class JsonWebToken
    SECRET_KEY = Rails.application.credentials.secret_key_base&.to_s || 
                 Rails.application.secret_key_base || 
                 'development_secret_key_change_in_production'
    
    ALGORITHM = 'HS256'

    def self.encode(payload, exp = 24.hours.from_now)
        payload[:exp] = exp.to_i
        JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    def self.decode(token)
        return { success: false, error: 'Token is blank' } if token.blank?
        
        # Check if token has the correct format (3 parts separated by dots)
        parts = token.split('.')
        if parts.length != 3
            Rails.logger.error "JWT Decode Error: Invalid token format - expected 3 parts, got #{parts.length}"
            return { success: false, error: 'Invalid token format' }
        end
        
        body = JWT.decode(token, SECRET_KEY, true, { algorithm: ALGORITHM })[0]
        { success: true, payload: HashWithIndifferentAccess.new(body) }
    rescue JWT::ExpiredSignature => e
        Rails.logger.warn "JWT Decode Error: Token has expired - #{e.message}"
        { success: false, error: 'Token has expired', expired: true }
    rescue JWT::DecodeError => e
        Rails.logger.error "JWT Decode Error: #{e.message}"
        { success: false, error: 'Invalid token format' }
    rescue => e
        Rails.logger.error "JWT Decode Error: #{e.message}"
        { success: false, error: 'Token validation failed' }
    end

    # Legacy method for backward compatibility - returns nil on error
    def self.decode_legacy(token)
        result = decode(token)
        result[:success] ? result[:payload] : nil
    end
end