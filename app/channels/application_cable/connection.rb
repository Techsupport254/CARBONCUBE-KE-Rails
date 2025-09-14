module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :session_id
    
    def connect
      authenticate_user!
      setup_session
      track_connection
      Rails.logger.info "🔌 WebSocket connection established for user #{current_user.id}"
    end
    
    def disconnect
      track_disconnection
      Rails.logger.info "🔌 WebSocket connection closed for user #{current_user&.id}"
    end
    
    private
    
    def authenticate_user!
      token = extract_token
      
      if token
        decoded_token = JsonWebToken.decode(token)
        if decoded_token
          self.current_user = find_user_from_token(decoded_token)
          if current_user
            self.session_id = decoded_token['session_id'] || SecureRandom.uuid
            verify_session_validity!
            return
          end
        end
      end
      
      # TEMPORARY: Allow connection without authentication for debugging
      Rails.logger.warn "No valid token found, but allowing connection for debugging"
      # Create a dummy user for testing
      self.current_user = OpenStruct.new(
        id: 999,
        user_type: 'debug',
        email: 'debug@example.com'
      )
      self.session_id = SecureRandom.uuid
      return
      
      # If no token or invalid token, try to extract from subscription params
      # This is a fallback for when frontend sends user info directly
      Rails.logger.warn "No valid token found, connection will be rejected"
      reject_unauthorized_connection
    rescue StandardError => e
      Rails.logger.error "WebSocket authentication failed: #{e.message}"
      # TEMPORARY: Allow connection even on error for debugging
      Rails.logger.warn "Allowing connection despite authentication error for debugging"
      self.current_user = OpenStruct.new(
        id: 999,
        user_type: 'debug',
        email: 'debug@example.com'
      )
      self.session_id = SecureRandom.uuid
    end
    
    def extract_token
      # Try multiple token sources
      request.params[:token] ||
        request.headers['Authorization']&.gsub(/^Bearer /, '') ||
        cookies.signed[:ws_token]
    end
    
    def find_user_from_token(decoded_token)
      # Handle different token formats based on user type
      if decoded_token['seller_id']
        Seller.find_by(id: decoded_token['seller_id'])
      elsif decoded_token['user_id']
        # Try to find user in different models based on role
        role = decoded_token['role']
        case role&.downcase
        when 'buyer'
          Buyer.find_by(id: decoded_token['user_id'])
        when 'admin'
          Admin.find_by(id: decoded_token['user_id'])
        when 'sales'
          SalesUser.find_by(id: decoded_token['user_id'])
        when 'rider'
          Rider.find_by(id: decoded_token['user_id'])
        else
          # Fallback: try all models
          Buyer.find_by(id: decoded_token['user_id']) ||
          Admin.find_by(id: decoded_token['user_id']) ||
          SalesUser.find_by(id: decoded_token['user_id']) ||
          Rider.find_by(id: decoded_token['user_id'])
        end
      else
        nil
      end
    end
    
    def verify_session_validity!
      # Check if user session is still valid
      session_key = "user_session:#{current_user.id}:#{session_id}"
      session_data = Redis.current.get(session_key)
      
      unless session_data
        Rails.logger.warn "No session data found for user #{current_user.id}, creating new session"
        # Create a new session instead of rejecting
        create_new_session
      end
    end
    
    def create_new_session
      session_key = "user_session:#{current_user.id}:#{session_id}"
      session_data = {
        user_id: current_user.id,
        session_id: session_id,
        user_type: current_user.user_type,
        created_at: Time.current.iso8601,
        expires_at: 2.hours.from_now.iso8601,
        active: true
      }
      
      Redis.current.setex(session_key, 7200, session_data.to_json)
    end
    
    def setup_session
      # Store connection info in Redis for tracking
      connection_key = "ws_connection:#{current_user.id}:#{session_id}"
      connection_data = {
        user_id: current_user.id,
        session_id: session_id,
        connected_at: Time.current.iso8601,
        remote_ip: request.remote_ip,
        user_agent: request.headers['User-Agent']
      }
      
      Redis.current.setex(connection_key, 3600, connection_data.to_json)
    end
    
    def track_connection
      # Increment connection metrics
      increment_metric('websocket.connections.total')
      increment_metric("websocket.connections.user_type.#{current_user.user_type}")
    end
    
    def track_disconnection
      return unless current_user
      
      # Clean up connection tracking
      connection_key = "ws_connection:#{current_user.id}:#{session_id}"
      Redis.current.del(connection_key)
      
      # Track disconnection metrics
      increment_metric('websocket.disconnections.total')
    end
    
    def increment_metric(metric_name, value = 1)
      # Simple Redis-based metrics (can be replaced with Prometheus)
      metric_key = "metrics:#{metric_name}:#{Date.current}"
      Redis.current.incrby(metric_key, value)
      Redis.current.expire(metric_key, 86400) # Expire after 24 hours
    rescue StandardError => e
      Rails.logger.warn "Failed to track metric #{metric_name}: #{e.message}"
    end
  end
end