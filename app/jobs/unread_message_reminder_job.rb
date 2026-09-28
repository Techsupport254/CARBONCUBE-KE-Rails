# frozen_string_literal: true

class UnreadMessageReminderJob < ApplicationJob
  queue_as :broadcast

  retry_on StandardError, wait: :polynomially_longer, attempts: 2
  discard_on ActiveRecord::RecordNotFound

  def perform(conversation_id, recipient_type, recipient_id, reminder_number = 1)
    UnreadMessageReminderService.process_reminder(
      conversation_id,
      recipient_type,
      recipient_id,
      reminder_number
    )
  end
end
