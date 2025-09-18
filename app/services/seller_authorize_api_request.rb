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
      Rails.logger.error "SellerAuthorizeApiRequest: Token validation failed: #{decoded_result[:error]}"
      raise ExceptionHandler::InvalidToken, decoded_result[:error]
    end
    
    payload = decoded_result[:payload]
    Rails.logger.info "SellerAuthorizeApiRequest: Token payload: #{payload.inspect}"
    
    seller_id = payload[:seller_id]
    seller_email = payload[:email]
    role = payload[:role]
    
    Rails.logger.info "SellerAuthorizeApiRequest: Extracted seller_id: #{seller_id}, email: #{seller_email}, role: #{role}"

    # Check if the token is actually for a seller
    if role && role.downcase != 'seller'
      Rails.logger.error "SellerAuthorizeApiRequest: Token is for #{role}, not seller. Email: #{seller_email}"
      raise ExceptionHandler::InvalidToken, "Token is for #{role}, not seller"
    end

    # Try to find seller by ID first
    if seller_id
      Rails.logger.info "SellerAuthorizeApiRequest: Looking for seller with ID: #{seller_id}"
      seller = Seller.find_by(id: seller_id)
      if seller && !seller.deleted?
        Rails.logger.info "SellerAuthorizeApiRequest: Found seller: #{seller.id}"
        return seller
      elsif seller&.deleted?
        Rails.logger.error "SellerAuthorizeApiRequest: Seller #{seller_id} is deleted"
      else
        Rails.logger.error "SellerAuthorizeApiRequest: Seller #{seller_id} not found in database"
      end
    end

    # Try to find seller by email if ID didn't work
    if seller_email
      Rails.logger.info "SellerAuthorizeApiRequest: Looking for seller with email: #{seller_email}"
      seller = Seller.find_by(email: seller_email)
      if seller && !seller.deleted?
        Rails.logger.info "SellerAuthorizeApiRequest: Found seller by email: #{seller.id}"
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
      
      Rails.logger.info "SellerAuthorizeApiRequest: Attempting to decode token: #{token[0..20]}..."
      JsonWebToken.decode(token)
    rescue => e
      Rails.logger.error "JWT Decode Error: #{e.message}"
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
      Rails.logger.debug "SellerAuthorizeApiRequest: Missing Authorization header"
      raise ExceptionHandler::MissingToken, 'Missing token'
    end
  end
end
