class ProcessWebsocketMessageJob < ApplicationJob
  queue_as :websocket
  
  # Retry configuration with exponential backoff - reduced attempts for graceful degradation
  retry_on StandardError, wait: :exponentially_longer, attempts: 2
  
  def perform(message_data)
    # Extract data
    conversation_id = message_data['conversation_id']
    content = sanitize_content(message_data['content'])
    sender_type = message_data['sender_type']
    sender_id = message_data['sender_id']
    sender_user = message_data['sender_user']
    sender_session = message_data['sender_session']
    
    # Find conversation and validate access
    conversation = find_and_validate_conversation(conversation_id, sender_user)
    return unless conversation
    
    # Create message with optimistic locking
    message = create_message_with_retry(conversation, {
      content: content,
      sender_type: sender_type,
      sender_id: sender_id,
      ad_id: message_data['ad_id'],
      product_context: message_data['product_context'],
      message_type: message_data['message_type'] || 'text'
    })
    
    return unless message
    
    # Broadcast to conversation participants
    broadcast_message_to_participants(conversation, message, sender_session)
    
    # Update conversation last activity
    update_conversation_activity(conversation)
    
    # Track metrics
    track_message_metrics(message)
    
    # Process any post-message hooks (notifications, etc.)
    post_message_processing(conversation, message)
    
  rescue StandardError => e
    Rails.logger.error "Failed to process WebSocket message: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Send error back to sender if possible (non-blocking)
    WebsocketService.notify_error(sender_user, sender_session, e.message)
    
    # Don't re-raise the error to prevent job failure from blocking deployment
    Rails.logger.warn "WebSocket message processing failed but deployment continues"
  end
  
  private
  
  def find_and_validate_conversation(conversation_id, sender_user)
    conversation = Conversation.find_by(id: conversation_id)
    
    unless conversation
      Rails.logger.warn "Conversation #{conversation_id} not found"
      return nil
    end
    
    # Validate sender has access to this conversation
    unless conversation_participant?(conversation, sender_user)
      Rails.logger.warn "User #{sender_user.id} not authorized for conversation #{conversation_id}"
      return nil
    end
    
    conversation
  end
  
  def conversation_participant?(conversation, user)
    case user.user_type.downcase
    when 'buyer'
      conversation.buyer_id == user.id
    when 'seller'
      conversation.seller_id == user.id
    when 'admin'
      true
    else
      false
    end
  end
  
  def create_message_with_retry(conversation, message_attrs, retries: 3)
    attempt = 0
    
    begin
      attempt += 1
      
      message = conversation.messages.create!(message_attrs)
      Rails.logger.info "Created message #{message.id} for conversation #{conversation.id}"
      message
      
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Message validation failed: #{e.message}"
      nil
    rescue ActiveRecord::StaleObjectError => e
      if attempt <= retries
        Rails.logger.warn "Conversation updated concurrently, retrying (#{attempt}/#{retries})"
        conversation.reload
        sleep(0.1 * attempt) # Brief backoff
        retry
      else
        Rails.logger.error "Failed to create message after #{retries} retries: #{e.message}"
        nil
      end
    end
  end
  
  def sanitize_content(content)
    # Basic sanitization for security
    ActionController::Base.helpers.sanitize(
      content,
      tags: %w[b i u em strong],
      attributes: {}
    )
  end
  
  def broadcast_message_to_participants(conversation, message, sender_session)
    # Prepare broadcast data
    message_data = serialize_message(message)
    
    # Use WebSocket service for broadcasting with fallback
    success = WebsocketService.broadcast_to_conversation(conversation, message_data, sender_session)
    
    if success
      WebsocketService.track_metric('websocket.messages.broadcast.success')
    else
      Rails.logger.warn "Message broadcast failed but job continues"
      WebsocketService.track_metric('websocket.messages.broadcast.error')
    end
  end
  
  def serialize_message(message)
    # Determine status based on read_at/delivered_at
    status = if message.read_at.present?
      'read'
    elsif message.delivered_at.present?
      'delivered'
    else
      message.status.present? ? message.status : 'sent'
    end

    {
      id: message.id,
      content: message.content,
      sender_type: message.sender_type,
      sender_id: message.sender_id,
      ad_id: message.ad_id,
      product_context: message.product_context,
      message_type: message.message_type,
      created_at: message.created_at.iso8601,
      status: status,
      read_at: message.read_at,
      delivered_at: message.delivered_at
    }
  end
  
  def update_conversation_activity(conversation)
    begin
      # Update last activity timestamp
      conversation.touch(:updated_at)
      
      # Update Redis cache for quick access
      cache_key = "conversation_activity:#{conversation.id}"
      RedisConnection.setex(cache_key, 3600, Time.current.to_i)
    rescue StandardError => e
      Rails.logger.warn "Failed to update conversation activity: #{e.message}"
      # Continue without Redis cache update
    end
  end
  
  def track_message_metrics(message)
    date_key = Date.current.to_s
    
    # Track total messages using WebSocket service
    WebsocketService.track_metric("websocket.messages.created.total")
    WebsocketService.track_metric("websocket.messages.created.#{message.sender_type.downcase}")
    WebsocketService.track_metric("websocket.messages.created.type.#{message.message_type}")
    
    # Track daily metrics
    WebsocketService.track_metric("websocket.messages.daily.#{date_key}")
  end
  
  def post_message_processing(conversation, message)
    begin
      # Queue notification job for offline participants
      NotifyOfflineParticipantsJob.perform_later(conversation.id, message.id)
      
      # Update conversation participants' unread counts
      # Try to perform immediately first, fallback to queue if Sidekiq is not available
      begin
        UpdateUnreadCountsJob.perform_now(conversation.id, message.id)
      rescue StandardError => e
        Rails.logger.warn "Failed to perform UpdateUnreadCountsJob immediately, queuing instead: #{e.message}"
        UpdateUnreadCountsJob.perform_later(conversation.id, message.id)
      end
      
      # Content moderation (if enabled)
      if Rails.application.config.content_moderation_enabled
        ContentModerationJob.perform_later(message.id)
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to process post-message hooks: #{e.message}"
      # Continue without post-processing
    end
  end
  
  def notify_sender_of_error(sender_user, sender_session, error_message)
    return unless sender_user && sender_session
    
    ActionCable.server.broadcast(
      "conversations_#{sender_user.user_type.downcase}_#{sender_user.id}",
      {
        type: 'message_error',
        error: 'Failed to send message',
        details: error_message,
        session_id: sender_session,
        timestamp: Time.current.iso8601
      }
    )
  rescue StandardError => e
    Rails.logger.error "Failed to notify sender of error: #{e.message}"
  end
  
  def increment_metric(metric_name, value = 1)
    metric_key = "metrics:#{metric_name}:#{Date.current}"
    RedisConnection.incrby(metric_key, value)
    RedisConnection.expire(metric_key, 86400)
  rescue StandardError => e
    Rails.logger.debug "Metric tracking failed: #{e.message}"
  end
end
