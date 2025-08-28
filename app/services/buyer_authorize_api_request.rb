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
    buyer_id = decoded_token[:user_id] if decoded_token.present?

    if buyer_id
      buyer = Buyer.find_by(id: buyer_id)
      return buyer if buyer
    end

    buyer_email = decoded_token[:email] if decoded_token.present?

    if buyer_email
      buyer = Buyer.find_by(email: buyer_email)
      return buyer if buyer
    end

    raise ExceptionHandler::InvalidToken, 'Invalid token'
  end

  def decoded_token
    @decoded_token ||= JsonWebToken.decode(http_auth_header)
  end

  def http_auth_header
    if @headers['Authorization'].present?
      return @headers['Authorization'].split(' ').last
    else
      raise ExceptionHandler::MissingToken, 'Missing token'
    end
  end
end
