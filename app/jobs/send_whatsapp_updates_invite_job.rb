# frozen_string_literal: true

require 'timeout'

# Sends email invitations and follow-up reminders to new users (sellers & buyers)
# to join Carbon Cube Kenya WhatsApp updates via a 1-tap `wa.me/?text=START` link.
#
# Lifecycle:
#   - Initial Invite: Sent roughly 2 days (48–72h) after registration.
#   - Follow-up Reminder: Sent ~3 days after the initial invite (roughly 5 days after registration)
#     only if the user has NOT yet engaged or subscribed on WhatsApp.
#
# Compliance & Safety:
#   - Sent exclusively via Email (zero Meta WABA spam / template risk).
#   - Immediately halts reminders if the user has messaged us on WhatsApp
#     (`WhatsAppCloudService.user_whatsapp_engaged?` or keyword opt-in).
#   - Deduplicated via in-app Notification records so no stage is sent twice.
class SendWhatsappUpdatesInviteJob < ApplicationJob
  queue_as :broadcast

  INITIAL_MIN_AGE_HOURS = 48 # 2 days
  INITIAL_MAX_AGE_HOURS = 72 # 3 days
  REMINDER_DELAY_DAYS   = 3  # 3 days after initial invite

  INVITE_NOTIFICATION_TITLE   = 'Join Carbon Cube Kenya on WhatsApp'
  REMINDER_NOTIFICATION_TITLE = 'Reminder: Join Carbon Cube Kenya on WhatsApp'

  INVITE_BODY   = 'Stay updated in real time — connect with Carbon Cube Kenya on WhatsApp for instant inquiries, alerts, and priority support.'
  REMINDER_BODY = 'Quick reminder: Connect with Carbon Cube Kenya on WhatsApp to ensure you never miss urgent buyer inquiries, deals, or account alerts.'

  def perform(dry_run: false)
    stats = {
      initial_eligible: 0,
      initial_queued: 0,
      initial_skipped_engaged: 0,
      initial_skipped_duplicate: 0,
      reminder_eligible: 0,
      reminder_queued: 0,
      reminder_skipped_engaged: 0,
      reminder_skipped_duplicate: 0,
      failed: 0,
      dry_run: dry_run
    }

    # Step 1: Process initial invites for users registered 2 days ago
    process_initial_invites(stats, dry_run: dry_run)

    # Step 2: Process follow-up reminders for users invited ~3 days ago who haven't subscribed
    process_reminders(stats, dry_run: dry_run)

    Rails.logger.info "[SendWhatsappUpdatesInviteJob] Completed: #{stats.inspect}"
    stats
  end

  private

  def process_initial_invites(stats, dry_run:)
    window = INITIAL_MAX_AGE_HOURS.hours.ago..INITIAL_MIN_AGE_HOURS.hours.ago

    [Seller, Buyer].each do |user_class|
      users = user_class.where(deleted: [false, nil], blocked: [false, nil])
                        .where(created_at: window)

      users.find_each do |user|
        stats[:initial_eligible] += 1

        if already_engaged?(user)
          stats[:initial_skipped_engaged] += 1
          next
        end

        if Notification.exists?(recipient: user, title: INVITE_NOTIFICATION_TITLE)
          stats[:initial_skipped_duplicate] += 1
          next
        end

        deliver_invite(user, reminder_number: 0, title: INVITE_NOTIFICATION_TITLE, body: INVITE_BODY, dry_run: dry_run)
        stats[:initial_queued] += 1
      rescue StandardError => e
        stats[:failed] += 1
        Rails.logger.error "[SendWhatsappUpdatesInviteJob] Initial invite failed for #{user.class.name}##{user.id}: #{e.message}"
      end
    end
  end

  def process_reminders(stats, dry_run:)
    # Find initial notifications sent between 3 and 4 days ago
    reminder_window = (REMINDER_DELAY_DAYS + 1).days.ago..REMINDER_DELAY_DAYS.days.ago

    initial_notifications = Notification.where(title: INVITE_NOTIFICATION_TITLE)
                                        .where(created_at: reminder_window)

    initial_notifications.find_each do |notif|
      user = notif.recipient
      next unless user.is_a?(Seller) || user.is_a?(Buyer)
      next if user.try(:deleted) || user.try(:blocked)

      stats[:reminder_eligible] += 1

      if already_engaged?(user)
        stats[:reminder_skipped_engaged] += 1
        next
      end

      if Notification.exists?(recipient: user, title: REMINDER_NOTIFICATION_TITLE)
        stats[:reminder_skipped_duplicate] += 1
        next
      end

      deliver_invite(user, reminder_number: 1, title: REMINDER_NOTIFICATION_TITLE, body: REMINDER_BODY, dry_run: dry_run)
      stats[:reminder_queued] += 1
    rescue StandardError => e
      stats[:failed] += 1
      Rails.logger.error "[SendWhatsappUpdatesInviteJob] Reminder failed for recipient #{notif.recipient_id}: #{e.message}"
    end
  end

  def already_engaged?(user)
    return true if WhatsAppCloudService.user_whatsapp_engaged?(user)
    return true if user.respond_to?(:whatsapp_opt_in_source) && user.whatsapp_opt_in_source == 'whatsapp_keyword'

    false
  end

  def deliver_invite(user, reminder_number:, title:, body:, dry_run:)
    return if dry_run
    return if user.email.blank?

    Timeout.timeout(30) do
      MarketingMailer.whatsapp_updates_invite(
        recipient: user,
        reminder_number: reminder_number
      ).deliver_now
    end

    unless Notification.exists?(recipient: user, title: title)
      Notification.create!(
        recipient: user,
        title: title,
        body: body,
        data: { 'type' => 'whatsapp_updates_invite', 'reminder_number' => reminder_number }
      )
    end
  end
end
