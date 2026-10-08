class JsonWebToken
    # Fail loudly when the signing secret is missing — a committed fallback
    # would let anyone forge tokens.
    SECRET_KEY = Rails.application.secret_key_base.presence ||
                 raise('secret_key_base is not configured')
    
    ALGORITHM = 'HS256'

    def self.encode(payload, exp = nil)
        # Default to 60 days for maximum session persistence
        exp ||= 60.days.from_now
        payload[:exp] = exp.to_i
        payload[:jti] = SecureRandom.uuid unless payload[:jti]
        JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    def self.decode(token)
        return { success: false, error: 'Token is blank' } if token.blank?
        
        # Check if token has the correct format (3 parts separated by dots)
        parts = token.split('.')
        if parts.length != 3
            # Malformed Authorization headers are routine client noise, not app errors
            Rails.logger.debug "JWT Decode Error: Invalid token format - expected 3 parts, got #{parts.length}"
            return { success: false, error: 'Invalid token format' }
        end

        body = JWT.decode(token, SECRET_KEY, true, { algorithm: ALGORITHM, exp_leeway: 60, leeway: 60 })[0]
        payload = HashWithIndifferentAccess.new(body)

        # Check if token has been blacklisted (revoked via logout).
        # Fail open like JwtService.blacklisted? — a Redis outage must not
        # invalidate every valid token in flight.
        if payload[:jti].present?
            begin
                return { success: false, error: 'Token has been revoked' } if RedisConnection.exists?("blacklisted_token:#{payload[:jti]}")
            rescue StandardError => e
                Rails.logger.warn "JWT blacklist check failed, continuing: #{e.message}"
            end
        end

        { success: true, payload: payload }
    rescue JWT::ExpiredSignature => e
        begin
            expired_payload = JWT.decode(token, nil, false)[0]
            exp = expired_payload['exp']
            Rails.logger.debug "JWT Decode Error: Token has expired - exp: #{exp}, now: #{Time.now.to_i}, diff: #{Time.now.to_i - exp.to_i}s, jti: #{expired_payload['jti']}"
        rescue => diagnostic_err
            Rails.logger.debug "JWT Decode Error: Token has expired - #{e.message}"
        end
        { success: false, error: 'Token has expired', expired: true }
    rescue JWT::VerificationError => e
        # Structurally valid JWT signed with a different secret — stale
        # cross-environment credential, not a malformed token.
        Rails.logger.debug "JWT Decode Error: #{e.message}"
        { success: false, error: 'Invalid token signature' }
    rescue JWT::DecodeError => e
        # Only log decode errors at debug level - they might be expected (malformed tokens from clients)
        Rails.logger.debug "JWT Decode Error: #{e.message}"
        { success: false, error: 'Invalid token format' }
    rescue => e
        # Only log unexpected errors as warnings
        Rails.logger.warn "JWT Decode Error: #{e.message}"
        { success: false, error: 'Token validation failed' }
    end

end