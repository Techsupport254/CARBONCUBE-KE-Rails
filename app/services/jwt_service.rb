class JwtService
  # Use environment variable or generate a secure secret
  SECRET_KEY = Rails.application.credentials.secret_key_base || 
               ENV['JWT_SECRET_KEY'] || 
               Rails.application.config.secret_key_base

  # Algorithm for JWT encoding/decoding
  ALGORITHM = 'HS256'
  
  # Token expiration times
  ACCESS_TOKEN_EXPIRY = 1.hour
  REFRESH_TOKEN_EXPIRY = 30.days
  WEBSOCKET_TOKEN_EXPIRY = 2.hours

  class << self
    # Encode a JWT token
    def encode(payload, exp = ACCESS_TOKEN_EXPIRY.from_now)
      # Add standard claims
      payload[:exp] = exp.to_i
      payload[:iat] = Time.current.to_i
      payload[:jti] = generate_jti
      
      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    # Decode a JWT token
    def decode(token)
      decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: ALGORITHM })
      payload = decoded[0]
      
      # Validate token isn't blacklisted
      if blacklisted?(payload['jti'])
        raise JWT::InvalidTokenError, 'Token has been revoked'
      end
      
      HashWithIndifferentAccess.new(payload)
    rescue JWT::DecodeError => e
      Rails.logger.warn "JWT decode error: #{e.message}"
      nil
    end

    # Generate access token for user
    def generate_access_token(user)
      payload = {
        user_id: user.id,
        email: user.email,
        user_type: user.user_type,
        session_id: generate_session_id,
        token_type: 'access'
      }
      
      encode(payload, ACCESS_TOKEN_EXPIRY.from_now)
    end

    # Generate refresh token for user
    def generate_refresh_token(user)
      payload = {
        user_id: user.id,
        session_id: generate_session_id,
        token_type: 'refresh'
      }
      
      encode(payload, REFRESH_TOKEN_EXPIRY.from_now)
    end

    # Generate WebSocket token for real-time connections
    def generate_websocket_token(user, session_id = nil)
      # Use appropriate ID field based on user type
      payload = if user.is_a?(Seller)
        {
          seller_id: user.id,
          email: user.email,
          user_type: user.user_type,
          session_id: session_id || generate_session_id,
          token_type: 'websocket',
          permissions: websocket_permissions(user)
        }
      else
        {
          user_id: user.id,
          email: user.email,
          user_type: user.user_type,
          session_id: session_id || generate_session_id,
          token_type: 'websocket',
          permissions: websocket_permissions(user)
        }
      end
      
      token = encode(payload, WEBSOCKET_TOKEN_EXPIRY.from_now)
      
      # Store session info in Redis for validation
      store_websocket_session(payload)
      
      token
    end

    # Refresh an access token using a refresh token
    def refresh_access_token(refresh_token)
      payload = decode(refresh_token)
      return nil unless payload && payload['token_type'] == 'refresh'

      user = User.find_by(id: payload['user_id'])
      return nil unless user

      # Generate new access token
      generate_access_token(user)
    rescue StandardError => e
      Rails.logger.error "Token refresh failed: #{e.message}"
      nil
    end

    # Validate token and extract user
    def current_user_from_token(token)
      payload = decode(token)
      return nil unless payload

      user = User.find_by(id: payload['user_id'])
      return nil unless user

      # Validate session if it's a WebSocket token
      if payload['token_type'] == 'websocket'
        return nil unless valid_websocket_session?(payload)
      end

      user
    rescue StandardError => e
      Rails.logger.error "Token validation failed: #{e.message}"
      nil
    end

    # Blacklist a token (for logout)
    def blacklist_token(token)
      payload = decode(token)
      return false unless payload

      # Store JTI in Redis with expiration
      jti = payload['jti']
      exp = payload['exp']
      ttl = exp - Time.current.to_i

      if ttl > 0
        Redis.current.setex("blacklisted_token:#{jti}", ttl, true)
        
        # Also invalidate associated session
        if payload['session_id']
          invalidate_session(payload['session_id'], payload['user_id'])
        end
      end

      true
    rescue StandardError => e
      Rails.logger.error "Token blacklisting failed: #{e.message}"
      false
    end

    # Check if token is blacklisted
    def blacklisted?(jti)
      return false unless jti
      Redis.current.exists("blacklisted_token:#{jti}")
    rescue StandardError => e
      Rails.logger.warn "Blacklist check failed: #{e.message}"
      false # Fail open for availability
    end

    # Validate WebSocket session
    def valid_websocket_session?(payload)
      session_key = "user_session:#{payload['user_id']}:#{payload['session_id']}"
      session_data = Redis.current.get(session_key)
      
      return false unless session_data
      
      begin
        session_info = JSON.parse(session_data)
        # Check if session is still active and not expired
        session_info['active'] == true && 
        Time.parse(session_info['expires_at']) > Time.current
      rescue StandardError => e
        Rails.logger.warn "Session validation error: #{e.message}"
        false
      end
    end

    private

    # Generate unique JWT ID
    def generate_jti
      SecureRandom.uuid
    end

    # Generate session ID
    def generate_session_id
      SecureRandom.hex(16)
    end

    # Define WebSocket permissions based on user type
    def websocket_permissions(user)
      case user.user_type&.downcase
      when 'admin'
        %w[all_conversations moderate_content system_notifications]
      when 'seller'
        %w[seller_conversations product_updates order_notifications]
      when 'buyer'
        %w[buyer_conversations order_updates]
      else
        []
      end
    end

    # Store WebSocket session information
    def store_websocket_session(payload)
      session_key = "user_session:#{payload[:user_id]}:#{payload[:session_id]}"
      session_data = {
        user_id: payload[:user_id],
        session_id: payload[:session_id],
        user_type: payload[:user_type],
        permissions: payload[:permissions],
        created_at: Time.current.iso8601,
        expires_at: WEBSOCKET_TOKEN_EXPIRY.from_now.iso8601,
        active: true
      }

      # Store with expiration
      Redis.current.setex(session_key, WEBSOCKET_TOKEN_EXPIRY.to_i, session_data.to_json)
      
      # Track active sessions per user
      user_sessions_key = "user_sessions:#{payload[:user_id]}"
      Redis.current.sadd(user_sessions_key, payload[:session_id])
      Redis.current.expire(user_sessions_key, WEBSOCKET_TOKEN_EXPIRY.to_i)
    end

    # Invalidate a user session
    def invalidate_session(session_id, user_id)
      session_key = "user_session:#{user_id}:#{session_id}"
      Redis.current.del(session_key)
      
      user_sessions_key = "user_sessions:#{user_id}"
      Redis.current.srem(user_sessions_key, session_id)
    end
  end
end
