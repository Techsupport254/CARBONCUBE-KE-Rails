class UpdateUnreadCountsJob < ApplicationJob
  queue_as :critical  # Unread badge counts are real-time UX — must stay responsive

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(conversation_id, message_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation
    
    message = Message.find_by(id: message_id)
    return unless message
    
    # Update unread counts for all participants using optimized queries
    update_participant_unread_counts_optimized(conversation, message)
    
    # Broadcast unread count updates to all participants
    broadcast_unread_count_updates_optimized(conversation)
    
  rescue StandardError => e
    Rails.logger.error "UpdateUnreadCountsJob: Failed to update unread counts: #{e.message}"
    raise e
  end
  
  private
  
  def update_participant_unread_counts_optimized(conversation, message)
    # OPTIMIZATION: Use single bulk SQL queries instead of N+1 queries
    
    # For buyer
    if conversation.buyer_id
      buyer_unread_count = calculate_total_unread_for_buyer_optimized(conversation.buyer_id)
      Rails.cache.write("buyer_unread_count:#{conversation.buyer_id}", buyer_unread_count, expires_in: 1.hour)
    end
    
    # For seller
    if conversation.seller_id
      seller_unread_count = calculate_total_unread_for_seller_optimized(conversation.seller_id)
      Rails.cache.write("seller_unread_count:#{conversation.seller_id}", seller_unread_count, expires_in: 1.hour)
    end
    
    # For inquirer seller (if different from main seller)
    if conversation.inquirer_seller_id && conversation.inquirer_seller_id != conversation.seller_id
      inquirer_unread_count = calculate_total_unread_for_seller_optimized(conversation.inquirer_seller_id)
      Rails.cache.write("seller_unread_count:#{conversation.inquirer_seller_id}", inquirer_unread_count, expires_in: 1.hour)
    end
    
    # For admin
    if conversation.admin_id
      admin_unread_count = calculate_total_unread_for_admin_optimized(conversation.admin_id)
      Rails.cache.write("admin_unread_count:#{conversation.admin_id}", admin_unread_count, expires_in: 1.hour)
    end
    
    # OPTIMIZATION: Update sales users counts in bulk
    update_sales_users_unread_counts_optimized(conversation)
  end
  
  # OPTIMIZED: Single SQL query for buyer unread count
  def calculate_total_unread_for_buyer_optimized(buyer_id)
    Message.joins(:conversation)
           .where(conversations: { buyer_id: buyer_id })
           .where.not(sender_id: buyer_id)
           .where(read_at: nil)
           .count
  end
  
  # OPTIMIZED: Single SQL query for seller unread count
  def calculate_total_unread_for_seller_optimized(seller_id)
    Message.joins(:conversation)
           .where("conversations.seller_id = :id OR conversations.inquirer_seller_id = :id OR conversations.buyer_id = :id", id: seller_id)
           .where.not(sender_id: seller_id)
           .where(read_at: nil)
           .count
  end
  
  # OPTIMIZED: Single SQL query for admin unread count
  def calculate_total_unread_for_admin_optimized(admin_id)
    Message.joins(:conversation)
           .where("conversations.admin_id = :admin_id OR conversations.admin_id IS NULL OR conversations.is_whatsapp = true", admin_id: admin_id)
           .where.not(sender_id: admin_id)
           .where.not(sender_type: ['Admin', 'SalesUser'])
           .where(read_at: nil)
           .count
  end
  
  # OPTIMIZED: Cache total unread count for sales users
  def update_sales_users_unread_counts_optimized(conversation)
    # Bust stale cached total before recalculating
    Rails.cache.delete("sales_total_unread")

    total_unread_for_sales = Message.joins(:conversation)
                                    .where.not(sender_type: ['SalesUser', 'Admin'])
                                    .where(read_at: nil)
                                    .count
    
    Rails.cache.write("sales_total_unread", total_unread_for_sales, expires_in: 5.minutes)
    
    # Broadcast to all sales users
    SalesUser.find_each do |sales_user|
      Rails.cache.write("sales_unread_count:#{sales_user.id}", total_unread_for_sales, expires_in: 1.hour)
    end
  end
  
  def broadcast_unread_count_updates_optimized(conversation)
    # Broadcast to buyer
    if conversation.buyer_id
      buyer_unread = Rails.cache.read("buyer_unread_count:#{conversation.buyer_id}")
      broadcast_unread_count_to_user('buyer', conversation.buyer_id, buyer_unread) if buyer_unread
    end
    
    # Broadcast to seller
    if conversation.seller_id
      seller_unread = Rails.cache.read("seller_unread_count:#{conversation.seller_id}")
      broadcast_unread_count_to_user('seller', conversation.seller_id, seller_unread) if seller_unread
    end
    
    # Broadcast to inquirer seller (if different)
    if conversation.inquirer_seller_id && conversation.inquirer_seller_id != conversation.seller_id
      inquirer_unread = Rails.cache.read("seller_unread_count:#{conversation.inquirer_seller_id}")
      broadcast_unread_count_to_user('seller', conversation.inquirer_seller_id, inquirer_unread) if inquirer_unread
    end
    
    # Broadcast to admin
    if conversation.admin_id
      admin_unread = Rails.cache.read("admin_unread_count:#{conversation.admin_id}")
      broadcast_unread_count_to_user('admin', conversation.admin_id, admin_unread) if admin_unread
    end
    
    # Broadcast to all sales users
    SalesUser.find_each do |sales_user|
      sales_unread = Rails.cache.read("sales_unread_count:#{sales_user.id}")
      broadcast_unread_count_to_user('sales', sales_user.id, sales_unread) if sales_unread
    end
  end
  
  def broadcast_unread_count_to_user(user_type, user_id, unread_count)
    payload = {
      type: 'unread_count_update',
      unread_count: unread_count,
      count: unread_count,
      timestamp: Time.current.iso8601
    }

    # Primary stream subscribed by frontend useActionCable
    ActionCable.server.broadcast(
      "conversations_#{user_type}_#{user_id}",
      payload
    )

    # Presence stream fallback
    ActionCable.server.broadcast(
      "presence_#{user_type}_#{user_id}",
      payload
    )

    # Backward compatibility stream
    ActionCable.server.broadcast(
      "#{user_type}_#{user_id}_unread_counts",
      payload
    )
  rescue => e
    Rails.logger.error "Failed to broadcast unread count to #{user_type} #{user_id}: #{e.message}"
  end
end
