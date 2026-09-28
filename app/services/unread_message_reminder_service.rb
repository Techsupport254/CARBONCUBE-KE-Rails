# frozen_string_literal: true

# Service managing automated reminders for unviewed marketplace messages.
#
# Scheduling Strategy (Industry-standard progressive backoff):
#   - Reminder 1: 30 minutes after initial unviewed message
#   - Reminder 2: 3 hours after Reminder 1 (if still unviewed)
#   - Reminder 3: 24 hours after Reminder 2 (final notice if still unviewed)
#   - Maximum: 3 reminders per unread message cycle.
#
# Anti-Spam Safeguards:
#   - Single active reminder sequence per conversation & recipient (no message storms).
#   - Immediately cancelled if recipient views/reads messages.
#   - Immediately cancelled if recipient replies.
#   - Deferred if recipient is currently online in the web/mobile app.
#   - Quiet hours respect: 10:00 PM - 7:00 AM EAT (UTC+3) postponed to 8:00 AM next morning.
#   - Uses approved WhatsApp utility template: ping_seller_message_v1.
class UnreadMessageReminderService
  TEMPLATE_NAME = 'ping_seller_message_v1'
  MAX_REMINDERS = 3

  # Intervals between reminders:
  # Reminder 1: 30 minutes from message creation
  # Reminder 2: 3 hours after Reminder 1
  # Reminder 3: 24 hours after Reminder 2
  INTERVALS = {
    1 => 30.minutes,
    2 => 3.hours,
    3 => 24.hours
  }.freeze

  class << self
    # Schedules the first reminder (after 30 minutes) when a new in-app message is created.
    # Debounced: if a reminder sequence is already running for this conversation + recipient,
    # does nothing so we don't spam duplicate notifications.
    def schedule_reminders_for(message)
      return unless message&.conversation
      return if message.conversation.is_whatsapp?

      recipient = message.get_recipient
      return unless recipient.is_a?(Seller)
      return if recipient.phone_number.blank?

      # Don't schedule if recipient already read the message
      return if message.read?

      active_key = reminder_lock_key(message.conversation_id, recipient.id)

      # Check if an active reminder sequence is already scheduled
      if RedisConnection.exists?(active_key)
        Rails.logger.info "[UnreadMessageReminderService] Reminder sequence already active for conv #{message.conversation_id}, recipient #{recipient.id}. Skipping duplicate scheduling."
        return
      end

      # Mark sequence as active in Redis (TTL: 48 hours to cover full 3-step cycle)
      RedisConnection.setex(
        active_key,
        48.hours.to_i,
        { step: 1, scheduled_at: (Time.current + INTERVALS[1]).iso8601 }.to_json
      )

      # Calculate first reminder run time respecting quiet hours
      scheduled_time = Time.current + INTERVALS[1]
      wait_time = calculate_wait_time(scheduled_time)

      UnreadMessageReminderJob.set(wait: wait_time).perform_later(
        message.conversation_id,
        recipient.class.name,
        recipient.id,
        1
      )

      Rails.logger.info "[UnreadMessageReminderService] Scheduled Reminder 1 for conv #{message.conversation_id} in #{wait_time.to_i / 60} minutes."
    rescue StandardError => e
      Rails.logger.error "[UnreadMessageReminderService] Failed to schedule reminder for message #{message&.id}: #{e.message}"
    end

    # Cancels active reminders when recipient views/reads messages in a conversation.
    def cancel_reminders(conversation_id, recipient_id)
      return if conversation_id.blank? || recipient_id.blank?

      active_key = reminder_lock_key(conversation_id, recipient_id)
      if RedisConnection.exists?(active_key)
        RedisConnection.del(active_key)
        Rails.logger.info "[UnreadMessageReminderService] Cancelled unread reminders for conv #{conversation_id}, recipient #{recipient_id}"
      end
    rescue StandardError => e
      Rails.logger.warn "[UnreadMessageReminderService] Error cancelling reminders: #{e.message}"
    end

    # Executes the reminder send, verifies unread state, and schedules the next stage if applicable.
    def process_reminder(conversation_id, recipient_type, recipient_id, reminder_number)
      conversation = Conversation.find_by(id: conversation_id)
      return unless conversation

      recipient = recipient_type.constantize.find_by(id: recipient_id)
      return unless recipient && recipient.phone_number.present?

      # Stop if we exceeded max reminders
      if reminder_number > MAX_REMINDERS
        cancel_reminders(conversation_id, recipient_id)
        return
      end

      # Check 1: Are there any unread messages from other participants?
      unread_messages = conversation.messages.unread.where.not(sender: recipient)
      if unread_messages.empty?
        Rails.logger.info "[UnreadMessageReminderService] No unread messages in conv #{conversation_id} for recipient #{recipient_id}. Cancelling sequence."
        cancel_reminders(conversation_id, recipient_id)
        return
      end

      # Check 2: Did the recipient reply in this conversation after the unread message?
      first_unread_at = unread_messages.minimum(:created_at)
      if first_unread_at && conversation.messages.where(sender: recipient).where('created_at > ?', first_unread_at).exists?
        Rails.logger.info "[UnreadMessageReminderService] Recipient #{recipient_id} has replied in conv #{conversation_id}. Cancelling sequence."
        cancel_reminders(conversation_id, recipient_id)
        return
      end

      # Check 3: Is recipient currently online on the platform?
      if is_recipient_online?(recipient)
        Rails.logger.info "[UnreadMessageReminderService] Recipient #{recipient_id} is currently online. Postponing Reminder #{reminder_number} by 15 minutes."
        UnreadMessageReminderJob.set(wait: 15.minutes).perform_later(
          conversation_id,
          recipient_type,
          recipient_id,
          reminder_number
        )
        return
      end

      # Check 4: Quiet Hours check (10:00 PM to 7:00 AM EAT)
      if in_quiet_hours?
        postponed_time = next_quiet_hours_end
        wait_seconds = [postponed_time - Time.current, 60].max
        Rails.logger.info "[UnreadMessageReminderService] Currently in quiet hours (10 PM - 7 AM EAT). Postponing Reminder #{reminder_number} to #{postponed_time} (wait #{wait_seconds / 60} mins)."
        UnreadMessageReminderJob.set(wait: wait_seconds.seconds).perform_later(
          conversation_id,
          recipient_type,
          recipient_id,
          reminder_number
        )
        return
      end

      # Send the WhatsApp reminder
      sent = send_whatsapp_template(conversation, recipient, unread_messages)

      # If send was successful (or failed gracefully), schedule the next reminder if < MAX_REMINDERS
      if sent && reminder_number < MAX_REMINDERS
        next_step = reminder_number + 1
        interval = INTERVALS[next_step] || 24.hours

        scheduled_time = Time.current + interval
        wait_time = calculate_wait_time(scheduled_time)

        active_key = reminder_lock_key(conversation_id, recipient_id)
        RedisConnection.setex(
          active_key,
          48.hours.to_i,
          { step: next_step, scheduled_at: (Time.current + wait_time).iso8601 }.to_json
        )

        UnreadMessageReminderJob.set(wait: wait_time).perform_later(
          conversation_id,
          recipient_type,
          recipient_id,
          next_step
        )
        Rails.logger.info "[UnreadMessageReminderService] Scheduled next Reminder #{next_step} for conv #{conversation_id} in #{wait_time.to_i / 60} mins."
      else
        # Completed all 3 reminders or sending stopped
        cancel_reminders(conversation_id, recipient_id)
        Rails.logger.info "[UnreadMessageReminderService] Sequence finished for conv #{conversation_id}, recipient #{recipient_id} at step #{reminder_number}."
      end
    rescue StandardError => e
      Rails.logger.error "[UnreadMessageReminderService] Error processing reminder #{reminder_number} for conv #{conversation_id}: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
    end

    # Checks if current or target time falls within quiet hours (10:00 PM - 7:00 AM EAT / UTC+3)
    def in_quiet_hours?(time = Time.current)
      eat_time = time.in_time_zone('Africa/Nairobi')
      eat_time.hour >= 22 || eat_time.hour < 7
    end

    # Calculates the end of quiet hours (8:00 AM EAT next morning)
    def next_quiet_hours_end(time = Time.current)
      eat_time = time.in_time_zone('Africa/Nairobi')
      target = if eat_time.hour >= 22
                 (eat_time + 1.day).change(hour: 8, min: 0, sec: 0)
               elsif eat_time.hour < 8
                 eat_time.change(hour: 8, min: 0, sec: 0)
               else
                 eat_time
               end
      target.in_time_zone('UTC')
    end

    # Calculates wait time in seconds, shifting forward if it lands in quiet hours
    def calculate_wait_time(target_time)
      adjusted_time = in_quiet_hours?(target_time) ? next_quiet_hours_end(target_time) : target_time
      [adjusted_time - Time.current, 60].max.seconds
    end

    def is_recipient_online?(recipient)
      return false unless recipient

      user_type = recipient.class.name.downcase
      cache_key = "online_user_#{user_type}_#{recipient.id}"
      Rails.cache.exist?(cache_key) || RedisConnection.exists?(cache_key)
    rescue StandardError => e
      Rails.logger.warn "[UnreadMessageReminderService] Failed to check online status: #{e.message}"
      false
    end

    private

    def reminder_lock_key(conversation_id, recipient_id)
      "unread_reminder:#{conversation_id}:#{recipient_id}"
    end

    def send_whatsapp_template(conversation, recipient, unread_messages)
      unread_count = unread_messages.count
      last_message = unread_messages.order(created_at: :desc).first
      message_preview = last_message&.content&.truncate(60) || "You have #{unread_count} unread message#{unread_count > 1 ? 's' : ''}"

      sender = last_message&.sender
      sender_name = if sender.is_a?(Buyer)
                      sender.fullname.presence || sender.username.presence || 'Buyer'
                    elsif sender.is_a?(Seller)
                      sender.enterprise_name.presence || sender.fullname.presence || 'Seller'
                    elsif sender.is_a?(Admin) || sender.is_a?(SalesUser)
                      'Carbon Cube Support'
                    else
                      'Carbon Cube Team'
                    end

      # Ultra-safe parameter cleaning for Meta WhatsApp API compliance
      safe_fullname = (recipient.fullname.presence || 'Seller').to_s.gsub(/[^a-zA-Z0-9 ]/, '').squish.truncate(30)
      safe_preview = message_preview.to_s.gsub(/[^a-zA-Z0-9 ]/, '').squish.truncate(60)
      safe_unread = unread_count.to_s
      safe_sender = sender_name.to_s.gsub(/[^a-zA-Z0-9 ]/, '').squish.truncate(30)

      result = WhatsAppCloudService.send_template(
        recipient.phone_number,
        TEMPLATE_NAME,
        'en',
        [
          {
            type: 'body',
            parameters: [
              { type: 'text', text: safe_fullname },
              { type: 'text', text: safe_unread },
              { type: 'text', text: safe_sender },
              { type: 'text', text: safe_preview }
            ]
          },
          {
            type: 'button',
            sub_type: 'url',
            index: 0,
            parameters: [
              { type: 'text', text: conversation.id.to_s }
            ]
          }
        ]
      )

      if result[:success]
        Rails.logger.info "[UnreadMessageReminderService] Successfully sent WhatsApp reminder to #{recipient.phone_number} (conv #{conversation.id})"
        true
      else
        Rails.logger.warn "[UnreadMessageReminderService] WhatsApp template failed for conv #{conversation.id}: #{result[:error]}"
        false
      end
    rescue StandardError => e
      Rails.logger.error "[UnreadMessageReminderService] Failed to send WhatsApp reminder: #{e.message}"
      false
    end
  end
end
