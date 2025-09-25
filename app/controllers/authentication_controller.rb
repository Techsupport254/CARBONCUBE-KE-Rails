class AuthenticationController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def login
    identifier = params[:email] || params[:identifier] || params[:authentication]&.[](:email)
    remember_me = params[:remember_me] == true || params[:remember_me] == 'true'
    @user = find_user_by_identifier(identifier)

    if @user&.authenticate(params[:password])
      role = determine_role(@user)

      # Block login if the user is soft-deleted
      if (@user.is_a?(Buyer) || @user.is_a?(Seller)) && @user.deleted?
        render json: { errors: ['Your account has been deleted. Please contact support.'] }, status: :unauthorized
        return
      end

      # 🚫 Pilot restriction for sellers outside Nairobi (only if pilot phase is enabled)
      if ENV['PILOT_PHASE_ENABLED'] == 'true' && role == 'seller' && @user.county&.county_code.to_i != 47
        render json: {
          errors: ['Access restricted during pilot phase. Only Nairobi-based sellers can log in.']
        }, status: :forbidden
        return
      end

      user_response = {
        id: @user.id,
        email: @user.email,
        role: role
      }
      
      # Add name fields based on user type
      if @user.respond_to?(:fullname) && @user.fullname.present?
        user_response[:name] = @user.fullname
      elsif @user.respond_to?(:username) && @user.username.present?
        user_response[:name] = @user.username
      end
      
      # Only include username for users that have this field (Buyer, Seller, Admin)
      if @user.respond_to?(:username) && @user.username.present?
        user_response[:username] = @user.username
      end
      
      # Only include profile picture for users that have this field (Buyer, Seller)
      if @user.respond_to?(:profile_picture) && @user.profile_picture.present?
        user_response[:profile_picture] = @user.profile_picture
      end
      

      # Update last active timestamp for sellers
      if role == 'seller' && @user.respond_to?(:update_last_active!)
        @user.update_last_active!
      end

      # Create token with appropriate ID field and remember_me flag
      token_payload = if role == 'seller'
        { seller_id: @user.id, email: @user.email, role: role, remember_me: remember_me }
      else
        { user_id: @user.id, email: @user.email, role: role, remember_me: remember_me }
      end
      
      token = JsonWebToken.encode(token_payload)
      render json: { token: token, user: user_response, remember_me: remember_me }, status: :ok
    else
      render json: { errors: ['Invalid login credentials'] }, status: :unauthorized
    end
  end

  def refresh_token
    token_validation = TokenValidationService.new(request.headers)
    
    # Check if token is expired
    unless token_validation.token_expired?
      render json: { 
        error: 'Token is not expired',
        error_type: 'token_not_expired'
      }, status: :bad_request
      return
    end

    # Extract user information from expired token
    validation_result = token_validation.validate_token
    unless validation_result[:success]
      render json: { 
        error: 'Invalid token',
        error_type: 'invalid_token'
      }, status: :unauthorized
      return
    end

    payload = validation_result[:payload]
    user_id = payload[:user_id] || payload[:seller_id]
    role = payload[:role]
    remember_me = payload[:remember_me]

    # Check if remember_me was enabled during login
    unless remember_me
      render json: { 
        error: 'Token refresh not allowed - remember me was not enabled',
        error_type: 'refresh_not_allowed'
      }, status: :forbidden
      return
    end

    # Find the user
    user = find_user_by_id_and_role(user_id, role)
    unless user
      render json: { 
        error: 'User not found',
        error_type: 'user_not_found'
      }, status: :not_found
      return
    end

    # Check if user is deleted
    if (user.is_a?(Buyer) || user.is_a?(Seller)) && user.deleted?
      render json: { 
        error: 'Account has been deleted',
        error_type: 'account_deleted'
      }, status: :unauthorized
      return
    end

    # Generate new token with remember_me flag
    token_payload = if role == 'seller'
      { seller_id: user.id, email: user.email, role: role, remember_me: remember_me }
    else
      { user_id: user.id, email: user.email, role: role, remember_me: remember_me }
    end
    
    new_token = JsonWebToken.encode(token_payload)

    render json: { 
      token: new_token,
      message: 'Token refreshed successfully'
    }, status: :ok
  end

  def logout
    token = request.headers['Authorization']&.split(' ')&.last
    
    if token
      # Extract user info before blacklisting
      begin
        payload = JsonWebToken.decode(token)
        user_id = payload[:user_id] || payload[:seller_id]
        role = payload[:role]
        
        # Update last_active_at for sellers before logout
        if role == 'seller' && user_id
          seller = Seller.find_by(id: user_id)
          seller&.update_last_active!
        end
        
        # Blacklist the token
        JwtService.blacklist_token(token)
        
        render json: { message: 'Logged out successfully' }, status: :ok
      rescue StandardError => e
        Rails.logger.error "Logout error: #{e.message}"
        render json: { error: 'Invalid token' }, status: :unauthorized
      end
    else
      render json: { error: 'No token provided' }, status: :bad_request
    end
  end

  def google_oauth
    auth_code = params[:code]
    redirect_uri = params[:redirect_uri] || ENV['GOOGLE_REDIRECT_URI'] || "#{request.base_url}/auth/google_oauth2/callback"
    
    unless auth_code
      render json: { errors: ['Authorization code is required'] }, status: :bad_request
      return
    end

    oauth_service = GoogleOauthService.new(auth_code, redirect_uri)
    result = oauth_service.authenticate

    if result[:success]
      user = result[:user]
      role = determine_role(user)
      
      # Block login if the user is soft-deleted
      if (user.is_a?(Buyer) || user.is_a?(Seller)) && user.deleted?
        render json: { errors: ['Your account has been deleted. Please contact support.'] }, status: :unauthorized
        return
      end

      # 🚫 Pilot restriction for sellers outside Nairobi (only if pilot phase is enabled)
      if ENV['PILOT_PHASE_ENABLED'] == 'true' && role == 'seller' && user.county&.county_code.to_i != 47
        render json: {
          errors: ['Access restricted during pilot phase. Only Nairobi-based sellers can log in.']
        }, status: :forbidden
        return
      end

      user_response = {
        id: user.id,
        email: user.email,
        role: role
      }
      
      # Add name fields based on user type
      if user.respond_to?(:fullname) && user.fullname.present?
        user_response[:name] = user.fullname
      elsif user.respond_to?(:username) && user.username.present?
        user_response[:name] = user.username
      end
      
      # Only include username for users that have this field (Buyer, Seller, Admin)
      if user.respond_to?(:username) && user.username.present?
        user_response[:username] = user.username
      end
      
      # Only include profile picture for users that have this field (Buyer, Seller)
      if user.respond_to?(:profile_picture) && user.profile_picture.present?
        user_response[:profile_picture] = user.profile_picture
      end

      # Create token with appropriate ID field
      token_payload = if role == 'seller'
        { seller_id: user.id, email: user.email, role: role, remember_me: true }
      else
        { user_id: user.id, email: user.email, role: role, remember_me: true }
      end
      
      token = JsonWebToken.encode(token_payload)
      render json: { token: token, user: user_response }, status: :ok
    else
      render json: { errors: ['Authentication failed'] }, status: :unauthorized
    end
  end

  def google_one_tap
    credential = params[:credential]
    
    Rails.logger.info "Google One Tap: Received credential: #{credential.present? ? 'Present' : 'Missing'}"
    
    unless credential
      render json: { success: false, error: 'Credential is required' }, status: :bad_request
      return
    end

    begin
      # Verify the Google ID token by calling Google's tokeninfo endpoint
      response = HTTParty.get("https://oauth2.googleapis.com/tokeninfo", {
        query: { id_token: credential }
      })
      
      unless response.success?
        Rails.logger.error "Google One Tap: Token verification failed - #{response.code}: #{response.body}"
        render json: { success: false, error: 'Invalid Google token' }, status: :unauthorized
        return
      end
      
      token_info = JSON.parse(response.body)
      Rails.logger.info "Google One Tap: Token verified for user: #{token_info['email']}"
      
      # Verify the token is for our client
      unless token_info['aud'] == ENV['GOOGLE_CLIENT_ID']
        Rails.logger.error "Google One Tap: Token audience mismatch. Expected: #{ENV['GOOGLE_CLIENT_ID']}, Got: #{token_info['aud']}"
        render json: { success: false, error: 'Token audience mismatch' }, status: :unauthorized
        return
      end
      
      # Extract user information
      user_info = {
        email: token_info['email'],
        name: token_info['name'],
        picture: token_info['picture'],
        verified_email: token_info['email_verified']
      }
      
      # Find or create user
      Rails.logger.info "Google One Tap: Looking for user with email: #{user_info[:email]}"
      user = find_or_create_user_from_google_info(user_info)
      
      if user
        Rails.logger.info "Google One Tap: User found/created: #{user.class.name} ID: #{user.id}"
        role = determine_role(user)
        
        # Block login if the user is soft-deleted
        if (user.is_a?(Buyer) || user.is_a?(Seller)) && user.deleted?
          render json: { success: false, error: 'Your account has been deleted. Please contact support.' }, status: :unauthorized
          return
        end

        # 🚫 Pilot restriction for sellers outside Nairobi (only if pilot phase is enabled)
        if ENV['PILOT_PHASE_ENABLED'] == 'true' && role == 'seller' && user.county&.county_code.to_i != 47
          render json: {
            success: false,
            error: 'Access restricted during pilot phase. Only Nairobi-based sellers can log in.'
          }, status: :forbidden
          return
        end

        user_response = {
          id: user.id,
          email: user.email,
          role: role
        }
        
        # Add name fields based on user type
        if user.respond_to?(:fullname) && user.fullname.present?
          user_response[:name] = user.fullname
        elsif user.respond_to?(:username) && user.username.present?
          user_response[:name] = user.username
        end
      
        # Only include username for users that have this field (Buyer, Seller, Admin)
        if user.respond_to?(:username) && user.username.present?
          user_response[:username] = user.username
        end
        
        # Only include profile picture for users that have this field (Buyer, Seller)
        if user.respond_to?(:profile_picture) && user.profile_picture.present?
          user_response[:profile_picture] = user.profile_picture
        end

        # Create token with appropriate ID field
        token_payload = if role == 'seller'
          { seller_id: user.id, email: user.email, role: role, remember_me: true }
        else
          { user_id: user.id, email: user.email, role: role, remember_me: true }
        end
        
        token = JsonWebToken.encode(token_payload)
        render json: { success: true, token: token, user: user_response }, status: :ok
      else
        render json: { success: false, error: 'Failed to create or find user' }, status: :unauthorized
      end
    rescue => e
      Rails.logger.error "Google One Tap error: #{e.message}"
      render json: { success: false, error: 'Authentication failed' }, status: :unauthorized
    end
  end

  def google_oauth_callback
    # This method handles the callback from Google OAuth
    # Process the authentication and redirect with token
    code = params[:code]
    state = params[:state]
    error = params[:error]
    
    frontend_url = ENV['REACT_APP_FRONTEND_URL'] || 'http://localhost:3000'
    
    if error
      # Handle OAuth error
      redirect_url = "#{frontend_url}/auth/google/callback?error=#{CGI.escape(error)}"
      redirect_to redirect_url, allow_other_host: true
      return
    end
    
    unless code
      # No code received
      redirect_url = "#{frontend_url}/auth/google/callback?error=no_code_received"
      redirect_to redirect_url, allow_other_host: true
      return
    end
    
    # Process the OAuth code
    begin
      redirect_uri = ENV['GOOGLE_REDIRECT_URI'] || "#{request.base_url}/auth/google_oauth2/callback"
      oauth_service = GoogleOauthService.new(code, redirect_uri)
      result = oauth_service.authenticate
      
      if result[:success]
        user = result[:user]
        role = determine_role(user)
        
        # Block login if the user is soft-deleted
        if (user.is_a?(Buyer) || user.is_a?(Seller)) && user.deleted?
          redirect_url = "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Your account has been deleted. Please contact support.')}"
          redirect_to redirect_url, allow_other_host: true
          return
        end

        # 🚫 Pilot restriction for sellers outside Nairobi (only if pilot phase is enabled)
        if ENV['PILOT_PHASE_ENABLED'] == 'true' && role == 'seller' && user.county&.county_code.to_i != 47
          redirect_url = "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Access restricted during pilot phase. Only Nairobi-based sellers can log in.')}"
          redirect_to redirect_url, allow_other_host: true
          return
        end

        # Build user response
        user_response = {
          id: user.id,
          email: user.email,
          role: role
        }
        
        # Add name fields based on user type
        if user.respond_to?(:fullname) && user.fullname.present?
          user_response[:name] = user.fullname
        elsif user.respond_to?(:username) && user.username.present?
          user_response[:name] = user.username
        end
        
        # Only include username for users that have this field (Buyer, Seller, Admin)
        if user.respond_to?(:username) && user.username.present?
          user_response[:username] = user.username
        end
        
        # Only include profile picture for users that have this field (Buyer, Seller)
        if user.respond_to?(:profile_picture) && user.profile_picture.present?
          user_response[:profile_picture] = user.profile_picture
        end

        # Create token with appropriate ID field
        token_payload = if role == 'seller'
          { seller_id: user.id, email: user.email, role: role, remember_me: true }
        else
          { user_id: user.id, email: user.email, role: role, remember_me: true }
        end
        
        token = JsonWebToken.encode(token_payload)
        
        # Redirect to frontend with token and user data
        redirect_url = "#{frontend_url}/auth/google/callback?token=#{token}&user=#{CGI.escape(JSON.generate(user_response))}&success=true"
        redirect_to redirect_url, allow_other_host: true
      else
        # Authentication failed
        redirect_url = "#{frontend_url}/auth/google/callback?error=#{CGI.escape(result[:error] || 'Authentication failed')}"
        redirect_to redirect_url, allow_other_host: true
      end
    rescue => e
      Rails.logger.error "Google OAuth callback error: #{e.message}"
      redirect_url = "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Authentication failed')}"
      redirect_to redirect_url, allow_other_host: true
    end
  end

  private

  def find_or_create_user_from_google_info(user_info)
    email = user_info[:email]
    return nil unless email

    # Try to find existing user
    user = Buyer.find_by(email: email) || Seller.find_by(email: email) || SalesUser.find_by(email: email) || Admin.find_by(email: email)
    
    if user
      # Update user info if needed
      if user.respond_to?(:fullname) && user_info[:name].present? && user.fullname.blank?
        user.update(fullname: user_info[:name])
      end
      if user.respond_to?(:profile_picture) && user_info[:picture].present? && user.profile_picture.blank?
        user.update(profile_picture: user_info[:picture])
      end
      return user
    end

    # Create new buyer by default
    Buyer.create!(
      email: email,
      fullname: user_info[:name] || email.split('@').first,
      profile_picture: user_info[:picture],
      password: SecureRandom.hex(20), # Random password since they'll use Google
      password_confirmation: SecureRandom.hex(20)
    )
  rescue => e
    Rails.logger.error "Error creating user: #{e.message}"
    nil
  end

  def find_user_by_identifier(identifier)
    if identifier.include?('@')
      # Assume it's an email if it contains '@'
      Buyer.find_by(email: identifier) ||
      Seller.find_by(email: identifier) ||
      Admin.find_by(email: identifier) ||
      SalesUser.find_by(email: identifier)
    elsif identifier.match?(/\A\d{10}\z/)
      # Assume phone number if it's 10 digits - no longer supported
      nil
    else
      # Otherwise, assume it's an ID number - no longer supported
      nil
    end
  end

  def find_user_by_id_and_role(user_id, role)
    case role
    when 'buyer'
      Buyer.find_by(id: user_id)
    when 'seller'
      Seller.find_by(id: user_id)
    when 'admin'
      Admin.find_by(id: user_id)
    when 'sales'
      SalesUser.find_by(id: user_id)
    else
      nil
    end
  end

  def determine_role(user)
    case user
    when Buyer then 'buyer'
    when Seller then 'seller'
    when Admin then 'admin'
    when SalesUser then 'sales'
    else 'unknown'
    end
  end
end
