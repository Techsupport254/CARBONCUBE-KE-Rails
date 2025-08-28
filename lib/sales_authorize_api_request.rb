# app/lib/sales_authorize_api_request.rb
class SalesAuthorizeApiRequest
  def initialize(headers = {})
    @headers = headers
  end

  def result
    token = http_auth_header
    return nil unless token

    decoded_auth_token = JsonWebToken.decode(token)
    SalesUser.find_by(id: decoded_auth_token[:user_id])
  rescue JWT::ExpiredSignature
    Rails.logger.warn('JWT has expired')
    nil
  rescue JWT::DecodeError => e
    Rails.logger.warn("JWT Decode Error: #{e.message}")
    nil
  rescue => e
    Rails.logger.error("Unexpected Auth Error: #{e.message}")
    nil
  end

  private

  def http_auth_header
    auth_header = @headers['Authorization']
    if auth_header.present?
      auth_header.split(' ').last
    else
      Rails.logger.warn('Missing Authorization header')
      nil
    end
  end
end
