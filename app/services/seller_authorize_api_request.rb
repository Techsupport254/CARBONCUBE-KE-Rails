class SellerAuthorizeApiRequest
  def initialize(headers = {})
    @headers = headers
  end

  def result
    @seller ||= find_seller
  end

  private

  def find_seller
    seller_id = decoded_token[:user_id] if decoded_token.present?

    if seller_id
      seller = Seller.find_by(id: seller_id)
      return seller if seller
    end

    seller_email = decoded_token[:email] if decoded_token.present?

    if seller_email
      seller = Seller.find_by(email: seller_email)
      return seller if seller
    end

    raise ExceptionHandler::InvalidToken, 'Invalid token'
  end

  def decoded_token
    @decoded_token ||= JsonWebToken.decode(http_auth_header)
  end

  def http_auth_header
    authorization_header = @headers['Authorization']
    if authorization_header.present?
      return authorization_header.split(' ').last
    else
      raise ExceptionHandler::MissingToken, 'Missing token'
    end
  end
end
