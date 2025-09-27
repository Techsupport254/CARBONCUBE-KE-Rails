# app/services/token_validation_service.rb
class TokenValidationService
  def initialize(headers = {})
    @headers = headers
  end

  # Validate token and return structured result
  def validate_token
    token = extract_token
    return validation_error('No token provided') unless token

    decoded_result = JsonWebToken.decode(token)
    
    unless decoded_result[:success]
      error_message = decoded_result[:error]
      error_type = decoded_result[:expired] ? 'token_expired' : 'invalid_token'
      return validation_error(error_message, error_type, expired: decoded_result[:expired])
    end

    validation_success(decoded_result[:payload])
  end

  # Extract user from token with proper error handling
  def extract_user(user_class, id_field = :user_id, email_field = :email)
    validation_result = validate_token
    return nil unless validation_result[:success]

    payload = validation_result[:payload]
    
    # Try to find user by ID first
    user_id = payload[id_field]
    if user_id
      user = user_class.find_by(id: user_id)
      return user if user && (!user.respond_to?(:deleted?) || !user.deleted?)
    end

    # Try to find user by email if ID didn't work
    user_email = payload[email_field]
    if user_email
      user = user_class.find_by(email: user_email)
      return user if user && (!user.respond_to?(:deleted?) || !user.deleted?)
    end

    nil
  end

  # Check if token is expired without raising exceptions
  def token_expired?
    token = extract_token
    return true unless token

    decoded_result = JsonWebToken.decode(token)
    !decoded_result[:success] && decoded_result[:expired]
  end

  # Get token expiration time
  def token_expires_at
    token = extract_token
    return nil unless token

    decoded_result = JsonWebToken.decode(token)
    return nil unless decoded_result[:success]

    Time.at(decoded_result[:payload][:exp])
  end


  private

  def extract_token
    auth_header = @headers['Authorization']
    return nil unless auth_header.present?

    auth_header.split(' ').last
  end

  def validation_success(payload)
    {
      success: true,
      payload: payload,
      error: nil,
      error_type: nil,
      expired: false
    }
  end

  def validation_error(message, error_type = 'invalid_token', expired: false)
    {
      success: false,
      payload: nil,
      error: message,
      error_type: error_type,
      expired: expired
    }
  end
end
