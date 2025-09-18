# app/lib/sales_authorize_api_request.rb
class SalesAuthorizeApiRequest
  def initialize(headers = {})
    @headers = headers
  end

  def result
    token = http_auth_header
    return nil unless token

    decoded_result = JsonWebToken.decode(token)
    
    if decoded_result[:success]
      SalesUser.find_by(id: decoded_result[:payload][:user_id])
    else
      Rails.logger.warn("JWT validation failed: #{decoded_result[:error]}")
      nil
    end
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
