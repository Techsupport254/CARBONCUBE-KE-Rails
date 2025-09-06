class SellerAuthorizeApiRequest
  def initialize(headers = {})
    @headers = headers
  end

  def result
    @seller ||= find_seller
  end

  private

  def find_seller
    Rails.logger.info "SellerAuthorizeApiRequest: Starting authentication"
    Rails.logger.info "SellerAuthorizeApiRequest: Decoded token: #{decoded_token.inspect}"
    
    seller_id = decoded_token[:seller_id] if decoded_token.present?
    Rails.logger.info "SellerAuthorizeApiRequest: Seller ID from token: #{seller_id}"

    if seller_id
      seller = Seller.find_by(id: seller_id)
      Rails.logger.info "SellerAuthorizeApiRequest: Found seller by ID: #{seller&.id}"
      return seller if seller
    end

    seller_email = decoded_token[:email] if decoded_token.present?
    Rails.logger.info "SellerAuthorizeApiRequest: Seller email from token: #{seller_email}"

    if seller_email
      seller = Seller.find_by(email: seller_email)
      Rails.logger.info "SellerAuthorizeApiRequest: Found seller by email: #{seller&.id}"
      return seller if seller
    end

    Rails.logger.error "SellerAuthorizeApiRequest: No seller found, raising InvalidToken"
    raise ExceptionHandler::InvalidToken, 'Invalid token'
  end

  def decoded_token
    @decoded_token ||= JsonWebToken.decode(http_auth_header)
  end

  def http_auth_header
    authorization_header = @headers['Authorization']
    Rails.logger.info "SellerAuthorizeApiRequest: Authorization header: #{authorization_header}"
    
    if authorization_header.present?
      token = authorization_header.split(' ').last
      Rails.logger.info "SellerAuthorizeApiRequest: Extracted token: #{token[0..20]}..." if token
      return token
    else
      Rails.logger.error "SellerAuthorizeApiRequest: Missing Authorization header"
      raise ExceptionHandler::MissingToken, 'Missing token'
    end
  end
end
