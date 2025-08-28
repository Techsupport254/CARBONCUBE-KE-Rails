class AdminAuthorizeApiRequest
  def initialize(headers = {})
    @headers = headers
  end

  def result
    @admin ||= find_admin
  end

  private

  def find_admin
    token = decoded_token
    admin_id = token[:user_id] if token.present?

    if admin_id
      admin = Admin.find_by(id: admin_id)
      return admin if admin
    end

    admin_email = token[:email] if token.present?

    if admin_email
      admin = Admin.find_by(email: admin_email)
      return admin if admin
    end

    raise ExceptionHandler::InvalidToken, 'Invalid token'
  end

  def decoded_token
    @decoded_token ||= JsonWebToken.decode(http_auth_header)
  end

  def http_auth_header
    if @headers['Authorization'].present?
      @headers['Authorization'].split(' ').last
    else
      raise ExceptionHandler::MissingToken, 'Missing token'
    end
  end
end
