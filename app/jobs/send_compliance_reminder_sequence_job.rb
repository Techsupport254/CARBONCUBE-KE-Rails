# frozen_string_literal: true

class SendComplianceReminderSequenceJob < ApplicationJob
  queue_as :default

  # Sends a compliance reminder sequence:
  #   - 3 weekly reminders
  #   - if still unresolved, a final reminder one month after the 3rd
  #   - then stop
  #
  # count is 0-indexed: 0 = first reminder, 3 = final reminder.
  def perform(seller_id, reminder_type = 'general', target_phone: nil, target_email: nil, count: 0)
    seller = Seller.find_by(id: seller_id)
    unless seller
      Rails.logger.error "[SendComplianceReminderSequenceJob] Seller #{seller_id} not found"
      return
    end

    if count > 3
      Rails.logger.info "[SendComplianceReminderSequenceJob] Sequence complete for seller #{seller_id}"
      return
    end

    # Fire the current reminder (email + whatsapp)
    SendDocumentComplianceReminderJob.perform_later(
      seller.id,
      reminder_type: reminder_type,
      channel: 'all',
      target_phone: target_phone,
      target_email: target_email
    )

    next_count = count + 1
    return if next_count > 3

    wait = next_count == 3 ? 1.month : 1.week
    SendComplianceReminderSequenceJob.set(wait: wait).perform_later(
      seller.id,
      reminder_type,
      target_phone: target_phone,
      target_email: target_email,
      count: next_count
    )
  end
end
