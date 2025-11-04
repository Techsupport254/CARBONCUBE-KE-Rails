# app/services/buyer_authorize_api_request.rb

class BuyerAuthorizeApiRequest
  def initialize(headers = {})
    @headers = headers
  end

  def result
    @buyer ||= find_buyer
  end

  private

  def find_buyer
    decoded_result = decoded_token
    
    unless decoded_result[:success]
      # Only log as error if token was provided but invalid (not just missing)
      if decoded_result[:missing_token]
        Rails.logger.debug "BuyerAuthorizeApiRequest: No token provided"
      else
        Rails.logger.error "BuyerAuthorizeApiRequest: Token validation failed: #{decoded_result[:error]}"
      end
      raise ExceptionHandler::InvalidToken, decoded_result[:error]
    end
    
    payload = decoded_result[:payload]
    buyer_id = payload[:user_id]
    buyer_email = payload[:email]
    role = payload[:role]

    # Check if the token is actually for a buyer
    if role && role.downcase != 'buyer'
      Rails.logger.debug "BuyerAuthorizeApiRequest: Token is for #{role}, not buyer. Email: #{buyer_email}"
      raise ExceptionHandler::InvalidToken, "Token is for #{role}, not buyer"
    end

    # Try to find buyer by ID first
    if buyer_id
      Rails.logger.debug "BuyerAuthorizeApiRequest: Looking for buyer with ID: #{buyer_id} (type: #{buyer_id.class.name})"
      
      # Check if buyer_id is numeric (old format) but database uses UUIDs
      if buyer_id.is_a?(Integer) || buyer_id.is_a?(String) && buyer_id.match?(/^\d+$/)
        Rails.logger.warn "BuyerAuthorizeApiRequest: Token contains numeric ID #{buyer_id}, but buyers now use UUIDs. Will try email lookup."
      end
      
      buyer = Buyer.find_by(id: buyer_id)
      if buyer && !buyer.deleted?
        Rails.logger.debug "BuyerAuthorizeApiRequest: Found buyer: #{buyer.id} (type: #{buyer.id.class.name})"
        return buyer
      elsif buyer&.deleted?
        Rails.logger.error "BuyerAuthorizeApiRequest: Buyer #{buyer_id} is deleted"
      else
        Rails.logger.warn "BuyerAuthorizeApiRequest: Buyer with ID #{buyer_id} not found in database (may be old numeric ID, trying email...)"
      end
    end

    # Try to find buyer by email if ID didn't work (this handles old tokens with numeric IDs)
    if buyer_email
      Rails.logger.debug "BuyerAuthorizeApiRequest: Looking for buyer with email: #{buyer_email}"
      buyer = Buyer.find_by(email: buyer_email)
      if buyer && !buyer.deleted?
        Rails.logger.info "BuyerAuthorizeApiRequest: Found buyer by email: #{buyer.id} (UUID) - token had ID: #{buyer_id} (may be old numeric ID)"
        return buyer
      elsif buyer&.deleted?
        Rails.logger.error "BuyerAuthorizeApiRequest: Buyer with email #{buyer_email} is deleted"
      else
        Rails.logger.warn "BuyerAuthorizeApiRequest: Buyer with email #{buyer_email} not found in database"
      end
    end

    Rails.logger.error "BuyerAuthorizeApiRequest: Could not find buyer with ID: #{buyer_id}, email: #{buyer_email}"
    raise ExceptionHandler::InvalidToken, 'Invalid token'
  end

  def decoded_token
    @decoded_token ||= begin
      token = http_auth_header
      return { success: false, error: 'No token provided' } if token.blank?
      
      Rails.logger.debug "BuyerAuthorizeApiRequest: Attempting to decode token: #{token[0..20]}..."
      JsonWebToken.decode(token)
    rescue ExceptionHandler::MissingToken => e
      # Missing token is normal for public endpoints, only log at debug level
      Rails.logger.debug "BuyerAuthorizeApiRequest: #{e.message}"
      { success: false, error: 'No token provided', missing_token: true }
    rescue => e
      # Only log as error if token was provided but invalid
      Rails.logger.error "BuyerAuthorizeApiRequest: JWT Decode Error: #{e.message}"
      { success: false, error: 'Token validation failed' }
    end
  end

  def http_auth_header
    if @headers['Authorization'].present?
      auth_header = @headers['Authorization']
      if auth_header.start_with?('Bearer ')
        return auth_header.split(' ').last
      else
        # Sometimes the token might be passed without 'Bearer ' prefix
        return auth_header
      end
    else
      # Don't log missing tokens - they're normal for public endpoints
      raise ExceptionHandler::MissingToken, 'Missing token'
    end
  end
end
