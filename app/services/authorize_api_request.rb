# app/services/authorize_api_request.rb
class AuthorizeApiRequest
  def initialize(headers = {})
    @headers = headers
  end

  def result
    @user ||= find_user
  end

  private

  def find_user
    decoded_result = decoded_token
    
    unless decoded_result[:success]
      Rails.logger.error "AuthorizeApiRequest: Token validation failed: #{decoded_result[:error]}"
      return nil
    end
    
    payload = decoded_result[:payload]
    user_id = payload[:user_id]
    user_email = payload[:email]
    role = payload[:role]

    # Try to find user by ID first
    if user_id
      user = find_user_by_id_and_role(user_id, role)
      return user if user && (!user.respond_to?(:deleted?) || !user.deleted?)
    end

    # Try to find user by email if ID didn't work
    if user_email
      user = find_user_by_email_and_role(user_email, role)
      return user if user && (!user.respond_to?(:deleted?) || !user.deleted?)
    end

    nil
  end

  def find_user_by_id_and_role(user_id, role)
    case role&.downcase
    when 'buyer'
      Buyer.find_by(id: user_id)
    when 'seller'
      Seller.find_by(id: user_id)
    when 'admin'
      Admin.find_by(id: user_id)
    when 'sales'
      SalesUser.find_by(id: user_id)
    when 'marketing'
      MarketingUser.find_by(id: user_id)
    else
      # Fallback: try all models
      Buyer.find_by(id: user_id) ||
      Seller.find_by(id: user_id) ||
      Admin.find_by(id: user_id) ||
      SalesUser.find_by(id: user_id) ||
      MarketingUser.find_by(id: user_id)
    end
  end

  def find_user_by_email_and_role(user_email, role)
    case role&.downcase
    when 'buyer'
      Buyer.find_by(email: user_email)
    when 'seller'
      Seller.find_by(email: user_email)
    when 'admin'
      Admin.find_by(email: user_email)
    when 'sales'
      SalesUser.find_by(email: user_email)
    when 'marketing'
      MarketingUser.find_by(email: user_email)
    else
      # Fallback: try all models
      Buyer.find_by(email: user_email) ||
      Seller.find_by(email: user_email) ||
      Admin.find_by(email: user_email) ||
      SalesUser.find_by(email: user_email) ||
      MarketingUser.find_by(email: user_email)
    end
  end

  def decoded_token
    @decoded_token ||= begin
      token = http_auth_header
      return { success: false, error: 'No token provided' } if token.blank?
      
      JsonWebToken.decode(token)
    rescue => e
      Rails.logger.error "JWT Decode Error: #{e.message}"
      { success: false, error: 'Token validation failed' }
    end
  end

  def http_auth_header
    if @headers['Authorization'].present?
      @headers['Authorization'].split(' ').last
    else
      nil
    end
  end
end
