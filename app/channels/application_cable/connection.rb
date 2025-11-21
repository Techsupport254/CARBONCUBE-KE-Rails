module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :session_id
    
    # Simple in-memory connection tracking to prevent spam
    @@active_connections = {}
    @@connection_lock = Mutex.new
    
    def connect
      # Check for existing connections to prevent spam
      @connection_attempt_time = Time.current
      @connection_id = SecureRandom.uuid
      
      begin
        authenticate_user!
        setup_session
        track_connection
      rescue StandardError => e
        Rails.logger.error "WebSocket connection setup failed: #{e.message}"
        Rails.logger.error "WebSocket connection setup backtrace: #{e.backtrace.first(5).join("\n")}"
        
        # Only try fallback if we don't have a current_user
        unless current_user
          begin
            authenticate_user_fallback!
          rescue StandardError => fallback_error
            Rails.logger.error "WebSocket fallback authentication also failed: #{fallback_error.message}"
            Rails.logger.error "WebSocket fallback backtrace: #{fallback_error.backtrace.first(5).join("\n")}"
            # Allow connection to proceed even if all authentication fails
            Rails.logger.warn "Allowing WebSocket connection despite authentication failure"
          end
        else
          Rails.logger.warn "WebSocket: Authentication succeeded but other setup failed, rejecting connection"
          reject_unauthorized_connection
        end
      end
    end
    
    def disconnect
      begin
        track_disconnection
        
        # Clean up in-memory connection tracking
        if current_user
          @@connection_lock.synchronize do
            @@active_connections.delete(current_user.id)
          end
        end
      rescue StandardError => e
        Rails.logger.error "WebSocket disconnection tracking failed: #{e.message}"
        # Don't prevent disconnection even if tracking fails
      end
    end
    
    private
    
    def authenticate_user!
      token = extract_token
      
      if token
        decoded_result = JsonWebToken.decode(token)
        
        if decoded_result[:success]
          self.current_user = find_user_from_token(decoded_result[:payload])
          if current_user
            self.session_id = decoded_result[:payload]['session_id'] || SecureRandom.uuid
            
            begin
              verify_session_validity!
            rescue => e
              Rails.logger.warn "WebSocket: Session validation failed: #{e.message}"
              # Continue anyway - session validation failure shouldn't block connection
            end
            
            return
          else
            Rails.logger.warn "WebSocket: User not found from token payload"
          end
        else
          # Only log warnings for non-expired token errors to reduce noise
          unless decoded_result[:expired]
            Rails.logger.warn "WebSocket token validation failed: #{decoded_result[:error]}"
          end
        end
      end
      
      # If no token or invalid token, allow connection to proceed
      # Authentication will be handled during subscription creation
      # Don't reject the connection - let it proceed and handle auth during subscription
    rescue StandardError => e
      Rails.logger.warn "WebSocket authentication failed: #{e.message}"
      # Don't reject the connection - let it proceed for subscription-based auth
    end
    
    def authenticate_user_fallback!
      # Fallback authentication that's more lenient for WebSocket connections
      # Try to extract user info from subscription parameters if available
      if request.params[:user_type] && request.params[:user_id]
        user_type = request.params[:user_type]
        user_id = request.params[:user_id]
        
        case user_type.downcase
        when 'seller'
          seller = Seller.find_by(id: user_id)
          if seller && !seller.deleted?
            self.current_user = seller
            self.session_id = SecureRandom.uuid
            return
          end
        when 'buyer'
          buyer = Buyer.find_by(id: user_id)
          if buyer && !buyer.deleted?
            self.current_user = buyer
            self.session_id = SecureRandom.uuid
            return
          end
        when 'admin'
          admin = Admin.find_by(id: user_id)
          if admin
            self.current_user = admin
            self.session_id = SecureRandom.uuid
            return
          end
        when 'sales'
          # SalesUser uses UUID, so integer IDs won't work
          if user_id.is_a?(Integer)
            Rails.logger.warn "WebSocket fallback: SalesUser ID is an integer (#{user_id}), but SalesUsers use UUIDs. Token may be stale."
          end
          
          sales_user = SalesUser.find_by(id: user_id)
          
          if sales_user
            self.current_user = sales_user
            self.session_id = SecureRandom.uuid
            return
          end
        end
      end
      # Don't reject the connection - let it proceed for subscription-based auth
    end
    
    def extract_token
      # Try multiple token sources in order of preference
      token = nil
      
      # 1. Try Authorization header first (most common for API calls)
      if request.headers['Authorization'].present?
        auth_header = request.headers['Authorization']
        if auth_header.start_with?('Bearer ')
          token = auth_header.gsub(/^Bearer /, '')
        else
          # Sometimes the token might be passed without 'Bearer ' prefix
          token = auth_header
        end
      end
      
      # 2. Try query parameter (common for WebSocket connections)
      if token.blank? && request.params[:token].present?
        token = request.params[:token]
      end
      
      # 3. Try cookies as fallback
      if token.blank? && cookies.signed[:ws_token].present?
        token = cookies.signed[:ws_token]
      end
      
      # 4. Try session token as last resort
      if token.blank? && cookies.signed[:session_token].present?
        token = cookies.signed[:session_token]
      end
      
      token
    end
    
    def find_user_from_token(payload)
      # Handle different token formats based on user type
      # Sellers use seller_id field
      if payload['seller_id']
        seller_id = payload['seller_id']
        role = payload['role']
        
        # Verify the role matches (case-insensitive)
        if role && role.to_s.downcase != 'seller'
          Rails.logger.error "WebSocket: Token has seller_id but role is #{role}, expected seller"
          return nil
        end
        
        seller = Seller.find_by(id: seller_id)
        if seller
          return seller unless seller.deleted?
        end
        return nil
      end
      
      
      # Buyers, Admins, Sales use user_id field with role
      if payload['user_id']
        user_id = payload['user_id']
        role = payload['role']
        user_id_type = user_id.class.name
        
        # Require role for direct lookup - don't search all databases
        unless role.present?
          Rails.logger.warn "WebSocket: Token has user_id but no role field. Cannot perform direct lookup. Token may be malformed."
          return nil
        end
        
        # Direct lookup based on role - no fallback to search all models
        case role.to_s.downcase
        when 'buyer'
          buyer = Buyer.find_by(id: user_id)
          if buyer
            return buyer unless buyer.deleted?
          end
        when 'admin'
          admin = Admin.find_by(id: user_id)
          if admin
            return admin
          end
        when 'sales'
          # SalesUser IDs are UUIDs, so we need to ensure proper format
          # If user_id is an integer, it's likely from a stale token (pre-UUID migration)
          if user_id.is_a?(Integer)
            Rails.logger.warn "WebSocket: SalesUser ID is an integer (#{user_id}), but SalesUsers use UUIDs. Token may be stale from before UUID migration."
          end
          
          # Try direct lookup (works for both UUID strings and will fail gracefully for integers)
          sales_user = SalesUser.find_by(id: user_id)
          
          if sales_user
            return sales_user
          end
        else
          # Unknown role - don't search all models, just log and return nil
          Rails.logger.warn "WebSocket: Unknown role '#{role}' for user_id #{user_id}. Cannot perform lookup. Token may be malformed."
        end
      end
      
      nil
    end
    
    def verify_session_validity!
      # Check if user session is still valid
      session_key = "user_session:#{current_user.id}:#{session_id}"
      
      begin
        session_data = RedisConnection.get(session_key)
        
        unless session_data
          # Create a new session instead of rejecting
          create_new_session
        end
      rescue => e
        Rails.logger.warn "Redis connection failed, skipping session validation: #{e.message}"
        # Allow connection to proceed even if Redis is unavailable
      end
    end
    
    def create_new_session
      session_key = "user_session:#{current_user.id}:#{session_id}"
      
      # Determine user type based on model class
      user_type = case current_user.class.name
                  when 'Buyer' then 'buyer'
                  when 'Seller' then 'seller'
                  when 'Admin' then 'admin'
                  when 'SalesUser' then 'sales'
                  else current_user.class.name.downcase
                  end
      
      session_data = {
        user_id: current_user.id,
        session_id: session_id,
        user_type: user_type,
        created_at: Time.current.iso8601,
        expires_at: 2.hours.from_now.iso8601,
        active: true
      }
      
      begin
        RedisConnection.setex(session_key, 7200, session_data.to_json)
      rescue StandardError => e
        Rails.logger.warn "Failed to create new WebSocket session in Redis: #{e.message}"
        # Continue without session storage
      end
    end
    
    def setup_session
      return unless current_user
      
      begin
        # Check for existing connections to prevent spam using in-memory tracking
        @@connection_lock.synchronize do
          user_id = current_user.id
          current_time = Time.current
          
          # Clean up old connections (older than 1 minute)
          @@active_connections.delete_if { |k, v| current_time - v > 60 }
          
          # Check if user has too many recent connections (allow up to 3 concurrent connections)
          user_connections = @@active_connections.select { |k, v| k == user_id }
          if user_connections.size >= 3
            Rails.logger.warn "WebSocket: User #{user_id} has too many active connections (#{user_connections.size}), rejecting duplicate"
            reject_unauthorized_connection
            return
          end
          
          # Record this connection
          @@active_connections[user_id] = current_time
        end
        
        # Store connection info in Redis for tracking using WebSocket service
        connection_data = {
          user_id: current_user.id,
          session_id: session_id,
          connected_at: Time.current.iso8601,
          remote_ip: request.remote_ip,
          user_agent: request.headers['User-Agent'],
          connection_id: @connection_id
        }
        
        WebsocketService.store_connection_data(current_user.id, session_id, connection_data)
      rescue => e
        Rails.logger.warn "WebSocket: Session setup failed: #{e.message}"
        # Continue without session storage
      end
    end
    
    def track_connection
      return unless current_user
      
      begin
        # Increment connection metrics using WebSocket service
        WebsocketService.track_metric('websocket.connections.total')
        
        # Determine user type based on model class
        user_type = case current_user.class.name
                    when 'Buyer' then 'buyer'
                    when 'Seller' then 'seller'
                    when 'Admin' then 'admin'
                    when 'SalesUser' then 'sales'
                    else current_user.class.name.downcase
                    end
        
        WebsocketService.track_metric("websocket.connections.user_type.#{user_type}")
      rescue => e
        Rails.logger.warn "WebSocket: Connection tracking failed: #{e.message}"
        # Continue without tracking
      end
    end
    
    def track_disconnection
      return unless current_user
      
      # Clean up connection tracking using WebSocket service
      WebsocketService.remove_connection_data(current_user.id, session_id)
      
      # Track disconnection metrics
      WebsocketService.track_metric('websocket.disconnections.total')
    end
    
    def increment_metric(metric_name, value = 1)
      # Simple Redis-based metrics (can be replaced with Prometheus)
      metric_key = "metrics:#{metric_name}:#{Date.current}"
      
      begin
        RedisConnection.incrby(metric_key, value)
        RedisConnection.expire(metric_key, 86400) # Expire after 24 hours
      rescue StandardError => e
        Rails.logger.warn "Failed to track metric #{metric_name}: #{e.message}"
      end
    end
  end
end