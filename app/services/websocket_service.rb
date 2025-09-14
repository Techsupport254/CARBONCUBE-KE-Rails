# WebSocket Service with fallback mechanisms
class WebsocketService
  class << self
    # Check if WebSocket service is available
    def available?
      return false unless Rails.application.config.websocket_enabled
      
      begin
        # Try to ping Redis to check if WebSocket infrastructure is available
        Redis.current.ping == 'PONG'
      rescue StandardError
        false
      end
    end
    
    # Broadcast message with fallback
    def broadcast(channel, data)
      return false unless available?
      
      begin
        AnyCable.broadcast(channel, data)
        true
      rescue StandardError => e
        Rails.logger.warn "WebSocket broadcast failed: #{e.message}"
        false
      end
    end
    
    # Broadcast to conversation participants with fallback
    def broadcast_to_conversation(conversation, message_data, sender_session = nil)
      return false unless available?
      
      success = true
      
      # Broadcast to buyer
      if conversation.buyer_id
        unless broadcast("conversations_buyer_#{conversation.buyer_id}", {
          type: 'new_message',
          conversation_id: conversation.id,
          message: message_data,
          timestamp: Time.current.iso8601
        })
          success = false
        end
      end
      
      # Broadcast to seller
      if conversation.seller_id
        unless broadcast("conversations_seller_#{conversation.seller_id}", {
          type: 'new_message',
          conversation_id: conversation.id,
          message: message_data,
          timestamp: Time.current.iso8601
        })
          success = false
        end
      end
      
      # Broadcast to inquirer seller (if different from main seller)
      if conversation.inquirer_seller_id && conversation.inquirer_seller_id != conversation.seller_id
        unless broadcast("conversations_seller_#{conversation.inquirer_seller_id}", {
          type: 'new_message',
          conversation_id: conversation.id,
          message: message_data,
          timestamp: Time.current.iso8601
        })
          success = false
        end
      end
      
      success
    end
    
    # Send error notification with fallback
    def notify_error(user, session_id, error_message)
      return false unless available? && user
      
      broadcast("conversations_#{user.user_type.downcase}_#{user.id}", {
        type: 'message_error',
        error: 'Failed to send message',
        details: error_message,
        session_id: session_id,
        timestamp: Time.current.iso8601
      })
    end
    
    # Store connection data with fallback
    def store_connection_data(user_id, session_id, connection_data)
      return false unless available?
      
      begin
        connection_key = "ws_connection:#{user_id}:#{session_id}"
        Redis.current.setex(connection_key, 3600, connection_data.to_json)
        true
      rescue StandardError => e
        Rails.logger.warn "Failed to store WebSocket connection data: #{e.message}"
        false
      end
    end
    
    # Remove connection data with fallback
    def remove_connection_data(user_id, session_id)
      return false unless available?
      
      begin
        connection_key = "ws_connection:#{user_id}:#{session_id}"
        Redis.current.del(connection_key)
        true
      rescue StandardError => e
        Rails.logger.warn "Failed to remove WebSocket connection data: #{e.message}"
        false
      end
    end
    
    # Track metrics with fallback
    def track_metric(metric_name, value = 1)
      return false unless available?
      
      begin
        metric_key = "metrics:#{metric_name}:#{Date.current}"
        Redis.current.incrby(metric_key, value)
        Redis.current.expire(metric_key, 86400)
        true
      rescue StandardError => e
        Rails.logger.debug "Failed to track metric #{metric_name}: #{e.message}"
        false
      end
    end
    
    # Get WebSocket status for monitoring
    def status
      {
        enabled: Rails.application.config.websocket_enabled,
        available: available?,
        redis_connected: redis_connected?,
        anycable_available: anycable_available?
      }
    end
    
    private
    
    def redis_connected?
      begin
        Redis.current.ping == 'PONG'
      rescue StandardError
        false
      end
    end
    
    def anycable_available?
      begin
        # Check if AnyCable is available in the current environment
        defined?(AnyCable) && AnyCable.respond_to?(:broadcast)
      rescue StandardError
        false
      end
    end
  end
end

