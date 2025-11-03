class AdminAuthorizeApiRequest
  def initialize(headers = {})
    @headers = headers
  end

  def result
    @admin ||= find_admin
  end

  private

  def find_admin
    decoded_result = decoded_token
    
    unless decoded_result[:success]
      # Only log as error if token was provided but invalid (not just missing)
      if decoded_result[:missing_token]
        Rails.logger.debug "AdminAuthorizeApiRequest: No token provided"
      else
        Rails.logger.error "AdminAuthorizeApiRequest: Token validation failed: #{decoded_result[:error]}"
      end
      raise ExceptionHandler::InvalidToken, decoded_result[:error]
    end
    
    payload = decoded_result[:payload]
    admin_id = payload[:admin_id] || payload[:user_id] # Support both for backward compatibility
    admin_email = payload[:email]
    role = payload[:role]

    # Check if the token is actually for an admin
    if role && role.downcase != 'admin'
      Rails.logger.debug "AdminAuthorizeApiRequest: Token is for #{role}, not admin. Email: #{admin_email}"
      raise ExceptionHandler::InvalidToken, "Token is for #{role}, not admin"
    end

    # Try to find admin by ID first
    if admin_id
      admin = Admin.find_by(id: admin_id)
      return admin if admin
    end

    # Try to find admin by email if ID didn't work
    if admin_email
      admin = Admin.find_by(email: admin_email)
      return admin if admin
    end

    raise ExceptionHandler::InvalidToken, 'Invalid token'
  end

  def decoded_token
    @decoded_token ||= begin
      token = http_auth_header
      return { success: false, error: 'No token provided' } if token.blank?
      
      Rails.logger.debug "AdminAuthorizeApiRequest: Attempting to decode token: #{token[0..20]}..."
      JsonWebToken.decode(token)
    rescue ExceptionHandler::MissingToken => e
      # Missing token is normal for public endpoints, only log at debug level
      Rails.logger.debug "AdminAuthorizeApiRequest: #{e.message}"
      { success: false, error: 'No token provided', missing_token: true }
    rescue => e
      # Only log as error if token was provided but invalid
      Rails.logger.error "AdminAuthorizeApiRequest: JWT Decode Error: #{e.message}"
      { success: false, error: 'Token validation failed' }
    end
  end

  def http_auth_header
    if @headers['Authorization'].present?
      @headers['Authorization'].split(' ').last
    else
      # Don't log missing tokens - they're normal for public endpoints
      raise ExceptionHandler::MissingToken, 'Missing token'
    end
  end
end
