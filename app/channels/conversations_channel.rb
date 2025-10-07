class ConversationsChannel < ApplicationCable::Channel
  include ActionView::Helpers::SanitizeHelper
  

  def unsubscribed
    begin
      log_channel_activity('unsubscribed')
      track_message_metric('unsubscribed')
      
      # Broadcast offline status
      user = connection.current_user || find_user_from_params
      broadcast_presence_update('offline', user) if user
      
      # Clean up connection tracking
      if user
        WebsocketService.remove_connection_data(user.id, connection.session_id)
      end
    rescue => e
      Rails.logger.warn "ConversationsChannel unsubscribed error: #{e.message}"
      # Don't raise the error to prevent subscription cleanup issues
    end
  end

  def subscribed
    # Try to get user from connection, fallback to subscription params
    user = connection.current_user || find_user_from_params
    
    # If we found a user from params, set it on the connection
    if user && !connection.current_user
      connection.current_user = user
      connection.session_id = SecureRandom.uuid
      Rails.logger.info "ConversationsChannel: Set current_user from params: #{user.class.name} ID: #{user.id}"
    end
    
    return reject unless user
    
    # Subscribe to user-specific conversation stream
    stream_name = "conversations_#{get_user_type(user).downcase}_#{user.id}"
    stream_from stream_name
    
    log_channel_activity('subscribed', { stream: stream_name, user_id: user.id })
    track_message_metric('subscribed')
    
    # Broadcast online status
    broadcast_presence_update('online', user)
  rescue => e
    Rails.logger.error "ConversationsChannel subscribed error: #{e.message}"
    reject
  end

  def receive(data)
    return if rate_limited?
    
    user = connection.current_user || find_user_from_params
    return reject unless user
    
    # Basic validation for incoming message
    return unless data.present? && data.is_a?(Hash)
    
    # Process message asynchronously for better performance
    ProcessWebsocketMessageJob.perform_later(
      data.merge(
        sender_user: user,
        sender_session: connection.session_id
      )
    )
    
    track_message_metric('message_received')
  end
  
  def typing(data)
    return if rate_limited?
    
    user = connection.current_user || find_user_from_params
    return reject unless user
    
    conversation_id = data['conversation_id']&.to_i
    typing_status = data['typing'] == true
    
    return unless conversation_id && validate_conversation_access(conversation_id, user)
    
    # Broadcast typing status to conversation participants
    broadcast_to_conversation_participants(
      conversation_id,
      {
        type: 'typing_status',
        user_id: user.id,
        user_type: get_user_type(user),
        typing: typing_status,
        conversation_id: conversation_id,
        timestamp: Time.current.iso8601
      },
      exclude_sender: true,
      current_user: user
    )
    
    track_message_metric('typing_update')
  end
  
  def mark_read(data)
    return if rate_limited?
    
    user = connection.current_user || find_user_from_params
    return reject unless user
    
    message_id = data['message_id']&.to_i
    return unless message_id
    
    # Process read receipt asynchronously
    ProcessReadReceiptJob.perform_later(message_id, user.id)
    
    track_message_metric('mark_read')
  end

  private

  def find_user_from_params
    user_type = params[:user_type]
    user_id = params[:user_id]
    
    return nil unless user_type && user_id
    
    case user_type.downcase
    when 'buyer'
      Buyer.find_by(id: user_id)
    when 'seller'
      Seller.find_by(id: user_id)
    when 'admin'
      Admin.find_by(id: user_id)
    else
      nil
    end
  end

  def validate_conversation_access(conversation_id, user)
    conversation = Conversation.find_by(id: conversation_id)
    return false unless conversation
    
    # Check if user is a participant
    user_type = get_user_type(user)
    case user_type.downcase
    when 'buyer'
      conversation.buyer_id == user.id
    when 'seller'
      conversation.seller_id == user.id || conversation.inquirer_seller_id == user.id
    when 'admin', 'sales'
      true # Admins and sales users can access all conversations
    when 'rider'
      false # Only buyers, sellers, and admins have conversation access
    else
      false
    end
  end
  
  def broadcast_to_conversation_participants(conversation_id, data, exclude_sender: false, current_user: nil)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation
    
    # Broadcast to buyer
    if conversation.buyer_id && (!exclude_sender || conversation.buyer_id != current_user&.id)
      broadcast_with_retry("conversations_buyer_#{conversation.buyer_id}", data)
    end
    
    # Broadcast to seller
    if conversation.seller_id && (!exclude_sender || conversation.seller_id != current_user&.id)
      broadcast_with_retry("conversations_seller_#{conversation.seller_id}", data)
    end
    
    # Broadcast to inquirer seller (if different from main seller)
    if conversation.inquirer_seller_id && conversation.inquirer_seller_id != conversation.seller_id && (!exclude_sender || conversation.inquirer_seller_id != current_user&.id)
      broadcast_with_retry("conversations_seller_#{conversation.inquirer_seller_id}", data)
    end
  end
  
  def broadcast_with_retry(stream_name, data, max_retries: 2)
    retries = 0
    begin
      ActionCable.server.broadcast(stream_name, data)
    rescue => e
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "Broadcast failed for #{stream_name}, retrying (#{retries}/#{max_retries}): #{e.message}"
        sleep(0.1 * retries) # Brief backoff
        retry
      else
        Rails.logger.error "Broadcast failed for #{stream_name} after #{max_retries} retries: #{e.message}"
        # Don't raise the error to prevent breaking the message flow
      end
    end
  end
  
  def broadcast_presence_update(status, user)
    return unless user
    
    # Get user's conversations to notify participants
    conversations = get_user_conversations(user)
    
    conversations.find_each do |conversation|
      broadcast_to_conversation_participants(
        conversation.id,
        {
          type: 'presence_update',
          user_id: user.id,
          user_type: get_user_type(user),
          status: status,
          timestamp: Time.current.iso8601
        },
        exclude_sender: true,
        current_user: user
      )
    end
  end
  
  def get_user_conversations(user)
    user_type = get_user_type(user)
    case user_type.downcase
    when 'buyer'
      Conversation.where(buyer_id: user.id)
    when 'seller'
      Conversation.where(seller_id: user.id)
    when 'admin'
      Conversation.all
    when 'sales'
      Conversation.all  # Sales users can see all conversations like admins
    when 'rider'
      Conversation.none  # Only buyers, sellers, and admins have conversations
    else
      Conversation.none
    end
  end
  
  def get_user_type(user)
    case user.class.name
    when 'Buyer'
      'buyer'
    when 'Seller'
      'seller'
    when 'Admin'
      'admin'
    when 'SalesUser'
      'sales'
    else
      'unknown'
    end
  end
  
  def log_channel_activity(action, data = {})
    Rails.logger.info "ConversationsChannel #{action}: #{data.inspect}"
  end
  
  def track_message_metric(action)
    # Track metrics using WebSocket service if available
    begin
      WebsocketService.track_metric("websocket.conversations.#{action}")
    rescue => e
      Rails.logger.debug "Failed to track metric: #{e.message}"
    end
  end
  
  def rate_limited?
    # Simple rate limiting - can be enhanced with Redis-based rate limiting
    false
  end
end