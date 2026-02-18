class UpdateUnreadCountsJob < ApplicationJob
  queue_as :default
  
  # Retry configuration with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(conversation_id, message_id)
    # Rails.logger.info "UpdateUnreadCountsJob: Starting for conversation #{conversation_id}, message #{message_id}"
    
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
    
    # Rails.logger.info "UpdateUnreadCountsJob: Found conversation #{conversation.id} and message #{message.id}"
    
    # Update unread counts for all participants
    update_participant_unread_counts(conversation, message)
    
    # Broadcast unread count updates to all participants
    broadcast_unread_count_updates(conversation)
    
    # Rails.logger.info "UpdateUnreadCountsJob: Completed successfully"
    
  rescue StandardError => e
    Rails.logger.error "UpdateUnreadCountsJob: Failed to update unread counts: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
  
  private
  
  def update_participant_unread_counts(conversation, message)
    # For buyer - calculate total unread across all their conversations
    if conversation.buyer_id
      buyer_unread_count = calculate_total_unread_for_buyer(conversation.buyer_id)
      broadcast_unread_count_to_user('buyer', conversation.buyer_id, buyer_unread_count)
    end
    
    # For seller - calculate total unread across all their conversations
    if conversation.seller_id
      seller_unread_count = calculate_total_unread_for_seller(conversation.seller_id)
      broadcast_unread_count_to_user('seller', conversation.seller_id, seller_unread_count)
    end
    
    # For inquirer seller (if different from main seller) - calculate total unread
    if conversation.inquirer_seller_id && conversation.inquirer_seller_id != conversation.seller_id
      inquirer_unread_count = calculate_total_unread_for_seller(conversation.inquirer_seller_id)
      broadcast_unread_count_to_user('seller', conversation.inquirer_seller_id, inquirer_unread_count)
    end
    
    # For admin (if present) - calculate total unread across all their conversations
    if conversation.admin_id
      admin = Admin.find_by(id: conversation.admin_id)
      sales_user = SalesUser.find_by(id: conversation.admin_id)
      
      if admin
        admin_unread_count = calculate_total_unread_for_admin(conversation.admin_id)
        broadcast_unread_count_to_user('admin', conversation.admin_id, admin_unread_count)
      elsif sales_user
        sales_unread_count = calculate_total_unread_for_sales_user(sales_user.id)
        broadcast_unread_count_to_user('sales', sales_user.id, sales_unread_count)
      end
    end
    
    # For Sales users viewing all conversations, broadcast total unread count
    # This ensures they get real-time updates when messages arrive in any conversation
    # We broadcast to all active Sales users so they see the updated total count
    SalesUser.find_each do |sales_user|
      # Calculate total unread count across all conversations for this sales user
      total_unread = calculate_total_unread_for_sales_user(sales_user.id)
      broadcast_unread_count_to_user('sales', sales_user.id, total_unread)
    end
  end
  
  def calculate_unread_count_for_user(conversation, user_id, user_type)
    case user_type
    when 'Buyer'
      # Count messages from sellers, admins, and sales users that are unread (read_at is nil)
      conversation.messages
                  .where(sender_type: ['Seller', 'Admin', 'SalesUser'])
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
        # Regular conversation: count messages from buyers, admins, and sales users
        conversation.messages
                    .where(sender_type: ['Buyer', 'Admin', 'SalesUser'])
                    .where(read_at: nil)
                    .count
      end
    when 'Admin'
      # Count messages from sellers, buyers, and purchasers that are unread (read_at is nil)
      conversation.messages
                  .where(sender_type: ['Seller', 'Buyer', 'Purchaser'])
                  .where(read_at: nil)
                  .count
    when 'SalesUser'
      # For Sales users, count messages from sellers, buyers, and purchasers
      conversation.messages
                  .where(sender_type: ['Seller', 'Buyer', 'Purchaser'])
                  .where(read_at: nil)
                  .count
    else
      0
    end
  end
  
  def calculate_total_unread_for_buyer(buyer_id)
    conversations = Conversation.where(buyer_id: buyer_id).active_participants
    total_unread = 0
    
    conversations.each do |conversation|
      unread_count = conversation.messages
                                .where(sender_type: ['Seller', 'Admin', 'SalesUser'])
                                .where(read_at: nil)
                                .count
      total_unread += unread_count
    end
    
    total_unread
  end
  
  def calculate_total_unread_for_seller(seller_id)
    conversations = Conversation.where(
      "(seller_id = ? OR inquirer_seller_id = ?)", 
      seller_id, 
      seller_id
    ).active_participants
    
    total_unread = 0
    conversations.each do |conversation|
      if conversation.seller_id.present? && conversation.inquirer_seller_id.present?
        # Seller-to-seller conversation: count messages not sent by current user
        unread_count = conversation.messages
                                  .where.not(sender_id: seller_id)
                                  .where(read_at: nil)
                                  .count
      else
        # Regular conversation: count messages from buyers, admins, and sales users
        unread_count = conversation.messages
                                  .where(sender_type: ['Buyer', 'Admin', 'SalesUser'])
                                  .where(read_at: nil)
                                  .count
      end
      total_unread += unread_count
    end
    
    total_unread
  end
  
  def calculate_total_unread_for_admin(admin_id)
    conversations = Conversation.where(admin_id: admin_id).active_participants
    total_unread = 0
    
    conversations.each do |conversation|
      unread_count = conversation.messages
                                .where(sender_type: ['Seller', 'Buyer', 'Purchaser'])
                                .where(read_at: nil)
                                .count
      total_unread += unread_count
    end
    
    total_unread
  end
  
  def calculate_total_unread_for_sales_user(sales_user_id)
    # Sales users see all conversations
    conversations = Conversation.active_participants
    total_unread = 0
    
    conversations.each do |conversation|
      unread_count = conversation.messages
                                .where(sender_type: ['Seller', 'Buyer', 'Purchaser'])
                                .where(read_at: nil)
                                .count
      total_unread += unread_count
    end
    
    total_unread
  end
  
  def broadcast_unread_count_to_user(user_type, user_id, unread_count)
    channel_name = "conversations_#{user_type.downcase}_#{user_id}"
    
    # Rails.logger.info "UpdateUnreadCountsJob: Broadcasting to #{channel_name} with count: #{unread_count}"
    
    # Use ActionCable.server.broadcast to match the Message model
    ActionCable.server.broadcast(channel_name, {
      type: 'unread_count_update',
      unread_count: unread_count,
      timestamp: Time.current.iso8601
    })
    
    # Rails.logger.info "UpdateUnreadCountsJob: Successfully broadcasted to #{channel_name}"
  rescue StandardError => e
    Rails.logger.warn "UpdateUnreadCountsJob: Failed to broadcast unread count to #{channel_name}: #{e.message}"
  end
  
  def broadcast_unread_count_updates(conversation)
    # This method can be used for additional broadcasting logic if needed
    # For now, the individual user broadcasts are handled in update_participant_unread_counts
  end
end
