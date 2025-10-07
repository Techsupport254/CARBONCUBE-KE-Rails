module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :session_id
    
    # Simple in-memory connection tracking to prevent spam
    @@active_connections = {}
    @@connection_lock = Mutex.new
    
    def connect
      Rails.logger.info "🔌 WebSocket: CONNECT METHOD CALLED"
      
      # Check for existing connections to prevent spam
      @connection_attempt_time = Time.current
      @connection_id = SecureRandom.uuid
      
      # Reduce debug logging to prevent spam
      Rails.logger.info "WebSocket: Connection attempt #{@connection_id} from #{request.remote_ip rescue 'unknown'}"
      
      begin
        authenticate_user!
        setup_session
        track_connection
        
        Rails.logger.info "🔌 WebSocket connection established for user #{current_user&.id || 'anonymous'}"
      rescue StandardError => e
        Rails.logger.error "WebSocket connection setup failed: #{e.message}"
        Rails.logger.error "WebSocket connection setup backtrace: #{e.backtrace.first(5).join("\n")}"
        
        # Only try fallback if we don't have a current_user
        unless current_user
          begin
            Rails.logger.info "WebSocket: Attempting fallback authentication"
            authenticate_user_fallback!
            Rails.logger.info "🔌 WebSocket connection established via fallback for user #{current_user&.id || 'anonymous'}"
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
        
        Rails.logger.info "🔌 WebSocket connection closed for user #{current_user&.id}"
      rescue StandardError => e
        Rails.logger.error "WebSocket disconnection tracking failed: #{e.message}"
        # Don't prevent disconnection even if tracking fails
      end
    end
    
    private
    
    def authenticate_user!
      token = extract_token
      
      if token
        Rails.logger.info "WebSocket: Token found, attempting to decode: #{token[0..20]}..."
        decoded_result = JsonWebToken.decode(token)
        
        if decoded_result[:success]
          self.current_user = find_user_from_token(decoded_result[:payload])
          if current_user
            Rails.logger.info "WebSocket: User authenticated successfully - #{current_user.class.name} ID: #{current_user.id}"
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
      else
        Rails.logger.info "WebSocket: No token provided"
      end
      
      # If no token or invalid token, allow connection to proceed
      # Authentication will be handled during subscription creation
      Rails.logger.info "WebSocket: No valid token found, allowing connection to proceed for subscription-based auth"
      # Don't reject the connection - let it proceed and handle auth during subscription
    rescue StandardError => e
      Rails.logger.warn "WebSocket authentication failed: #{e.message}"
      # Don't reject the connection - let it proceed for subscription-based auth
      Rails.logger.info "WebSocket: Allowing connection to proceed despite authentication failure for subscription-based auth"
    end
    
    def authenticate_user_fallback!
      # Fallback authentication that's more lenient for WebSocket connections
      Rails.logger.debug "WebSocket: Attempting fallback authentication"
      
      # Try to extract user info from subscription parameters if available
      if request.params[:user_type] && request.params[:user_id]
        user_type = request.params[:user_type]
        user_id = request.params[:user_id].to_i
        
        Rails.logger.debug "WebSocket fallback: Trying to find user #{user_id} of type #{user_type}"
        
        case user_type.downcase
        when 'seller'
          seller = Seller.find_by(id: user_id)
          if seller && !seller.deleted?
            self.current_user = seller
            self.session_id = SecureRandom.uuid
            Rails.logger.info "WebSocket fallback: Successfully authenticated seller #{seller.id}"
            return
          else
            Rails.logger.debug "WebSocket fallback: Seller #{user_id} not found or deleted"
          end
        when 'buyer'
          buyer = Buyer.find_by(id: user_id)
          if buyer && !buyer.deleted?
            self.current_user = buyer
            self.session_id = SecureRandom.uuid
            Rails.logger.info "WebSocket fallback: Successfully authenticated buyer #{buyer.id}"
            return
          else
            Rails.logger.debug "WebSocket fallback: Buyer #{user_id} not found or deleted"
          end
        when 'admin'
          admin = Admin.find_by(id: user_id)
          if admin
            self.current_user = admin
            self.session_id = SecureRandom.uuid
            Rails.logger.info "WebSocket fallback: Successfully authenticated admin #{admin.id}"
            return
          else
            Rails.logger.debug "WebSocket fallback: Admin #{user_id} not found"
          end
        when 'sales'
          sales_user = SalesUser.find_by(id: user_id)
          if sales_user
            self.current_user = sales_user
            self.session_id = SecureRandom.uuid
            Rails.logger.info "WebSocket fallback: Successfully authenticated sales user #{sales_user.id}"
            return
          else
            Rails.logger.debug "WebSocket fallback: Sales user #{user_id} not found"
          end
        else
          Rails.logger.debug "WebSocket fallback: Unknown user type: #{user_type}"
        end
      else
        Rails.logger.debug "WebSocket fallback: No user_type or user_id in request params"
      end
      
      Rails.logger.info "WebSocket fallback: No valid user found, allowing connection to proceed for subscription-based auth"
      # Don't reject the connection - let it proceed for subscription-based auth
    end
    
    def extract_token
      # Try multiple token sources in order of preference
      token = nil
      
      # Reduce debug logging to prevent spam - only log on first connection
      if @first_connection_attempt
        Rails.logger.info "WebSocket: Token extraction for #{request.remote_ip rescue 'unknown'}"
        @first_connection_attempt = false
      end
      
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
      
      # Only log token info if debug is enabled
      if Rails.env.development? && token.present?
        Rails.logger.debug "WebSocket: Found token (#{token[0..10]}...)"
      end
      
      token
    end
    
    def find_user_from_token(payload)
      Rails.logger.info "WebSocket: Finding user from token payload: #{payload.inspect}"
      
      # Handle different token formats based on user type
      # Sellers use seller_id field
      if payload['seller_id']
        seller_id = payload['seller_id'].to_i
        role = payload['role']
        
        # Verify the role matches
        if role && role != 'Seller'
          Rails.logger.error "WebSocket: Token has seller_id but role is #{role}, not seller"
          return nil
        end
        
        Rails.logger.info "WebSocket: Looking for seller with ID: #{seller_id}"
        seller = Seller.find_by(id: seller_id)
        if seller
          Rails.logger.info "WebSocket: Found seller: #{seller.id}, deleted: #{seller.deleted?}"
          return seller unless seller.deleted?
          Rails.logger.error "WebSocket: Seller #{seller_id} is deleted"
        else
          Rails.logger.error "WebSocket: Seller #{seller_id} not found in database"
        end
        return nil
      end
      
      
      # Buyers, Admins, Sales use user_id field with role
      if payload['user_id']
        user_id = payload['user_id'].to_i
        role = payload['role']
        Rails.logger.info "WebSocket: Looking for user with ID: #{user_id}, role: #{role}"
        
        # Try to find user in different models based on role
        case role&.downcase
        when 'buyer'
          buyer = Buyer.find_by(id: user_id)
          if buyer
            Rails.logger.info "WebSocket: Found buyer: #{buyer.id}, deleted: #{buyer.deleted?}"
            return buyer unless buyer.deleted?
            Rails.logger.error "WebSocket: Buyer #{user_id} is deleted"
          else
            Rails.logger.error "WebSocket: Buyer #{user_id} not found in database"
          end
        when 'admin'
          admin = Admin.find_by(id: user_id)
          if admin
            Rails.logger.info "WebSocket: Found admin: #{admin.id}"
            return admin
          else
            Rails.logger.error "WebSocket: Admin #{user_id} not found in database"
          end
        when 'sales'
          sales_user = SalesUser.find_by(id: user_id)
          if sales_user
            Rails.logger.info "WebSocket: Found sales user: #{sales_user.id}"
            return sales_user
          else
            Rails.logger.error "WebSocket: Sales user #{user_id} not found in database"
          end
        else
          # Fallback: try all models if no specific role
          Rails.logger.info "WebSocket: No specific role, trying all models"
          buyer = Buyer.find_by(id: user_id)
          if buyer && !buyer.deleted?
            Rails.logger.info "WebSocket: Found buyer via fallback: #{buyer.id}"
            return buyer
          end
          admin = Admin.find_by(id: user_id)
          if admin
            Rails.logger.info "WebSocket: Found admin via fallback: #{admin.id}"
            return admin
          end
          sales_user = SalesUser.find_by(id: user_id)
          if sales_user
            Rails.logger.info "WebSocket: Found sales user via fallback: #{sales_user.id}"
            return sales_user
          end
        end
      end
      
      Rails.logger.warn "WebSocket: No user found for payload: #{payload.inspect}"
      nil
    end
    
    def verify_session_validity!
      # Check if user session is still valid
      session_key = "user_session:#{current_user.id}:#{session_id}"
      
      begin
        session_data = RedisConnection.get(session_key)
        
        unless session_data
          Rails.logger.warn "No session data found for user #{current_user.id}, creating new session"
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
        Rails.logger.info "WebSocket: Session setup completed for user #{current_user.id}"
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
        Rails.logger.info "WebSocket: Connection tracking completed for user #{current_user.id}"
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