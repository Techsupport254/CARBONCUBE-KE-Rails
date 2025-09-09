class JsonWebToken
    SECRET_KEY = Rails.application.credentials.secret_key_base&.to_s || 
                 Rails.application.secret_key_base || 
                 'development_secret_key_change_in_production'

    def self.encode(payload, exp = 24.hours.from_now)
        payload[:exp] = exp.to_i
        JWT.encode(payload, SECRET_KEY)
    end

    def self.decode(token)
        return nil if token.blank?
        
        # Check if token has the correct format (3 parts separated by dots)
        parts = token.split('.')
        if parts.length != 3
            Rails.logger.error "JWT Decode Error: Invalid token format - expected 3 parts, got #{parts.length}"
            return nil
        end
        
        body = JWT.decode(token, SECRET_KEY)[0]
        HashWithIndifferentAccess.new body
    rescue JWT::ExpiredSignature => e
        Rails.logger.error "JWT Decode Error: Token has expired - #{e.message}"
        nil
    rescue JWT::DecodeError => e
        Rails.logger.error "JWT Decode Error: #{e.message}"
        nil
    rescue => e
        Rails.logger.error "JWT Decode Error: #{e.message}"
        nil
    end
end