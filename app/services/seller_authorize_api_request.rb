class SellerAuthorizeApiRequest
  def initialize(headers = {})
    @headers = headers
  end

  def result
    @seller ||= find_seller
  end

  private

  def find_seller
    decoded_result = decoded_token
    
    unless decoded_result[:success]
      # Only log as error if token was provided but invalid (not just missing)
      if decoded_result[:missing_token]
        Rails.logger.debug "SellerAuthorizeApiRequest: No token provided"
      else
        Rails.logger.error "SellerAuthorizeApiRequest: Token validation failed: #{decoded_result[:error]}"
      end
      raise ExceptionHandler::InvalidToken, decoded_result[:error]
    end
    
    payload = decoded_result[:payload]
    
    seller_id = payload[:seller_id]
    seller_email = payload[:email]
    role = payload[:role]

    # Check if the token is actually for a seller
    if role && role.downcase != 'seller'
      Rails.logger.debug "SellerAuthorizeApiRequest: Token is for #{role}, not seller. Email: #{seller_email}"
      raise ExceptionHandler::InvalidToken, "Token is for #{role}, not seller"
    end

    # Try to find seller by ID first
    if seller_id
      seller = Seller.find_by(id: seller_id)
      if seller && !seller.deleted?
        return seller
      elsif seller&.deleted?
        Rails.logger.error "SellerAuthorizeApiRequest: Seller #{seller_id} is deleted"
      else
        Rails.logger.error "SellerAuthorizeApiRequest: Seller #{seller_id} not found in database"
      end
    end

    # Try to find seller by email if ID didn't work
    if seller_email
      seller = Seller.find_by(email: seller_email)
      if seller && !seller.deleted?
        return seller
      elsif seller&.deleted?
        Rails.logger.error "SellerAuthorizeApiRequest: Seller with email #{seller_email} is deleted"
      else
        Rails.logger.error "SellerAuthorizeApiRequest: Seller with email #{seller_email} not found in database"
      end
    end

    # Create detailed error message with the attempted seller information
    error_details = []
    error_details << "ID: #{seller_id}" if seller_id
    error_details << "Email: #{seller_email}" if seller_email
    error_message = "No seller found"
    error_message += " (#{error_details.join(', ')})" if error_details.any?
    
    Rails.logger.error "SellerAuthorizeApiRequest: #{error_message}, raising InvalidToken"
    Rails.logger.error "SellerAuthorizeApiRequest: Detailed error - Seller ID: #{seller_id || 'nil'}, Email: #{seller_email || 'nil'}"
    raise ExceptionHandler::InvalidToken, error_message
  end

  def decoded_token
    @decoded_token ||= begin
      token = http_auth_header
      return { success: false, error: 'No token provided' } if token.blank?
      
      JsonWebToken.decode(token)
    rescue ExceptionHandler::MissingToken => e
      # Missing token is normal for public endpoints, only log at debug level
      Rails.logger.debug "SellerAuthorizeApiRequest: #{e.message}"
      { success: false, error: 'No token provided', missing_token: true }
    rescue => e
      # Only log as error if token was provided but invalid
      Rails.logger.error "SellerAuthorizeApiRequest: JWT Decode Error: #{e.message}"
      { success: false, error: 'Token validation failed' }
    end
  end

  def http_auth_header
    authorization_header = @headers['Authorization']
    
    if authorization_header.present?
      if authorization_header.start_with?('Bearer ')
        token = authorization_header.split(' ').last
        return token
      else
        # Sometimes the token might be passed without 'Bearer ' prefix
        Rails.logger.debug "SellerAuthorizeApiRequest: Token without Bearer prefix"
        return authorization_header
      end
    else
      # Don't log missing tokens - they're normal for public endpoints
      raise ExceptionHandler::MissingToken, 'Missing token'
    end
  end
end
