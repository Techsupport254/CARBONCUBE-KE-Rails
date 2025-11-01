module ApplicationCable
  class Channel < ActionCable::Channel::Base
    # Rate limiting configuration
    RATE_LIMIT_WINDOW = 60 # seconds
    RATE_LIMIT_MAX_REQUESTS = 100
    
    protected
    
    def rate_limited?
      user = connection.current_user
      return false unless user
      
      rate_limit_key = "rate_limit:#{user.id}:#{self.class.name}"
      current_count = RedisConnection.get(rate_limit_key).to_i
      
      if current_count >= RATE_LIMIT_MAX_REQUESTS
        Rails.logger.warn "Rate limit exceeded for user #{user.id} on #{self.class.name}"
        transmit({ error: "Rate limit exceeded. Please slow down." })
        return true
      end
      
      RedisConnection.with do |conn|
        conn.multi do |multi|
          multi.incr(rate_limit_key)
          multi.expire(rate_limit_key, RATE_LIMIT_WINDOW)
        end
      end
      
      false
    rescue StandardError => e
      Rails.logger.error "Rate limiting error: #{e.message}"
      false # Fail open
    end
    
    def validate_and_sanitize_data(data, schema_class)
      result = schema_class.new.call(data)
      
      unless result.success?
        transmit({ 
          error: "Invalid data", 
          details: result.errors.to_h 
        })
        return nil
      end
      
      result.output
    rescue StandardError => e
      Rails.logger.error "Data validation error: #{e.message}"
      transmit({ error: "Data validation failed" })
      nil
    end
    
    def broadcast_with_retry(channel_name, data, max_retries: 3)
      retries = 0
      
      begin
        ActionCable.server.broadcast(channel_name, data)
        track_broadcast_metric(channel_name)
      rescue StandardError => e
        retries += 1
        if retries <= max_retries
          Rails.logger.warn "Broadcast retry #{retries}/#{max_retries} for #{channel_name}: #{e.message}"
          sleep(0.1 * retries) # Exponential backoff
          retry
        else
          Rails.logger.error "Broadcast failed for #{channel_name} after #{max_retries} retries: #{e.message}"
          raise e
        end
      end
    end
    
    def track_message_metric(action)
      metric_key = "websocket.messages.#{self.class.name.underscore}.#{action}"
      increment_metric(metric_key)
    end
    
    def track_broadcast_metric(channel_name)
      metric_key = "websocket.broadcasts.#{channel_name.split('_').first}"
      increment_metric(metric_key)
    end
    
    def increment_metric(metric_name, value = 1)
      metric_key = "metrics:#{metric_name}:#{Date.current}"
      RedisConnection.incrby(metric_key, value)
      RedisConnection.expire(metric_key, 86400)
    rescue StandardError => e
      Rails.logger.debug "Metric tracking failed: #{e.message}"
    end
    
    def log_channel_activity(action, details = {})
      Rails.logger.info({
        channel: self.class.name,
        action: action,
        user_id: connection.current_user&.id,
        session_id: connection.session_id,
        timestamp: Time.current.iso8601,
        details: details
      }.to_json)
    end
  end
end