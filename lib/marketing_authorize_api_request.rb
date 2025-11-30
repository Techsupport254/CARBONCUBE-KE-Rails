# app/lib/marketing_authorize_api_request.rb
class MarketingAuthorizeApiRequest
  def initialize(headers = {})
    @headers = headers
  end

  def result
    token = http_auth_header
    return nil unless token

    decoded_result = JsonWebToken.decode(token)
    
    if decoded_result[:success]
      payload = decoded_result[:payload]
      role = payload[:role]&.downcase
      
      # Check if the token is actually for a marketing user
      if role && role != 'marketing'
        Rails.logger.debug "MarketingAuthorizeApiRequest: Token is for #{role}, not marketing"
        return nil
      end
      
      marketing_id = payload[:marketing_id] || payload[:user_id] # Support both for backward compatibility
      MarketingUser.find_by(id: marketing_id)
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

