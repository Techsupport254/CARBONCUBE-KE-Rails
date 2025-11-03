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
      buyer = Buyer.find_by(id: buyer_id)
      if buyer && !buyer.deleted?
        return buyer
      elsif buyer&.deleted?
        Rails.logger.error "BuyerAuthorizeApiRequest: Buyer #{buyer_id} is deleted"
      end
    end

    # Try to find buyer by email if ID didn't work
    if buyer_email
      buyer = Buyer.find_by(email: buyer_email)
      if buyer && !buyer.deleted?
        return buyer
      elsif buyer&.deleted?
        Rails.logger.error "BuyerAuthorizeApiRequest: Buyer with email #{buyer_email} is deleted"
      end
    end

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
