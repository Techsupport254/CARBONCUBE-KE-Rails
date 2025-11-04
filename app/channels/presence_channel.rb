class PresenceChannel < ApplicationCable::Channel
  def subscribed
    # Try to authenticate user if not already authenticated
    unless connection.current_user
      authenticate_user_from_subscription_params
    end
    
    # Ensure we have a valid user connection
    unless connection.current_user
      Rails.logger.warn "PresenceChannel: No current_user in connection after authentication attempt"
      reject
      return
    end
    
    # Get user info from connection instead of params to ensure consistency
    user_type = get_user_type_from_connection
    user_id = connection.current_user.id
    
    Rails.logger.info "PresenceChannel subscribed: user_type=#{user_type}, user_id=#{user_id}"
    
    # Store params for use in other methods
    @user_type = user_type
    @user_id = user_id
    
    # Subscribe to presence channel for online status and typing
    stream_from "presence_#{user_type}_#{user_id}"
    
    # Track this user as online in Redis or similar
    track_user_online(true)
    
    # Process pending delivery receipts for this user
    process_pending_delivery_receipts
    
    # Broadcast that user is online
    broadcast_online_status(true)
  end

  def unsubscribed
    begin
      # Only track offline if we have a valid user
      if connection.current_user
        user_type = @user_type || get_user_type_from_connection
        user_id = @user_id || connection.current_user.id
        
        Rails.logger.info "PresenceChannel unsubscribed: user_type=#{user_type}, user_id=#{user_id}"
        
        # Track this user as offline
        track_user_online(false)
        
        # Broadcast that user is offline
        broadcast_online_status(false)
        
        # Clean up connection tracking
        WebsocketService.remove_connection_data(user_id, connection.session_id)
        
        # Clean up any pending operations
        cleanup_user_data
      end
    rescue => e
      Rails.logger.warn "PresenceChannel unsubscribed error: #{e.message}"
      # Don't raise the error to prevent subscription cleanup issues
    end
  end

  def receive(data)
    # Check if connection is still active
    unless connection.current_user
      Rails.logger.warn "PresenceChannel: No current_user in connection, ignoring message"
      return
    end
    
    # Check if the subscription is still active
    unless subscription_active?
      Rails.logger.warn "PresenceChannel: Subscription not active, ignoring message"
      return
    end
    
    Rails.logger.info "PresenceChannel received: #{data['type']} from user #{connection.current_user.id}"
    
    case data['type']
    when 'typing_start'
      broadcast_typing_status(true, data['conversation_id'])
    when 'typing_stop'
      broadcast_typing_status(false, data['conversation_id'])
    when 'message_read'
      handle_message_read(data['message_id'])
    when 'message_delivered'
      handle_message_delivered(data['message_id'])
    when 'conversation_viewed'
      handle_conversation_viewed(data['conversation_id'])
    when 'heartbeat'
      # Update user's online status
      track_user_online(true)
      # Update user's last_active_at timestamp
      update_user_last_active
      # Process any pending delivery receipts
      process_pending_delivery_receipts
      # Send heartbeat response to confirm connection is alive
      transmit({ type: 'heartbeat_response', timestamp: Time.current.iso8601 })
    when 'pong'
      # Client responded to ping, connection is healthy
      Rails.logger.debug "PresenceChannel: Received pong from user #{connection.current_user.id}"
    else
      Rails.logger.warn "PresenceChannel: Unknown message type: #{data['type']}"
    end
  rescue => e
    Rails.logger.warn "PresenceChannel receive error: #{e.message}"
    Rails.logger.warn "PresenceChannel error backtrace: #{e.backtrace.first(3).join("\n")}"
    # Don't raise the error to prevent subscription cleanup issues
  end

  private

  def authenticate_user_from_subscription_params
    Rails.logger.info "PresenceChannel: Attempting to authenticate user from subscription params"
    Rails.logger.info "PresenceChannel: Subscription params: #{params.inspect}"
    
    user_type = params[:user_type]
    user_id = params[:user_id]
    
    unless user_type && user_id
      Rails.logger.error "PresenceChannel: Missing user_type or user_id in subscription params"
      return false
    end
    
    Rails.logger.info "PresenceChannel: Looking for user #{user_id} of type #{user_type}"
    
    case user_type.downcase
    when 'seller'
      seller = Seller.find_by(id: user_id)
      if seller && !seller.deleted?
        connection.current_user = seller
        connection.session_id = SecureRandom.uuid
        Rails.logger.info "PresenceChannel: Successfully authenticated seller #{seller.id}"
        return true
      else
        Rails.logger.error "PresenceChannel: Seller #{user_id} not found or deleted"
      end
    when 'buyer'
      buyer = Buyer.find_by(id: user_id)
      if buyer && !buyer.deleted?
        connection.current_user = buyer
        connection.session_id = SecureRandom.uuid
        Rails.logger.info "PresenceChannel: Successfully authenticated buyer #{buyer.id}"
        return true
      else
        Rails.logger.error "PresenceChannel: Buyer #{user_id} not found or deleted"
      end
    when 'admin'
      admin = Admin.find_by(id: user_id)
      if admin
        connection.current_user = admin
        connection.session_id = SecureRandom.uuid
        Rails.logger.info "PresenceChannel: Successfully authenticated admin #{admin.id}"
        return true
      else
        Rails.logger.error "PresenceChannel: Admin #{user_id} not found"
      end
    when 'sales'
      sales_user = SalesUser.find_by(id: user_id)
      if sales_user
        connection.current_user = sales_user
        connection.session_id = SecureRandom.uuid
        Rails.logger.info "PresenceChannel: Successfully authenticated sales user #{sales_user.id}"
        return true
      else
        Rails.logger.error "PresenceChannel: Sales user #{user_id} not found"
      end
    else
      Rails.logger.error "PresenceChannel: Unknown user type: #{user_type}"
    end
    
    false
  end

  def get_user_type_from_connection
    return @user_type if @user_type
    
    # Determine user type based on model class
    case connection.current_user.class.name
    when 'Buyer' then 'buyer'
    when 'Seller' then 'seller'
    when 'Admin' then 'admin'
    when 'SalesUser' then 'sales'
    else connection.current_user.class.name.downcase
    end
  end

  def subscription_active?
    # Check if the subscription is still active by verifying the connection
    begin
      # Basic checks
      return false unless connection.current_user.present?
      return false unless connection.connected?
      
      # Additional health check - verify the connection is still responsive
      # This helps detect broken pipe scenarios
      connection.transmit({ type: 'ping', timestamp: Time.current.iso8601 })
      true
    rescue => e
      Rails.logger.debug "PresenceChannel: Subscription not active: #{e.message}"
      false
    end
  end

  def cleanup_user_data
    # Clean up any user-specific data when disconnecting
    begin
      # Remove any pending typing indicators
      # This could be expanded to clean up other user-specific data
      Rails.logger.info "PresenceChannel: Cleaned up user data for #{params[:user_type]}_#{params[:user_id]}"
    rescue => e
      Rails.logger.warn "PresenceChannel: Error cleaning up user data: #{e.message}"
    end
  end

  def track_user_online(online)
    # Use Redis to track online users
    # Key format: "online_user_#{user_type}_#{user_id}"
    user_type = @user_type || get_user_type_from_connection
    user_id = @user_id || connection.current_user.id
    cache_key = "online_user_#{user_type}_#{user_id}"
    
    begin
      if online
        # Set user as online with a 5-minute expiration
        RedisConnection.setex(cache_key, 300, true) # 300 seconds = 5 minutes
      else
        # Remove user from online tracking
        RedisConnection.del(cache_key)
      end
      
      # Broadcast online status change to all subscribers (with error handling)
      broadcast_online_status_change(online)
      
    rescue => e
      Rails.logger.warn "Failed to track user online status: #{e.message}"
      # Don't re-raise to prevent connection issues
    end
  end

  def update_user_last_active
    # Update the user's last_active_at timestamp when they send a heartbeat
    user = connection.current_user
    if user.respond_to?(:update_last_active!)
      user.update_last_active!
    end
  rescue => e
    Rails.logger.warn "Failed to update user last_active_at: #{e.message}"
    # Don't re-raise to prevent connection issues
  end

  def broadcast_online_status_change(online)
    # Broadcast online status change to all subscribers
    user_type = @user_type || get_user_type_from_connection
    user_id = @user_id || connection.current_user.id
    
    begin
      ActionCable.server.broadcast(
        "presence_channel",
        {
          type: "online_status",
          user_type: user_type,
          user_id: user_id,
          online: online,
          timestamp: Time.current.iso8601
        }
      )
      
      Rails.logger.debug "Broadcasted online status change: #{user_type}_#{user_id} = #{online}"
    rescue => e
      Rails.logger.warn "Failed to broadcast online status change: #{e.message}"
      # Don't re-raise to prevent connection issues
    end
  end

  def broadcast_online_status(online)
    # Get user's conversations
    conversations = get_user_conversations
    
    user_type = @user_type || get_user_type_from_connection
    user_id = @user_id || connection.current_user.id
    
    conversations.each do |conversation|
      # Broadcast to other participants
      broadcast_to_other_participants(conversation, {
        type: 'online_status',
        user_id: user_id,
        user_type: user_type,
        online: online
      })
    end
  end

  def broadcast_typing_status(typing, conversation_id)
    # Find the specific conversation
    conversation = Conversation.find(conversation_id)
    
    user_type = @user_type || get_user_type_from_connection
    user_id = @user_id || connection.current_user.id
    
    # Broadcast to other participants in this conversation only
    broadcast_to_other_participants(conversation, {
      type: 'typing_status',
      user_id: user_id,
      user_type: user_type,
      typing: typing,
      conversation_id: conversation_id
    })
  end

  def process_pending_delivery_receipts
    user_type = @user_type || get_user_type_from_connection
    user_id = @user_id || connection.current_user.id
    
    Rails.logger.info "Processing pending delivery receipts for #{user_type}_#{user_id}"
    
    begin
      # Find all sent messages where this user is the recipient
      pending_messages = case user_type
      when 'buyer'
        Message.joins(:conversation)
               .where(conversations: { buyer_id: user_id })
               .where(status: ['sent', nil])
               .where.not(sender_type: 'Buyer')
      when 'seller'
        Message.joins(:conversation)
               .where(conversations: { seller_id: user_id })
               .where(status: ['sent', nil])
               .where.not(sender_type: 'Seller')
      else
        []
      end
      
      # Mark these messages as delivered since user is now online
      pending_messages.each do |message|
        message.mark_as_delivered!
        broadcast_delivery_receipt(message)
        Rails.logger.info "Marked pending message #{message.id} as delivered"
      end
      
      Rails.logger.info "Processed #{pending_messages.count} pending delivery receipts"
    rescue => e
      Rails.logger.error "Failed to process pending delivery receipts: #{e.message}"
    end
  end

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

  def handle_conversation_viewed(conversation_id)
    return unless conversation_id
    
    begin
      conversation = Conversation.find_by(id: conversation_id)
      return unless conversation
      
      # Mark all unread messages in this conversation as read
      unread_messages = conversation.messages.unread.where.not(sender: connection.current_user)
      
      unread_messages.each do |message|
        message.mark_as_read!
        broadcast_read_receipt(message)
      end
      
      Rails.logger.info "PresenceChannel: Marked #{unread_messages.count} messages as read for conversation #{conversation_id}"
    rescue => e
      Rails.logger.warn "PresenceChannel: Error handling conversation viewed for ID #{conversation_id}: #{e.message}"
    end
  end

  def handle_message_read(message_id)
    return unless message_id
    
    begin
      message = Message.find_by(id: message_id)
      return unless message
      
      # Don't mark your own messages as read
      return if message.sender == connection.current_user
      
      # Update message read status
      message.mark_as_read!
      
      # Broadcast read receipt to sender
      broadcast_read_receipt(message)
      
      Rails.logger.info "PresenceChannel: Marked message #{message_id} as read"
    rescue => e
      Rails.logger.warn "PresenceChannel: Error handling message read for ID #{message_id}: #{e.message}"
    end
  end

  def handle_message_delivered(message_id)
    return unless message_id
    
    begin
      message = Message.find_by(id: message_id)
      return unless message
      
      # Don't mark your own messages as delivered
      return if message.sender == connection.current_user
      
      # Update message delivered status
      message.mark_as_delivered!
      
      # Broadcast delivery receipt to sender
      broadcast_delivery_receipt(message)
      
      Rails.logger.info "PresenceChannel: Marked message #{message_id} as delivered"
    rescue => e
      Rails.logger.warn "PresenceChannel: Error handling message delivered for ID #{message_id}: #{e.message}"
    end
  end

  def get_user_conversations
    user_id = @user_id || connection.current_user.id
    user_type = @user_type || get_user_type_from_connection
    
    case user_type.downcase
    when 'buyer'
      Conversation.where(buyer_id: user_id)
    when 'seller'
      Conversation.where(seller_id: user_id)
    when 'admin'
      # Admins can see all conversations, but we need to find conversations where they participate
      Conversation.where("buyer_id = ? OR seller_id = ? OR admin_id = ?", user_id, user_id, user_id)
    else
      []
    end
  end

  def broadcast_to_other_participants(conversation, data)
    user_id = (@user_id || connection.current_user.id).to_s
    
    # Broadcast to buyer (but not to self)
    if conversation.buyer_id && conversation.buyer_id.to_s != user_id
      broadcast_with_retry("presence_buyer_#{conversation.buyer_id}", data)
    end

    # Broadcast to seller (but not to self)
    if conversation.seller_id && conversation.seller_id.to_s != user_id
      broadcast_with_retry("presence_seller_#{conversation.seller_id}", data)
    end

    # Broadcast to admin (but not to self)
    if conversation.admin_id && conversation.admin_id.to_s != user_id
      broadcast_with_retry("presence_admin_#{conversation.admin_id}", data)
    end
  end
  
  def broadcast_with_retry(stream_name, data, max_retries: 2)
    retries = 0
    begin
      ActionCable.server.broadcast(stream_name, data)
    rescue => e
      # Handle specific broken pipe errors gracefully
      if e.message.include?('Broken pipe') || e.message.include?('Connection reset')
        Rails.logger.debug "PresenceChannel: Connection lost for #{stream_name}, skipping broadcast"
        return
      end
      
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "PresenceChannel broadcast failed for #{stream_name}, retrying (#{retries}/#{max_retries}): #{e.message}"
        sleep(0.1 * retries) # Brief backoff
        retry
      else
        Rails.logger.warn "PresenceChannel broadcast failed for #{stream_name} after #{max_retries} retries: #{e.message}"
        # Don't raise the error to prevent breaking the presence flow
      end
    end
  end

  def broadcast_read_receipt(message)
    # Broadcast to message sender
    sender_type = message.sender_type.downcase
    sender_id = message.sender_id
    
    broadcast_with_retry(
      "presence_#{sender_type}_#{sender_id}",
      {
        type: 'message_read',
        message_id: message.id,
        conversation_id: message.conversation_id,
        read_at: message.read_at
      }
    )
  end

  def broadcast_delivery_receipt(message)
    # Broadcast to message sender
    sender_type = message.sender_type.downcase
    sender_id = message.sender_id
    
    broadcast_with_retry(
      "presence_#{sender_type}_#{sender_id}",
      {
        type: 'message_delivered',
        message_id: message.id,
        conversation_id: message.conversation_id,
        delivered_at: message.delivered_at
      }
    )
  end
end
