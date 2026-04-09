# app/services/buyer_authorize_api_request.rb

class BuyerAuthorizeApiRequest
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
      # Only log if token was provided but invalid (not just missing)
      unless decoded_result[:missing_token]
        # Rails.logger.error "BuyerAuthorizeApiRequest: Token validation failed: #{decoded_result[:error]}"
      end
      raise ExceptionHandler::InvalidToken, decoded_result[:error]
    end
    
    payload = decoded_result[:payload]
    user_id = payload[:user_id]
    user_email = payload[:email]
    role = payload[:role]

    # Check if the token is for a buyer or seller
    unless role && ['buyer', 'seller'].include?(role.downcase)
      # Rails.logger.debug "BuyerAuthorizeApiRequest: Token is for #{role}, not buyer or seller. Email: #{user_email}"
      raise ExceptionHandler::InvalidToken, "Token is for #{role}, not buyer or seller"
    end

    model = role.downcase == 'seller' ? Seller : Buyer

    # Try to find user by ID
    if user_id
      user = model.find_by(id: user_id)
      if user && (!user.respond_to?(:deleted?) || !user.deleted?)
        return user
      end
    end

    # Try to find user by email
    if user_email
      user = model.find_by(email: user_email)
      if user && (!user.respond_to?(:deleted?) || !user.deleted?)
        return user
      end
    end

    # --- FALLBACK: Check the other model (Buyer/Seller swap) ---
    # This handles the transition period during upgrade/migration 
    # when the JWT role might not yet match the database state.
    other_model = (model == Seller) ? Buyer : Seller
    
    # Check other model by email (ID might have changed during migration, but email is unique)
    if user_email
      user = other_model.find_by(email: user_email)
      if user && (!user.respond_to?(:deleted?) || !user.deleted?)
        # Rails.logger.info "BuyerAuthorizeApiRequest: Found user in FALLBACK model (#{other_model.name}) by email: #{user_email}"
        return user
      end
    end

    # Rails.logger.error "BuyerAuthorizeApiRequest: Could not find user in primary (#{model.name}) or fallback (#{other_model.name}) tables."
    raise ExceptionHandler::InvalidToken, 'Invalid token'
  end

  def decoded_token
    @decoded_token ||= begin
      token = http_auth_header
      return { success: false, error: 'No token provided' } if token.blank?
      
      # Rails.logger.debug "BuyerAuthorizeApiRequest: Attempting to decode token: #{token[0..20]}..."
      JsonWebToken.decode(token)
    rescue ExceptionHandler::MissingToken => e
      # Missing token is normal for public endpoints, only log at debug level
      Rails.logger.debug "BuyerAuthorizeApiRequest: #{e.message}"
      { success: false, error: 'No token provided', missing_token: true }
    rescue => e
      # Only log as error if token was provided but invalid
      Rails.logger.error "BuyerAuthorizeApiRequest: JWT Decode Error: #{e.message}"
      { success: false, error: 'Token validation failed' }
    end
  end

  def http_auth_header
    if @headers['Authorization'].present?
      auth_header = @headers['Authorization']
      if auth_header.start_with?('Bearer ')
        return auth_header.split(' ').last
      else
        # Sometimes the token might be passed without 'Bearer ' prefix
        return auth_header
      end
    else
      # Don't log missing tokens - they're normal for public endpoints
      raise ExceptionHandler::MissingToken, 'Missing token'
    end
  end
end
