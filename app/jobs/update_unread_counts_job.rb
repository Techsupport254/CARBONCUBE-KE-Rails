class UpdateUnreadCountsJob < ApplicationJob
  queue_as :default
  
  # Retry configuration with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(conversation_id, message_id)
    Rails.logger.info "UpdateUnreadCountsJob: Starting for conversation #{conversation_id}, message #{message_id}"
    
    conversation = Conversation.find_by(id: conversation_id)
    unless conversation
      Rails.logger.warn "UpdateUnreadCountsJob: Conversation #{conversation_id} not found"
      return
    end
    
    message = Message.find_by(id: message_id)
    unless message
      Rails.logger.warn "UpdateUnreadCountsJob: Message #{message_id} not found"
      return
    end
    
    Rails.logger.info "UpdateUnreadCountsJob: Found conversation #{conversation.id} and message #{message.id}"
    
    # Update unread counts for all participants
    update_participant_unread_counts(conversation, message)
    
    # Broadcast unread count updates to all participants
    broadcast_unread_count_updates(conversation)
    
    Rails.logger.info "UpdateUnreadCountsJob: Completed successfully"
    
  rescue StandardError => e
    Rails.logger.error "UpdateUnreadCountsJob: Failed to update unread counts: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
  
  private
  
  def update_participant_unread_counts(conversation, message)
    # For buyer
    if conversation.buyer_id
      buyer_unread_count = calculate_unread_count_for_user(conversation, conversation.buyer_id, 'Buyer')
      broadcast_unread_count_to_user('buyer', conversation.buyer_id, buyer_unread_count)
    end
    
    # For seller
    if conversation.seller_id
      seller_unread_count = calculate_unread_count_for_user(conversation, conversation.seller_id, 'Seller')
      broadcast_unread_count_to_user('seller', conversation.seller_id, seller_unread_count)
    end
    
    # For inquirer seller (if different from main seller)
    if conversation.inquirer_seller_id && conversation.inquirer_seller_id != conversation.seller_id
      inquirer_unread_count = calculate_unread_count_for_user(conversation, conversation.inquirer_seller_id, 'Seller')
      broadcast_unread_count_to_user('seller', conversation.inquirer_seller_id, inquirer_unread_count)
    end
    
    # For admin (if present)
    if conversation.admin_id
      admin_unread_count = calculate_unread_count_for_user(conversation, conversation.admin_id, 'Admin')
      broadcast_unread_count_to_user('admin', conversation.admin_id, admin_unread_count)
    end
  end
  
  def calculate_unread_count_for_user(conversation, user_id, user_type)
    case user_type
    when 'Buyer'
      # Count messages from sellers and admins that are unread (read_at is nil)
      conversation.messages
                  .where(sender_type: ['Seller', 'Admin'])
                  .where(read_at: nil)
                  .count
    when 'Seller'
      # Handle seller-to-seller conversations differently
      if conversation.seller_id.present? && conversation.inquirer_seller_id.present?
        # Seller-to-seller conversation: count messages not sent by current user
        conversation.messages
                    .where.not(sender_id: user_id)
                    .where(read_at: nil)
                    .count
      else
        # Regular conversation: count messages from buyers and admins
        conversation.messages
                    .where(sender_type: ['Buyer', 'Admin'])
                    .where(read_at: nil)
                    .count
      end
    when 'Admin'
      # Count messages from buyers and sellers that are unread (read_at is nil)
      conversation.messages
                  .where(sender_type: ['Buyer', 'Seller'])
                  .where(read_at: nil)
                  .count
    else
      0
    end
  end
  
  def broadcast_unread_count_to_user(user_type, user_id, unread_count)
    channel_name = "conversations_#{user_type.downcase}_#{user_id}"
    
    Rails.logger.info "UpdateUnreadCountsJob: Broadcasting to #{channel_name} with count: #{unread_count}"
    
    # Use ActionCable.server.broadcast to match the Message model
    ActionCable.server.broadcast(channel_name, {
      type: 'unread_count_update',
      unread_count: unread_count,
      timestamp: Time.current.iso8601
    })
    
    Rails.logger.info "UpdateUnreadCountsJob: Successfully broadcasted to #{channel_name}"
  rescue StandardError => e
    Rails.logger.warn "UpdateUnreadCountsJob: Failed to broadcast unread count to #{channel_name}: #{e.message}"
  end
  
  def broadcast_unread_count_updates(conversation)
    # This method can be used for additional broadcasting logic if needed
    # For now, the individual user broadcasts are handled in update_participant_unread_counts
  end
end
