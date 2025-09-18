class MessageDeliveryJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    # Check if recipient is online before marking as delivered
    recipient = message.get_recipient
    if recipient && message.is_recipient_online?(recipient)
      # Recipient is online - mark as delivered
      message.mark_as_delivered!
      broadcast_delivery_receipt(message)
      Rails.logger.info "Message #{message_id} marked as delivered - recipient is online"
    else
      # Recipient is still offline - reschedule for later
      Rails.logger.info "Message #{message_id} recipient still offline, rescheduling delivery"
      MessageDeliveryJob.perform_in(30.seconds, message_id)
    end
  rescue => e
    Rails.logger.error "MessageDeliveryJob failed for message #{message_id}: #{e.message}"
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
