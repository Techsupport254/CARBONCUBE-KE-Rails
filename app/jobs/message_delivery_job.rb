class MessageDeliveryJob < ApplicationJob
  queue_as :critical  # Real-time chat receipt delivery — must stay responsive

  retry_on StandardError, wait: 10.seconds, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  MAX_ATTEMPTS = 3

  def perform(message_id, attempt = 1)
    message = Message.find_by(id: message_id)
    return unless message
    return if message.delivered? || message.read?

    # Check if recipient is online before marking as delivered
    recipient = message.get_recipient
    if recipient && message.is_recipient_online?(recipient)
      # Recipient is online - mark as delivered
      message.mark_as_delivered!
      broadcast_delivery_receipt(message)
      Rails.logger.info "Message #{message_id} marked as delivered - recipient is online"
    elsif attempt < MAX_ATTEMPTS
      # Recipient is still offline - retry with backoff up to MAX_ATTEMPTS
      self.class.set(wait: (attempt * 15).seconds).perform_later(message_id, attempt + 1)
    else
      # Reached max attempts - stop polling. PresenceChannel will mark delivered when recipient connects.
      Rails.logger.info "Message #{message_id} recipient offline after #{MAX_ATTEMPTS} attempts, waiting for next connect"
    end
  rescue => e
    Rails.logger.error "MessageDeliveryJob failed for message #{message_id}: #{e.message}"
    raise e
  end

  private

  def broadcast_delivery_receipt(message)
    sender_type = message.sender_type.downcase
    sender_id = message.sender_id
    
    # Broadcast to sender via PresenceChannel
    ActionCable.server.broadcast(
      "presence_#{sender_type}_#{sender_id}",
      {
        type: 'message_delivered',
        message_id: message.id,
        conversation_id: message.conversation_id,
        delivered_at: message.delivered_at,
        status: 'delivered'
      }
    )

    Rails.logger.info "Broadcasted delivery receipt for message #{message.id} to #{sender_type}_#{sender_id}"
  rescue => e
    Rails.logger.error "Failed to broadcast delivery receipt for message #{message.id}: #{e.message}"
  end
end
