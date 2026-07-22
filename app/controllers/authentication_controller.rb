class AuthenticationController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false
  require 'timeout'
  require 'digest'

  def sales_users
    # Public endpoint for dev/internal use to get available sales agents
    users = SalesUser.select(:id, :fullname, :email).map do |u|
      { id: u.id, name: u.fullname, email: u.email }
    end
    render json: { success: true, users: users }, status: :ok
  end

  def send_reactivation_email
    email = params[:email]
    consent_given = params[:consent_given]

    unless email.present?
      render json: { error: 'Email is required' }, status: :bad_request
      return
    end

    # GDPR: Require explicit consent
    unless consent_given == true
      render json: { error: 'Consent is required for data processing' }, status: :bad_request
      return
    end

    # Find user by email (check both Buyer and Seller)
    user = Buyer.find_by(email: email) || Seller.find_by(email: email)

    unless user
      render json: { error: 'No account found with this email' }, status: :not_found
      return
    end

    # Check if user is deleted
    unless user.deleted?
      render json: { error: 'This account is not deleted' }, status: :bad_request
      return
    end

    # Generate secure reactivation token
    reactivation_token = SecureRandom.urlsafe_base64(32)
    reactivation_token_digest = Digest::SHA256.hexdigest(reactivation_token)

    # Store token in database (add to user model or create separate table)
    # For now, we'll use Rails.cache with expiration
    cache_key = "reactivation_#{user.id}_#{user.class.name}"
    Rails.cache.write(cache_key, reactivation_token_digest, expires_in: 24.hours)

    # Build reactivation URL
    frontend_url = ENV['FRONTEND_URL'] || ENV['REACT_APP_FRONTEND_URL'] || (Rails.env.development? ? 'http://localhost:3000' : 'https://carboncube-ke.com')
    reactivation_url = "#{frontend_url}/reactivate-account?token=#{reactivation_token}&user_id=#{user.id}&user_type=#{user.class.name}"

    # Log consent for GDPR compliance
    Rails.logger.info "[GDPR] Account reactivation consent logged - Email: #{email}, User ID: #{user.id}, User Type: #{user.class.name}, IP: #{request.remote_ip}, Timestamp: #{Time.current}"

    # Send actual reactivation email
    UserMailer.reactivation_email(user, reactivation_url).deliver_later

    render json: { success: true, message: 'Reactivation email sent' }, status: :ok
  end

  def reactivate_account
    token = params[:token]
    user_id = params[:user_id]
    user_type = params[:user_type]

    unless token.present? && user_id.present? && user_type.present?
      render json: { error: 'Invalid reactivation link' }, status: :bad_request
      return
    end

    # Find user
    user_class = user_type.constantize
    user = user_class.find_by(id: user_id)

    unless user
      render json: { error: 'User not found' }, status: :not_found
      return
    end

    # Verify token
    cache_key = "reactivation_#{user_id}_#{user_type}"
    stored_token_digest = Rails.cache.read(cache_key)

    unless stored_token_digest
      render json: { error: 'Reactivation link has expired or is invalid' }, status: :bad_request
      return
    end

    token_digest = Digest::SHA256.hexdigest(token)
    unless ActiveSupport::SecurityUtils.secure_compare(token_digest, stored_token_digest)
      render json: { error: 'Invalid reactivation token' }, status: :bad_request
      return
    end

    # Reactivate account
    user.update(deleted: false)

    # Clear the token
    Rails.cache.delete(cache_key)

    render json: { success: true, message: 'Account reactivated successfully' }, status: :ok
  end


  def login
    email = params[:email]
    unless email.present?
      render json: { errors: ['Email is required'] }, status: :bad_request
      return
    end
    # Always enable remember_me for maximum session duration
    remember_me = true
    @user = find_user_by_email(email)

    if @user&.authenticate(params[:password])
      role = determine_role(@user)

      # Block login if the user is soft-deleted
      if (@user.is_a?(Buyer) || @user.is_a?(Seller)) && @user.deleted?
        render json: { errors: ['Your account has been deleted. Please check your email for a reactivation link or request a new one.'], account_deleted: true }, status: :unauthorized
        return
      end

      # Block login if the user is blocked (both Buyer and Seller)
      if @user.is_a?(Buyer) && @user.blocked?
        render json: { errors: ['Your account has been blocked. Please contact support.'] }, status: :unauthorized
        return
      end

      if @user.is_a?(Seller) && @user.blocked?
        render json: { errors: ['Your account has been blocked. Please contact support.'] }, status: :unauthorized
        return
      end

      # 🚫 Pilot restriction for sellers outside Nairobi (only if pilot phase is enabled)
      if ENV['PILOT_PHASE_ENABLED'] == 'true' && role == 'Seller' && @user.county&.county_code.to_i != 47
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
      
      # Include enterprise_name for sellers
      if @user.respond_to?(:enterprise_name) && @user.enterprise_name.present?
        user_response[:enterprise_name] = @user.enterprise_name
      end

      # Include phone_number for buyers and sellers
      if @user.respond_to?(:phone_number) && @user.phone_number.present?
        user_response[:phone_number] = @user.phone_number
      end

      # Include secondary_phone_number for buyers and sellers
      if @user.respond_to?(:secondary_phone_number) && @user.secondary_phone_number.present?
        user_response[:secondary_phone_number] = @user.secondary_phone_number
      end

      # Update last active timestamp for sellers and buyers
      if @user.respond_to?(:update_last_active!)
        @user.update_last_active!
      end
      
      # Associate guest clicks with user (buyer or seller) if device_hash is provided
      if (@user.is_a?(Buyer) || @user.is_a?(Seller)) && params[:device_hash].present?
        begin
          GuestClickAssociationService.associate_clicks_with_user(@user, params[:device_hash])
        rescue => e
          Rails.logger.error "Failed to associate guest clicks on login: #{e.message}" if defined?(Rails.logger)
          # Don't fail login if association fails
        end
      end

      # Create token with appropriate ID field and remember_me flag
      token_payload = if role == 'Seller'
        { seller_id: @user.id, email: @user.email, role: role, remember_me: remember_me }
      else
        { user_id: @user.id, email: @user.email, role: role, remember_me: remember_me }
      end

      token = JsonWebToken.encode(token_payload)

      # Set secure HTTP-only cookies for token and user data
      cookie_options = {
        httponly: true,
        secure: Rails.env.production?, # Secure in production
        samesite: :lax,
        expires: 60.days.from_now,
        domain: Rails.env.development? ? nil : '.carboncube-ke.com' # No domain restriction in development
      }

      # Set auth token cookie
      cookies[token_cookie_key] = { value: token, **cookie_options }

      # Set user data cookie (non-httpOnly for client-side access)
      user_cookie_options = cookie_options.merge(httponly: false)
      cookies[user_cookie_key] = { value: user_response.to_json, **user_cookie_options }

      render json: { success: true, token: token, user: user_response, remember_me: remember_me }, status: :ok
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
    # Sessions are now persistent by default
    # unless remember_me
    #   render json: { 
    #     error: 'Token refresh not allowed - remember me was not enabled',
    #     error_type: 'refresh_not_allowed'
    #   }, status: :forbidden
    #   return
    # end

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
        error: 'Your account has been deleted. Please check your email for a reactivation link or request a new one.',
        error_type: 'account_deleted'
      }, status: :unauthorized
      return
    end

    # Check if user is blocked (both Buyer and Seller)
    if user.is_a?(Buyer) && user.blocked?
      render json: { 
        error: 'Account has been blocked',
        error_type: 'account_blocked'
      }, status: :unauthorized
      return
    end

    if user.is_a?(Seller) && user.blocked?
      render json: { 
        error: 'Account has been blocked',
        error_type: 'account_blocked'
      }, status: :unauthorized
      return
    end

    # Generate new token with remember_me flag and appropriate expiration
    token_payload = if role == 'Seller'
      { seller_id: user.id, email: user.email, role: role, remember_me: remember_me }
    else
      { user_id: user.id, email: user.email, role: role, remember_me: remember_me }
    end
    
    # Use JsonWebToken.encode which now respects remember_me flag
    new_token = JsonWebToken.encode(token_payload)

    render json: { 
      token: new_token,
      message: 'Token refreshed successfully',
      remember_me: remember_me
    }, status: :ok
  end

  def logout
    # Clear cookies on logout
    cookies.delete(token_cookie_key, domain: '.carboncube-ke.com')
    cookies.delete(user_cookie_key, domain: '.carboncube-ke.com')
    cookies.delete(token_cookie_key)
    cookies.delete(user_cookie_key)

    token = request.headers['Authorization']&.split(' ')&.last || cookies[token_cookie_key]
    
    if token
      # Extract user info before blacklisting
      begin
        decoded = JsonWebToken.decode(token)
        if decoded[:success]
          payload = decoded[:payload]
          user_id = payload[:user_id] || payload[:seller_id]
          role = payload[:role]
          
          # Update last_active_at for sellers before logout
          if role == 'Seller' && user_id
            seller = Seller.find_by(id: user_id)
            seller&.update_column(:last_active_at, Time.current)
          end
          
          # Blacklist the token using its jti if present, otherwise use a hash of the token
          jti = payload[:jti] || Digest::MD5.hexdigest(token)
          exp = payload[:exp]
          ttl = exp.to_i - Time.current.to_i
          if ttl > 0
            RedisConnection.setex("blacklisted_token:#{jti}", ttl, 'true')
          end
        end
        
        render json: { message: 'Logged out successfully' }, status: :ok
      rescue StandardError => e
        Rails.logger.error "Logout error: #{e.message}"
        # Even if token is invalid, allow graceful logout
        render json: { message: 'Logged out successfully' }, status: :ok
      end
    else
      # Allow graceful logout even without token (e.g., token already expired/cleared)
      render json: { message: 'Logged out successfully' }, status: :ok
    end
  end

  def me
    # This method validates the current user session and returns user info
    token_validation = TokenValidationService.new(request.headers)
    validation_result = token_validation.validate_token
    
    unless validation_result[:success]
      render json: { 
        error: 'Invalid or expired token',
        error_type: 'invalid_token'
      }, status: :unauthorized
      return
    end

    payload = validation_result[:payload]
    user_id = payload[:user_id] || payload[:seller_id]
    role = payload[:role]

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
        error: 'Your account has been deleted. Please check your email for a reactivation link or request a new one.',
        error_type: 'account_deleted'
      }, status: :unauthorized
      return
    end

    # Check if user is blocked (both Buyer and Seller)
    if user.is_a?(Buyer) && user.blocked?
      render json: { 
        error: 'Account has been blocked',
        error_type: 'account_blocked'
      }, status: :unauthorized
      return
    end

    if user.is_a?(Seller) && user.blocked?
      render json: { 
        error: 'Account has been blocked',
        error_type: 'account_blocked'
      }, status: :unauthorized
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

    # Include phone number for users that have this field (Buyer, Seller)
    if user.respond_to?(:phone_number) && user.phone_number.present?
      user_response[:phone_number] = user.phone_number
    end

    # Include secondary_phone_number for users that have this field (Buyer, Seller)
    if user.respond_to?(:secondary_phone_number) && user.secondary_phone_number.present?
      user_response[:secondary_phone_number] = user.secondary_phone_number
    end

    render json: { user: user_response }, status: :ok
  end

  def google_oauth
    # If we have a code, process it (frontend sending authorization code from GSI popup)
    if params[:code].present?
      process_google_oauth_code
      return
    end

    # Otherwise, generate OAuth URL (legacy flow or fallback)

    # Check if Google OAuth is configured
    client_id = ENV['GOOGLE_OAUTH_CLIENT_ID']&.strip
    client_secret = ENV['GOOGLE_OAUTH_CLIENT_SECRET']&.strip
    redirect_uri = ENV['GOOGLE_REDIRECT_URI']&.strip
    
    # Redirect URI is REQUIRED - don't use fallback
    unless redirect_uri.present?
      Rails.logger.error "❌ GOOGLE_REDIRECT_URI environment variable is not set!"
      Rails.logger.error "   Current ENV['GOOGLE_REDIRECT_URI']: #{ENV['GOOGLE_REDIRECT_URI'].inspect}"
      render json: { 
        success: false, 
        error: 'Google OAuth redirect URI is not configured. Please set GOOGLE_REDIRECT_URI environment variable.',
        debug: {
          env_vars: {
            GOOGLE_OAUTH_CLIENT_ID: ENV['GOOGLE_OAUTH_CLIENT_ID'],
            GOOGLE_OAUTH_CLIENT_SECRET: ENV['GOOGLE_OAUTH_CLIENT_SECRET'] ? '***set***' : nil,
            GOOGLE_REDIRECT_URI: ENV['GOOGLE_REDIRECT_URI'],
            RAILS_ENV: ENV['RAILS_ENV'],
            request_base_url: request.base_url
          }
        }
      }, status: :service_unavailable
      return
    end
    
    # Ensure redirect_uri has no trailing slash (Google is strict about exact match)
    redirect_uri = redirect_uri.chomp('/') if redirect_uri.end_with?('/')
    
    unless client_id.present? && client_secret.present?
      render json: { 
        success: false, 
        error: 'Google OAuth is not configured. Please set GOOGLE_OAUTH_CLIENT_ID and GOOGLE_OAUTH_CLIENT_SECRET environment variables.' 
      }, status: :service_unavailable
      return
    end
    
    # Get role from params (default to buyer)
    role = params[:role] || 'buyer'
    
    # Generate signed state parameter for CSRF protection (stateless - includes role)
    # State is signed with timestamp to prevent replay attacks
    state_data = {
      nonce: SecureRandom.hex(16),
      role: role,
      timestamp: Time.current.to_i
    }
    
    # Sign the state data using Rails message verifier (stateless approach)
    verifier = ActiveSupport::MessageVerifier.new(Rails.application.secret_key_base)
    state = verifier.generate(state_data)
    
    # Build Google OAuth authorization URL using standard OAuth 2.0 format
    # Minimal scopes for login - only request what's needed
    # openid email profile provides: name, email, picture, and verified_email
    scope = 'openid email profile'
    
    # Build query parameters hash (Google OAuth 2.0 standard format)
    query_params = {
      'client_id' => client_id,
      'redirect_uri' => redirect_uri,
      'response_type' => 'code',
      'scope' => scope,
      'access_type' => 'offline',
      'prompt' => 'select_account',
      'state' => state
    }
    
    # Use URI.encode_www_form for proper OAuth 2.0 encoding (Google standard)
    query_string = URI.encode_www_form(query_params)
    
    # Build the authorization URL using URI::HTTPS (standard approach)
    auth_url = URI::HTTPS.build(
      host: 'accounts.google.com',
      path: '/o/oauth2/v2/auth',
      query: query_string
    ).to_s
    
    # Log the exact redirect URI being sent

    render json: { 
      success: true, 
      auth_url: auth_url 
    }, status: :ok
  end

  # GET endpoint for initiating OAuth flow with redirect (generates signed state)
  # Optional: callback_scheme (e.g. "carbon") for mobile app deep link redirect
  def google_oauth_initiate
    # Get role from params (default to buyer)
    role = params[:role] || 'buyer'
    callback_scheme = params[:callback_scheme]&.strip.presence
    carbon_code = params[:carbon_code]&.to_s&.strip.presence

    # Check if Google OAuth is configured
    client_id = ENV['GOOGLE_OAUTH_CLIENT_ID']&.strip
    client_secret = ENV['GOOGLE_OAUTH_CLIENT_SECRET']&.strip
    redirect_uri = ENV['GOOGLE_REDIRECT_URI']&.strip

    unless redirect_uri.present? && client_id.present? && client_secret.present?
      frontend_url = ENV['FRONTEND_URL'] || ENV['REACT_APP_FRONTEND_URL'] || (Rails.env.development? ? 'http://localhost:3000' : 'https://carboncube-ke.com')
      redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Google OAuth is not configured')}", allow_other_host: true, status: 302
      return
    end

    # Ensure redirect_uri has no trailing slash
    redirect_uri = redirect_uri.chomp('/') if redirect_uri.end_with?('/')

    # Generate signed state parameter for CSRF protection
    nonce = SecureRandom.hex(16)
    timestamp = Time.current.to_i
    state_data = {
      nonce: nonce,
      role: role,
      timestamp: timestamp
    }
    state_data[:callback_scheme] = callback_scheme if callback_scheme.present?
    state_data[:carbon_code] = carbon_code if carbon_code.present? && role.to_s.downcase == 'seller'
    
    # Sign the state data using Rails message verifier
    verifier = ActiveSupport::MessageVerifier.new(Rails.application.secret_key_base)
    state = verifier.generate(state_data)
    
    # Build Google OAuth authorization URL
    scope = 'openid email profile https://www.googleapis.com/auth/user.phonenumbers.read'
    
    query_params = {
      'client_id' => client_id,
      'redirect_uri' => redirect_uri,
      'response_type' => 'code',
      'scope' => scope,
      'access_type' => 'offline',
      'prompt' => 'select_account',
      'state' => state
    }
    
    query_string = URI.encode_www_form(query_params)
    auth_url = URI::HTTPS.build(
      host: 'accounts.google.com',
      path: '/o/oauth2/v2/auth',
      query: query_string
    ).to_s
    
    redirect_to auth_url, allow_other_host: true
  end

  # Process authorization code from frontend (GSI popup flow)
  def process_google_oauth_code
    code = params[:code]
    redirect_uri = params[:redirect_uri] || 'postmessage' # GSI uses 'postmessage'
    role = params[:role] || 'buyer'
    location_data = params[:location_data]
    is_registration = params[:is_registration] == true || params[:is_registration] == 'true'
    user_ip = request.remote_ip

    begin
      # Initialize GoogleOauthService
      oauth_service = GoogleOauthService.new(
        code,
        redirect_uri,
        user_ip,
        role.capitalize,
        location_data,
        is_registration
      )

      # Authenticate user
      result = oauth_service.authenticate

      # Ensure result is always a hash (safety check)
      unless result.is_a?(Hash)
        Rails.logger.error "❌ [GoogleOAuth] Result is not a hash: #{result.class}"
        Rails.logger.error "   Result: #{result.inspect}"
        result = {
          success: false,
          error: "Authentication service returned an unexpected response format."
        }
      end

      if result[:success]

        # Set secure HTTP-only cookies for token and user data (same as regular login)
        cookie_options = {
          httponly: true,
          secure: Rails.env.production?, # Secure in production
          samesite: :lax,
          expires: 60.days.from_now,
          domain: Rails.env.development? ? nil : '.carboncube-ke.com' # No domain restriction in development
        }

        # Set auth token cookie
        cookies[token_cookie_key] = { value: result[:token], **cookie_options }

        # Set user data cookie (non-httpOnly for client-side access)
        user_cookie_options = cookie_options.merge(httponly: false)
        cookies[user_cookie_key] = { value: result[:user].to_json, **user_cookie_options }

        render json: result, status: :ok
      else
        # Ensure error field is present for better frontend error handling
        result[:error] ||= "Authentication failed. Please try again." unless result[:error]
        render json: result, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "❌ [GoogleOAuth] Exception: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")

      error_response = {
        success: false,
        error: "Authentication failed: #{e.message}",
        error_type: e.class.to_s
      }

      Rails.logger.error "📤 [GoogleOAuth] Sending error response to frontend"
      render json: error_response, status: :internal_server_error
    end
  end

  def google_oauth_callback
    # Prioritize FRONTEND_URL, then REACT_APP_FRONTEND_URL, then default to localhost for development
    frontend_url = ENV['FRONTEND_URL'] || ENV['REACT_APP_FRONTEND_URL'] || (Rails.env.development? ? 'http://localhost:3000' : 'https://carboncube-ke.com')

    # OAuth callbacks from Google are always GET requests with query parameters
    if request.method == 'POST'
      render json: {
        error: 'Invalid request method. Use GET /auth/google/retrieve endpoint instead.',
        correct_endpoint: '/auth/google/retrieve'
      }, status: :bad_request
      return
    end

    # Check for errors from Google first
    if params[:error].present?
      error_msg = params[:error] == 'access_denied' ? 'Access denied by user' : params[:error]
      redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape(error_msg)}", allow_other_host: true, status: 302
      return
    end

    # Validate OAuth state for CSRF protection
    if params[:state].present?
      # In a production environment, you would validate the state against a stored value
      # For now, we'll just log it and pass it through to the frontend
    end
    
    # If no code and no error, this might be a direct access or invalid request
    if params[:code].blank?
      redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('No authorization code received')}", allow_other_host: true, status: 302
      return
    end
    
    # Check if this is a duplicate request (same code being processed twice)
    code = params[:code]
    cache_key = "oauth_code_#{Digest::MD5.hexdigest(code)}"
    if Rails.cache.exist?(cache_key)
      redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('This authorization code has already been used')}", allow_other_host: true, status: 302
      return
    end
    # Mark code as processed (expires in 5 minutes)
    Rails.cache.write(cache_key, true, expires_in: 5.minutes)
    
    # Verify and decode signed state parameter for CSRF protection (stateless)
    # State is required for GET requests (OAuth redirect flow)
    if params[:state].blank?
      redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Invalid state parameter - OAuth flow may have been interrupted')}", allow_other_host: true, status: 302
      return
    end
    
    begin
      verifier = ActiveSupport::MessageVerifier.new(Rails.application.secret_key_base)
      state_data = verifier.verify(params[:state])
      
      # Convert to symbol keys if needed (MessageVerifier may return string keys)
      state_data = state_data.with_indifferent_access if state_data.is_a?(Hash) && !state_data.is_a?(ActiveSupport::HashWithIndifferentAccess)
      
      # Validate state data structure - check both symbol and string keys
      timestamp = state_data[:timestamp] || state_data['timestamp']
      unless state_data.is_a?(Hash) && timestamp.present?
        redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Invalid state parameter')}", allow_other_host: true, status: 302
        return
      end
      
      # Check if state is expired (5 minutes max age)
      timestamp = timestamp.to_i
      current_time = Time.current.to_i
      
      if timestamp <= 0 || (current_time - timestamp) > 300
        redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('State parameter expired')}", allow_other_host: true, status: 302
        return
      end
      
      role = (state_data[:role] || state_data['role'] || 'buyer').to_s
      callback_scheme = (state_data[:callback_scheme] || state_data['callback_scheme']).to_s.strip.presence
      carbon_code_from_state = (state_data[:carbon_code] || state_data['carbon_code']).to_s.strip.presence
    rescue ActiveSupport::MessageVerifier::InvalidSignature => e
      redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Invalid state parameter')}", allow_other_host: true, status: 302
      return
    rescue => e
      redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Invalid state parameter')}", allow_other_host: true, status: 302
      return
    end

    # Base URL for OAuth redirect (web frontend or app deep link for mobile)
    oauth_redirect_base = callback_scheme.present? ? "#{callback_scheme}://auth/google/callback" : "#{frontend_url}/auth/google/callback"

    # Exchange authorization code for tokens
    code = params[:code]
    unless code.present?
      redirect_to "#{oauth_redirect_base}?error=#{CGI.escape('Authorization code missing')}", allow_other_host: true, status: 302
      return
    end
    
    begin
      # Exchange code for access token
      token_response = exchange_code_for_tokens(code)

      unless token_response && token_response['access_token']
        redirect_to "#{oauth_redirect_base}?error=#{CGI.escape('Failed to authenticate with Google')}", allow_other_host: true, status: 302
        return
      end
      
      access_token = token_response['access_token']
      refresh_token = token_response['refresh_token']
      expires_at = token_response['expires_in'] ? Time.current + token_response['expires_in'].seconds : nil
      
      # Get user info from Google
      user_info = get_google_user_info(access_token)

      unless user_info && user_info['email']
        redirect_to "#{oauth_redirect_base}?error=#{CGI.escape('Failed to retrieve user information')}", allow_other_host: true, status: 302
        return
      end
      
      # Try to fetch phone numbers from Google People API
      phone_number = nil
      phone_numbers_array = []
      begin
        people_api_response = HTTParty.get('https://people.googleapis.com/v1/people/me', {
          headers: { 'Authorization' => "Bearer #{access_token}" },
          query: { personFields: 'phoneNumbers' }
        })
        
        if people_api_response.success?
          people_data = JSON.parse(people_api_response.body)
          if people_data['phoneNumbers']&.any?
            # Try to find mobile phone first, then any phone
            mobile_phone = people_data['phoneNumbers'].find { |p| 
              p['type']&.downcase == 'mobile' || p['type']&.downcase == 'cell'
            }
            phone_info = mobile_phone || people_data['phoneNumbers'].first
            phone_number = phone_info['value'] if phone_info && phone_info['value'].present?
            phone_numbers_array = people_data['phoneNumbers'].map { |p| { 'value' => p['value'], 'type' => p['type'] } }
          end
        end
      rescue => e
        # Continue without phone numbers - they're optional
      end
      
      # Build auth hash for OauthAccountLinkingService
      auth_hash = {
        provider: 'google_oauth2',
        uid: user_info['id'] || user_info['sub'],
        info: {
          email: user_info['email'],
          name: user_info['name'] || user_info['email'].split('@').first,
          image: user_info['picture'],
          first_name: user_info['given_name'],
          last_name: user_info['family_name'],
          phone_number: phone_number,
          phone: phone_number
        },
        extra: {
          raw_info: {
            phone_number: phone_number,
            phone_numbers: phone_numbers_array
          }
        },
        credentials: {
          token: access_token,
          refresh_token: refresh_token,
          expires_at: expires_at&.to_i
        }
      }
      auth_hash[:carbon_code] = carbon_code_from_state if carbon_code_from_state.present?

      # Use OauthAccountLinkingService to create or link account
      user_ip = request.remote_ip
      linking_service = OauthAccountLinkingService.new(auth_hash, role.capitalize, user_ip)
      result = linking_service.call
      
      # Handle pending registration (new sellers must complete onboarding first)
      if result[:pending_registration]
        pending_token = result[:pending_token]

        # Build user response for cookies
        user_response = {
          id: result[:user_id],
          email: result[:email],
          role: result[:role] || 'seller',
          name: result[:name],
          pending_token: pending_token,
          phone_number: result[:phone_number],
          given_name: result[:given_name],
          family_name: result[:family_name],
          picture: result[:picture]
        }

        # For development: use URL token transmission (cookies don't work across ports)
        # For production: use secure server-side cookies with subdomain sharing
        if Rails.env.development?
          # Build redirect URL with all available seller data
          redirect_params = {
            pending_registration: 'true',
            pending_token: pending_token,
            email: result[:email] || '',
            name: result[:name] || '',
            picture: result[:picture] || ''
          }

          # Add phone number if available
          if result[:phone_number].present?
            redirect_params[:phone_number] = result[:phone_number]
          end

          # Add given name and family name if available
          if result[:given_name].present?
            redirect_params[:given_name] = result[:given_name]
          end
          if result[:family_name].present?
            redirect_params[:family_name] = result[:family_name]
          end

          # Add role for proper routing
          if result[:role].present?
            redirect_params[:role] = result[:role]
          end

          redirect_url = "#{oauth_redirect_base}?#{redirect_params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')}"
        else
          # Production: use secure server-side cookies with subdomain sharing
          cookie_options = {
            httponly: true,
            secure: true,
            samesite: :none,  # Required for cross-subdomain requests
            domain: '.carboncube-ke.com',  # Share across carboncube-ke.com and anko.carboncube-ke.com
            expires: 60.days.from_now
          }

          # Set auth token cookie (use pending token for now)
          cookies[token_cookie_key] = { value: pending_token, **cookie_options }

          # Set user data cookie (non-httpOnly for client-side access)
          user_cookie_options = cookie_options.merge(httponly: false)
          cookies[user_cookie_key] = { value: user_response.to_json, **user_cookie_options }

          # Redirect to frontend with pending registration flag and token
          # Include pending_token in URL as primary transmission method since
          # cross-subdomain SameSite=None cookies may be blocked by browsers
          redirect_params = {
            pending_registration: 'true',
            pending_token: pending_token,
            name: result[:name] || '',
            email: result[:email] || ''
          }
          if result[:phone_number].present?
            redirect_params[:phone_number] = result[:phone_number]
          end
          redirect_url = "#{oauth_redirect_base}?#{redirect_params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')}"
        end

        # Include state parameter if it was provided for CSRF validation
        if params[:state].present?
          redirect_url += "&state=#{CGI.escape(params[:state])}"
        end
        redirect_to redirect_url, allow_other_host: true, status: 302
        return
      end
      
      unless result[:success] && result[:user]
        redirect_to "#{oauth_redirect_base}?error=#{CGI.escape(result[:error] || 'Failed to create or link account')}", allow_other_host: true, status: 302
        return
      end
      
      user = result[:user]
      user_role = determine_role(user)
      
      # Block login if the user is soft-deleted
      if (user.is_a?(Buyer) || user.is_a?(Seller)) && user.deleted?
        redirect_to "#{oauth_redirect_base}?error=#{CGI.escape('Your account has been deleted. Please check your email for a reactivation link or request a new one.')}", allow_other_host: true, status: 302
        return
      end

      # Block login if the user is blocked
      if (user.is_a?(Buyer) || user.is_a?(Seller)) && user.blocked?
        redirect_to "#{oauth_redirect_base}?error=#{CGI.escape('Your account has been blocked. Please contact support.')}", allow_other_host: true, status: 302
        return
      end
      
      # Create JWT token
      token_payload = if user_role == 'Seller'
        { seller_id: user.id, email: user.email, role: user_role }
      else
        { user_id: user.id, email: user.email, role: user_role }
      end

      token = JsonWebToken.encode(token_payload)
      
      # Build user response
      user_response = {
        id: user.id,
        email: user.email,
        role: user_role
      }
      
      if user.respond_to?(:fullname) && user.fullname.present?
        user_response[:name] = user.fullname
      elsif user.respond_to?(:username) && user.username.present?
        user_response[:name] = user.username
      end
      
      if user.respond_to?(:username) && user.username.present?
        user_response[:username] = user.username
      end
      
      if user.respond_to?(:profile_picture) && user.profile_picture.present?
        user_response[:profile_picture] = user.profile_picture
      end
      
      # Include ads_count for sellers
      if user.respond_to?(:ads_count)
        user_response[:ads_count] = user.ads_count
      end
      
      # Update last active timestamp
      if user.respond_to?(:update_last_active!)
        user.update_last_active!
      end
      
      # Check for missing fields if this is a seller (for completion modal)
      missing_fields = []
      if user.is_a?(Seller)
        missing_fields = check_seller_missing_fields(user)
      end
      
      # For development: use URL token transmission (cookies don't work across ports)
      # For production: use secure server-side cookies with subdomain sharing
      if Rails.env.development?
        # Encode token and user data as base64 JSON for URL transmission
        auth_data = {
          token: token,
          user: user_response
        }
        if missing_fields.any?
          auth_data[:missing_fields] = missing_fields
        end
        encoded_data = Base64.urlsafe_encode64(auth_data.to_json)
        redirect_url = "#{oauth_redirect_base}?token=#{CGI.escape(encoded_data)}"
      else
        # Production: use secure server-side cookies with subdomain sharing
        Rails.logger.info "🍪 [GoogleOAuth] Production mode - using secure cookies with subdomain sharing"

        cookie_options = {
          httponly: true,
          secure: true,
          samesite: :none,  # Required for cross-subdomain requests
          domain: '.carboncube-ke.com',  # Share across carboncube-ke.com and anko.carboncube-ke.com
          expires: 60.days.from_now
        }

        # Set auth token cookie
        cookies[token_cookie_key] = { value: token, **cookie_options }

        # Set user data cookie (non-httpOnly for client-side access)
        user_cookie_options = cookie_options.merge(httponly: false)
        cookies[user_cookie_key] = { value: user_response.to_json, **user_cookie_options }

        # Include missing fields in user data if any (frontend will show modal)
        if missing_fields.any?
          user_response[:missing_fields] = missing_fields
          cookies[user_cookie_key] = { value: user_response.to_json, **user_cookie_options }
        end

        redirect_url = "#{oauth_redirect_base}?success=true"
      end

      # Include state parameter if it was provided for CSRF validation
      if params[:state].present?
        redirect_url += "&state=#{CGI.escape(params[:state])}"
      end
      redirect_to redirect_url, allow_other_host: true, status: 302

    rescue => e
      redirect_to "#{oauth_redirect_base}?error=#{CGI.escape('Authentication failed: ' + e.message)}", allow_other_host: true, status: 302
    end
  end
  
  # Retrieve OAuth data from cache using the code
  # The code can be either:
  # 1. An auth_code generated by google_oauth_callback (stored in cache)
  # 2. A Google authorization code that needs to be processed first
  def retrieve_oauth_data
    # Force JSON format for API responses
    request.format = :json if request.format == :html || request.format == Mime::Type.lookup('*/*')

    code = params[:code]
    
    unless code.present?
      render json: { success: false, error: 'Authorization code is required' }, status: :bad_request
      return
    end

    # First, try to retrieve from cache (this is the auth_code from callback handler)
    cache_key = "oauth_auth_#{code}"
    cached_data = Rails.cache.read(cache_key)
    
    if cached_data
      begin
        auth_data = JSON.parse(cached_data)

        # Delete from cache after retrieval (one-time use)
        Rails.cache.delete(cache_key)

        respond_to do |format|
          format.json {
            render json: {
              success: true,
              token: auth_data['token'],
              user: auth_data['user']
            }, status: :ok
          }
          format.html {
            render json: {
              success: true,
              token: auth_data['token'],
              user: auth_data['user']
            }, status: :ok
          }
          format.any {
            render json: {
              success: true,
              token: auth_data['token'],
              user: auth_data['user']
            }, status: :ok
          }
        end
        return
      rescue JSON::ParserError => e
        Rails.logger.error "❌ Failed to parse cached auth data: #{e.message}"
        render json: { success: false, error: 'Invalid auth data format' }, status: :internal_server_error
        return
      end
    end
    
    # Cache miss - check if this is our auth_code format or a Google authorization code
    # Our auth_codes are 32 hex characters (SecureRandom.hex(16))
    # Google authorization codes are typically longer and have a different format
    is_our_auth_code = code.length == 32 && code.match?(/\A[0-9a-f]+\z/i)

    if is_our_auth_code
      render json: { success: false, error: 'Invalid or expired authorization code' }, status: :not_found
      return
    end
    
    # This appears to be a Google authorization code - check if already processed
    processed_cache_key = "oauth_code_#{Digest::MD5.hexdigest(code)}"
    already_processed = Rails.cache.exist?(processed_cache_key)

    if already_processed
      render json: { success: false, error: 'This authorization code has already been used' }, status: :bad_request
      return
    end
    
    # Try to process it as a Google authorization code
    # This handles the case where the frontend receives the Google code directly
    begin
      # Use the same processing logic as google_oauth_callback
      # But we need role and state - if not provided, default to buyer
      role = params[:role] || 'buyer'
      
      # Try to exchange code for tokens with different redirect_uris
      # Google codes can be generated with either:
      # 1. The configured redirect_uri (redirect flow)
      # 2. 'postmessage' (GSI popup flow)
      token_response = nil
      redirect_uri = params[:redirect_uri]
      
      # Try with provided redirect_uri first, then fallback to common ones
      redirect_uris_to_try = []
      redirect_uris_to_try << redirect_uri if redirect_uri.present?
      redirect_uris_to_try << 'postmessage' # GSI popup flow
      redirect_uris_to_try << (ENV['GOOGLE_REDIRECT_URI']&.strip) if ENV['GOOGLE_REDIRECT_URI'].present?
      redirect_uris_to_try << "#{request.base_url}/auth/google_oauth2/callback" # Default fallback
      redirect_uris_to_try.uniq!

      redirect_uris_to_try.each do |uri|
        token_response = exchange_code_for_tokens_with_redirect_uri(code, uri)
        if token_response && token_response['access_token']
          break
        end
      end
      
      # Check if token exchange succeeded
      unless token_response && token_response['access_token']
        Rails.logger.error "❌ [GoogleOAuth] Failed to exchange code for tokens with any redirect_uri"
        render json: { 
          success: false, 
          error: 'Invalid or expired authorization code. Please try signing in again.' 
        }, status: :unauthorized
        return
      end
      
      access_token = token_response['access_token']
      refresh_token = token_response['refresh_token']
      expires_at = token_response['expires_in'] ? Time.current + token_response['expires_in'].seconds : nil
      
      # Get user info from Google
      user_info = get_google_user_info(access_token)
      
      unless user_info && user_info['email']
        Rails.logger.error "❌ [GoogleOAuth] Failed to get user info from Google"
        render json: { success: false, error: 'Failed to retrieve user information' }, status: :unauthorized
        return
      end
      
      # Build auth hash for OauthAccountLinkingService
      auth_hash = {
        provider: 'google_oauth2',
        uid: user_info['id'] || user_info['sub'],
        info: {
          email: user_info['email'],
          name: user_info['name'] || user_info['email'].split('@').first,
          image: user_info['picture'],
          first_name: user_info['given_name'],
          last_name: user_info['family_name']
        },
        credentials: {
          token: access_token,
          refresh_token: refresh_token,
          expires_at: expires_at&.to_i
        }
      }
      
      # Use OauthAccountLinkingService to create or link account
      user_ip = request.remote_ip
      
      # Check if this is a new seller registration - use pending mode to delay DB creation
      # pending_mode = true for new sellers, false for existing users or buyers
      pending_mode = (role.capitalize == 'Seller' && !find_user_by_email(user_info['email']))
      
      linking_service = OauthAccountLinkingService.new(auth_hash, role.capitalize, user_ip, pending_mode)
      result = linking_service.call
      
      unless result[:success]
        Rails.logger.error "❌ [GoogleOAuth] OAuth account linking failed: #{result[:error]}"
        render json: { success: false, error: result[:error] || 'Failed to create or link account' }, status: :unprocessable_entity
        return
      end
      
      # Handle pending registration (new sellers must complete onboarding first)
      if result[:pending_registration]
        pending_token = result[:pending_token]

        render json: {
          success: true,
          pending_registration: true,
          pending_token: pending_token,
          email: result[:email],
          name: result[:name],
          picture: result[:picture]
        }, status: :ok
        return
      end
      
      user = result[:user]
      user_role = determine_role(user)
      
      # Block login if the user is soft-deleted or blocked
      if (user.is_a?(Buyer) || user.is_a?(Seller)) && (user.deleted? || user.blocked?)
        error_msg = user.deleted? ? 'Your account has been deleted. Please check your email for a reactivation link or request a new one.' : 'Your account has been blocked. Please contact support.'
        render json: { success: false, error: error_msg }, status: :forbidden
        return
      end
      
      # Create JWT token
      token_payload = if user_role == 'Seller'
        { seller_id: user.id, email: user.email, role: user_role }
      else
        { user_id: user.id, email: user.email, role: user_role }
      end
      
      token = JsonWebToken.encode(token_payload)
      
      # Build user response
      user_response = {
        id: user.id,
        email: user.email,
        role: user_role
      }
      
      if user.respond_to?(:fullname) && user.fullname.present?
        user_response[:name] = user.fullname
      elsif user.respond_to?(:username) && user.username.present?
        user_response[:name] = user.username
      end
      
      if user.respond_to?(:username) && user.username.present?
        user_response[:username] = user.username
      end
      
      if user.respond_to?(:profile_picture) && user.profile_picture.present?
        user_response[:profile_picture] = user.profile_picture
      end
      
      # Include ads_count for sellers
      if user.respond_to?(:ads_count)
        user_response[:ads_count] = user.ads_count
      end
      
      # Update last active timestamp
      if user.respond_to?(:update_last_active!)
        user.update_last_active!
      end
      
      # Mark code as processed
      Rails.cache.write(processed_cache_key, true, expires_in: 5.minutes)

      render json: {
        success: true,
        token: token,
        user: user_response
      }, status: :ok
      
    rescue => e
      Rails.logger.error "❌ [GoogleOAuth] Exception processing code: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      render json: { success: false, error: 'Invalid or expired authorization code' }, status: :not_found
    end
  end

  # Complete registration with missing fields
  def complete_registration
    begin
      # Get the form data from the request
      form_data = params.permit(:fullname, :email, :phone_number, :location, :city, :age_group, :gender, :username, :profile_picture, :county_id, :sub_county_id, :age_group_id, :birthday, :given_name, :family_name, :display_name, :provider, :uid, :user_type, :enterprise_name, :business_registration_number, :document_type_id, :description)

      # Determine user type (default to buyer if not specified)
      user_type = form_data[:user_type] || 'Buyer'
      
      # Find the user by email (assuming email is provided)
      user = case user_type
             when 'seller'
               Seller.find_by(email: form_data[:email])
             else
               Buyer.find_by(email: form_data[:email])
             end
      
      success = false
      
      if user.nil?
        
        # Check if phone number already exists for another user
        if form_data[:phone_number].present?
          existing_user_with_phone = case user_type
                                     when 'seller'
                                       Seller.find_by(phone_number: form_data[:phone_number])
                                     else
                                       Buyer.find_by(phone_number: form_data[:phone_number])
                                     end
          if existing_user_with_phone
            render json: {
              success: false,
              error: "Phone number #{form_data[:phone_number]} is already registered to another account. Please use a different phone number."
            }, status: :unprocessable_entity
            return
          end
        end
        
        # Check if business name (enterprise_name) already exists for another seller
        # Only check for sellers since enterprise_name is seller-specific
        if user_type == 'seller' && form_data[:enterprise_name].present?
          # Check case-insensitively (database constraint is on lower(enterprise_name))
          existing_seller_with_name = Seller.where("LOWER(enterprise_name) = ?", form_data[:enterprise_name].downcase.strip).first
          if existing_seller_with_name
            render json: {
              success: false,
              error: "Business name '#{form_data[:enterprise_name]}' is already registered to another account. Please use a different business name."
            }, status: :unprocessable_entity
            return
          end
        end
        
        # Create new user with the provided data
        # Track if phone number is being added (for new users, this is always "just added" if present)
        phone_being_added = form_data[:phone_number].present?
        
        user_attributes = {}
        
        # Common attributes for both buyer and seller
        user_attributes[:fullname] = form_data[:fullname] if form_data[:fullname].present?
        user_attributes[:phone_number] = form_data[:phone_number] if form_data[:phone_number].present?
        user_attributes[:location] = form_data[:location] if form_data[:location].present?
        user_attributes[:city] = form_data[:city] if form_data[:city].present?
        user_attributes[:gender] = form_data[:gender] if form_data[:gender].present?
        user_attributes[:username] = form_data[:username] if form_data[:username].present?
        user_attributes[:email] = form_data[:email] if form_data[:email].present?
        user_attributes[:profile_picture] = form_data[:profile_picture] if form_data[:profile_picture].present?
        user_attributes[:provider] = form_data[:provider] if form_data[:provider].present?
        user_attributes[:uid] = form_data[:uid] if form_data[:uid].present?
        user_attributes[:county_id] = form_data[:county_id] if form_data[:county_id].present?
        user_attributes[:sub_county_id] = form_data[:sub_county_id] if form_data[:sub_county_id].present?
        
        # Seller-specific attributes
        if user_type == 'seller'
          # Generate unique enterprise name to avoid duplicates
          if form_data[:enterprise_name].present?
            user_attributes[:enterprise_name] = generate_unique_enterprise_name(form_data[:enterprise_name])
          end
          user_attributes[:business_registration_number] = form_data[:business_registration_number] if form_data[:business_registration_number].present?
          user_attributes[:document_type_id] = form_data[:document_type_id] if form_data[:document_type_id].present?
          user_attributes[:description] = form_data[:description] if form_data[:description].present?
        end
        
        # Handle age group - support both age_group (name) and age_group_id
        if form_data[:age_group_id].present?
          user_attributes[:age_group_id] = form_data[:age_group_id]
        elsif form_data[:age_group].present?
          age_group = AgeGroup.find_by(name: form_data[:age_group])
          if age_group
            user_attributes[:age_group_id] = age_group.id
          end
        end
        
        # Create the user as OAuth user (no password required)
        user_attributes[:provider] = form_data[:provider] || 'oauth' # Mark as OAuth user
        user_attributes[:uid] = form_data[:uid] || SecureRandom.hex(16) # Use provided UID or generate one
        # Set phone_provided_by_oauth: If we're in complete_registration, phone was NOT provided by OAuth
        # (because if it was, user wouldn't need to complete registration)
        # So phone_provided_by_oauth should always be false for users created via complete_registration
        user_attributes[:phone_provided_by_oauth] = false
        
        # Create the appropriate user type
        user = case user_type
               when 'seller'
                 Seller.new(user_attributes)
               else
                 Buyer.new(user_attributes)
               end
        
        # Capture device hash if provided for guest click association
        if params[:device_hash].present? && (user.is_a?(Buyer) || user.is_a?(Seller))
          user.device_hash_for_association = params[:device_hash]
        end
        
        ActiveRecord::Base.transaction do
          if user.save
            
            # Associate guest clicks after save (in case device_hash wasn't set before)
            if (user.is_a?(Buyer) || user.is_a?(Seller)) && params[:device_hash].present?
              begin
                GuestClickAssociationService.associate_clicks_with_user(user, params[:device_hash])
              rescue => e
                Rails.logger.error "Failed to associate guest clicks after OAuth registration: #{e.message}" if defined?(Rails.logger)
              end
            end
            
            # Handle seller-specific setup
            if user_type == 'seller'
              # OAuth signups (Continue with Google, etc.) always get Premium for 6 months (same as GoogleOauthService and OauthAccountLinkingService)
              if form_data[:provider].present?
                expiry_date = 6.months.from_now
                premium_tier = Tier.find_by(name: 'Premium') || Tier.find_by(id: 4)
                if premium_tier
                  user.seller_tier = SellerTier.create!(
                    seller: user,
                    tier: premium_tier,
                    duration_months: 6,
                    expires_at: expiry_date
                  )
                else
                  Rails.logger.error "❌ Premium tier not found for OAuth seller"
                  assign_free_tier(user)
                end
              elsif should_get_2026_premium?
                create_2026_premium_tier(user)
              else
                assign_free_tier(user)
              end
              # Ensure seller always has a tier (create_2026_premium_tier can return without creating if tier missing/error)
              assign_free_tier(user) if user.seller_tier.blank?

              # Create main branch for OAuth sellers
              create_main_branch_for_seller(user)

              # Create first ad (required)
              create_first_ad_for_seller(user, params)
            end

            success = true
          else
            raise ActiveRecord::Rollback
          end
        end
      else
        
        # Check if phone number already exists for another user (excluding current user)
        if form_data[:phone_number].present?
          existing_user_with_phone = case user_type
                                     when 'seller'
                                       Seller.find_by(phone_number: form_data[:phone_number])
                                     else
                                       Buyer.find_by(phone_number: form_data[:phone_number])
                                     end
          if existing_user_with_phone && existing_user_with_phone.id != user.id
            render json: {
              success: false,
              error: "Phone number #{form_data[:phone_number]} is already registered to another account. Please use a different phone number."
            }, status: :unprocessable_entity
            return
          end
        end
        
        # Check if business name (enterprise_name) already exists for another seller (excluding current user)
        # Only check for sellers since enterprise_name is seller-specific
        if user_type == 'seller' && form_data[:enterprise_name].present?
          # Check case-insensitively (database constraint is on lower(enterprise_name))
          existing_seller_with_name = Seller.where("LOWER(enterprise_name) = ?", form_data[:enterprise_name].downcase.strip).where.not(id: user.id).first
          if existing_seller_with_name
            render json: {
              success: false,
              error: "Business name '#{form_data[:enterprise_name]}' is already registered to another account. Please use a different business name."
            }, status: :unprocessable_entity
            return
          end
        end
        
        # Update existing user with the provided data
        # Track if phone number is being added (didn't exist before)
        phone_number_before = user.phone_number
        phone_being_added = form_data[:phone_number].present? && phone_number_before.blank?
        
        user_attributes = {}
        # When adding phone in complete_registration, mark as not from OAuth so welcome WhatsApp is sent
        user_attributes[:phone_provided_by_oauth] = false if phone_being_added
        
        # Common attributes for both buyer and seller
        user_attributes[:fullname] = form_data[:fullname] if form_data[:fullname].present?
        user_attributes[:phone_number] = form_data[:phone_number] if form_data[:phone_number].present?
        user_attributes[:location] = form_data[:location] if form_data[:location].present?
        user_attributes[:city] = form_data[:city] if form_data[:city].present?
        user_attributes[:gender] = form_data[:gender] if form_data[:gender].present?
        user_attributes[:username] = form_data[:username] if form_data[:username].present?
        user_attributes[:profile_picture] = form_data[:profile_picture] if form_data[:profile_picture].present?
        user_attributes[:county_id] = form_data[:county_id] if form_data[:county_id].present?
        user_attributes[:sub_county_id] = form_data[:sub_county_id] if form_data[:sub_county_id].present?
        
        # Seller-specific attributes
        if user_type == 'seller'
          user_attributes[:enterprise_name] = form_data[:enterprise_name] if form_data[:enterprise_name].present?
          user_attributes[:business_registration_number] = form_data[:business_registration_number] if form_data[:business_registration_number].present?
          user_attributes[:document_type_id] = form_data[:document_type_id] if form_data[:document_type_id].present?
          user_attributes[:description] = form_data[:description] if form_data[:description].present?
        end
        
        # Handle age group
        if form_data[:age_group].present?
          age_group = AgeGroup.find_by(name: form_data[:age_group])
          if age_group
            user_attributes[:age_group_id] = age_group.id
          end
        end
        
        # Update the user
        ActiveRecord::Base.transaction do
          if user.update(user_attributes)
            
            # Handle seller-specific setup: OAuth sellers get Premium if missing tier; else 2026 promo
            if user_type == 'seller' && user.seller_tier.blank?
              if form_data[:provider].present?
                expiry_date = 6.months.from_now
                premium_tier = Tier.find_by(name: 'Premium') || Tier.find_by(id: 4)
                if premium_tier
                  user.seller_tier = SellerTier.create!(
                    seller: user,
                    tier: premium_tier,
                    duration_months: 6,
                    expires_at: expiry_date
                  )
                end
              elsif should_get_2026_premium?
                create_2026_premium_tier(user)
              end
            end

            if user_type == 'seller'
              # Create main branch for OAuth sellers if missing
              create_main_branch_for_seller(user)

              # Create first ad (required)
              create_first_ad_for_seller(user, params)
            end

            success = true
          else
            raise ActiveRecord::Rollback
          end
        end
      end

      unless success
        render json: {
          success: false,
          error: "Failed to complete registration: #{user.errors.full_messages.join(', ')}"
        }, status: :unprocessable_entity
        return
      end
      
      # Check if user is deleted or blocked before generating token
      if (user.is_a?(Buyer) || user.is_a?(Seller)) && user.deleted?
        render json: {
          success: false,
          error: 'Your account has been deleted. Please check your email for a reactivation link or request a new one.'
        }, status: :unauthorized
        return
      end

      if user.is_a?(Buyer) && user.blocked?
        render json: {
          success: false,
          error: 'Your account has been blocked. Please contact support.'
        }, status: :unauthorized
        return
      end

      if user.is_a?(Seller) && user.blocked?
        render json: {
          success: false,
          error: 'Your account has been blocked. Please contact support.'
        }, status: :unauthorized
        return
      end
      
      # Generate JWT token using JsonWebToken service
      token_payload = if user.is_a?(Seller)
        { seller_id: user.id, email: user.email, role: 'Seller' }
      else
        { user_id: user.id, email: user.email, role: 'Buyer' }
      end
      
      token = JsonWebToken.encode(token_payload)
      
      # Build user response
      user_response = {
        id: user.id,
        email: user.email,
        role: user.is_a?(Seller) ? 'Seller' : 'Buyer'
      }
      
      if user.respond_to?(:fullname) && user.fullname.present?
        user_response[:name] = user.fullname
      elsif user.respond_to?(:username) && user.username.present?
        user_response[:name] = user.username
      end
      
      if user.respond_to?(:username) && user.username.present?
        user_response[:username] = user.username
      end
      
      if user.respond_to?(:profile_picture) && user.profile_picture.present?
        user_response[:profile_picture] = user.profile_picture
      end
      
      render json: {
        success: true,
        token: token,
        user: user_response
      }, status: :ok
    rescue => e
      Rails.logger.error "❌ Complete registration error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      render json: { success: false, error: 'Failed to complete registration' }, status: :internal_server_error
    end
  end

  # Complete Google OAuth registration after first ad is created
  def complete_google_registration
    begin
      # Get the pending token and form data
      pending_token = params[:pending_token]
      form_data = params.permit(:fullname, :email, :phone_number, :location, :city, :county_id, :sub_county_id, :enterprise_name, :description, :ad_title, :ad_price, :ad_description, :ad_category, :ad_subcategory, :ad_condition, :ad_brand, :ad_manufacturer, :ad_images)

      unless pending_token.present?
        render json: { success: false, error: 'Pending token is required' }, status: :bad_request
        return
      end
      
      # Retrieve pending registration data from cache
      cache_key = "pending_google_registration_#{pending_token}"
      cached_data = Rails.cache.read(cache_key)
      
      unless cached_data
        Rails.logger.warn "⚠️ Pending registration not found or expired"
        render json: { success: false, error: 'Invalid or expired pending token' }, status: :not_found
        return
      end

      # Delete from cache (one-time use)
      Rails.cache.delete(cache_key)
      
      # Check if user already exists (race condition check)
      existing_user = Seller.find_by(email: cached_data['email'])
      if existing_user
        Rails.logger.warn "⚠️ User already exists: #{cached_data['email']}"
        render json: { success: false, error: 'User already registered' }, status: :conflict
        return
      end
      
      # Validate required fields for branch creation
      missing_fields = []
      missing_fields << "Enterprise name" unless form_data[:enterprise_name].present?
      missing_fields << "Location" unless form_data[:location].present?
      
      if missing_fields.any?
        Rails.logger.error "Missing required fields for Google seller registration: #{missing_fields.join(', ')}"
        render json: {
          success: false,
          error: "Missing required fields: #{missing_fields.join(', ')}"
        }, status: :unprocessable_entity
        return
      end

      # Build buyer attributes from cached OAuth data and form data (with pending seller data)
      buyer_attributes = {
        fullname: cached_data['name'] || form_data[:fullname],
        email: cached_data['email'],
        username: generate_unique_username(cached_data['name'] || cached_data['email'].split('@').first),
        provider: cached_data['provider'],
        uid: cached_data['uid'],
        oauth_token: cached_data['oauth_token'],
        oauth_refresh_token: cached_data['oauth_refresh_token'],
        oauth_expires_at: cached_data['oauth_expires_at'],
        # Form data
        phone_number: form_data[:phone_number],
        location: form_data[:location],
        profile_picture: cached_data['picture']
      }
      
      # Create buyer in transaction
      ActiveRecord::Base.transaction do
        buyer = Buyer.create!(buyer_attributes)
        
        # Store pending seller profile data
        buyer.update(
          pending_seller_fullname: cached_data['name'] || form_data[:fullname],
          pending_seller_phone_number: form_data[:phone_number],
          pending_seller_location: form_data[:location],
          pending_seller_enterprise_name: form_data[:enterprise_name],
          pending_seller_county_id: form_data[:county_id],
          pending_seller_sub_county_id: form_data[:sub_county_id],
          pending_seller_description: form_data[:description]
        )
        
        # Auto-verify email for Google OAuth users
        mark_email_as_verified(buyer.email)

        # Generate JWT token
        token = JsonWebToken.encode({ user_id: buyer.id, email: buyer.email, role: 'buyer' })
        
        # Build user response
        user_response = {
          id: buyer.id,
          email: buyer.email,
          role: 'buyer',
          name: buyer.fullname,
          username: buyer.username,
          profile_picture: buyer.profile_picture
        }

        render json: {
          success: true,
          token: token,
          user: user_response
        }, status: :ok
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "❌ Failed to create Google seller: #{e.message}"
      Rails.logger.error "Validation errors: #{e.record.errors.full_messages}"
      render json: {
        success: false,
        error: "Failed to create seller account: #{e.record.errors.full_messages.join(', ')}"
      }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "❌ Complete Google registration error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      render json: { success: false, error: 'Failed to complete registration' }, status: :internal_server_error
    end
  end

  private

  def token_cookie_key
    Rails.env.production? ? '__Secure-auth_token' : 'auth_token'
  end

  def user_cookie_key
    Rails.env.production? ? '__Secure-auth_user' : 'auth_user'
  end

  def mark_email_as_verified(email)
    return unless email.present?
    
    EmailOtp.where(email: email, verified: false).delete_all
    
    email_otp = EmailOtp.find_or_initialize_by(email: email)
    email_otp.update!(
      verified: true,
      otp_code: nil,
      expires_at: nil
    )
  rescue => e
    Rails.logger.error "❌ Failed to mark email as verified: #{e.message}"
  end
  
  def exchange_code_for_tokens(code, redirect_uri = nil)
    redirect_uri ||= (ENV['GOOGLE_REDIRECT_URI']&.strip) || "#{request.base_url}/auth/google_oauth2/callback"
    exchange_code_for_tokens_with_redirect_uri(code, redirect_uri)
  end

  def exchange_code_for_tokens_with_redirect_uri(code, redirect_uri)
    client_id = ENV['GOOGLE_OAUTH_CLIENT_ID']&.strip
    client_secret = ENV['GOOGLE_OAUTH_CLIENT_SECRET']&.strip

    unless client_id.present? && client_secret.present?
      return nil
    end

    # Ensure redirect_uri has no trailing slash (Google is strict about exact match)
    redirect_uri = redirect_uri.chomp('/') if redirect_uri.end_with?('/')

    begin
      request_body = {
        code: code,
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri,
        grant_type: 'authorization_code'
      }
      
      response = HTTParty.post('https://oauth2.googleapis.com/token', {
        body: request_body,
        headers: {
          'Content-Type' => 'application/x-www-form-urlencoded'
        },
        timeout: 30
      })

      if response.success?
        JSON.parse(response.body)
      else
        nil
      end
    rescue => e
      nil
    end
  end
  
  def get_google_user_info(access_token)
    response = HTTParty.get('https://www.googleapis.com/oauth2/v2/userinfo', {
      headers: {
        'Authorization' => "Bearer #{access_token}"
      }
    })
    
    if response.success?
      JSON.parse(response.body)
    else
      nil
    end
  end

  def google_oauth_popup_callback
    # Redirect to regular callback - popup flow not currently used
    redirect_to "/auth/google_oauth2/callback?#{params.to_query}"
  end

  private

  # Create first ad for a seller (required for all seller signups)
  def create_first_ad_for_seller(seller, ad_params)
    return unless seller.is_a?(Seller)

    unless ad_params[:ad_title].present? && ad_params[:ad_price].present? && ad_params[:ad_category].present?
      Rails.logger.error "First ad data is missing: ad_title, ad_price, and ad_category are required"
      seller.errors.add(:base, "First ad data is required. Please fill in the ad details.")
      raise ActiveRecord::Rollback
    end

    ad = seller.ads.build(
      title: ad_params[:ad_title],
      price: ad_params[:ad_price].to_s.gsub(/,/, '').to_f,
      description: ad_params[:ad_description],
      category_id: ad_params[:ad_category],
      subcategory_id: ad_params[:ad_subcategory],
      condition: ad_params[:ad_condition],
      brand: ad_params[:ad_brand],
      manufacturer: ad_params[:ad_manufacturer],
      is_added_by_sales: false
    )

    # Process and upload ad images if present
    if ad_params[:ad_images].present?
      begin
        uploaded_media = process_and_upload_ad_images(ad_params[:ad_images])
        ad.media = uploaded_media
      rescue => e
        Rails.logger.error "❌ Error processing ad images: #{e.message}"
      end
    end

    if ad.save
    else
      Rails.logger.error "Failed to create first ad for OAuth seller: #{ad.errors.full_messages.inspect}"
      seller.errors.add(:base, "Failed to create first ad: #{ad.errors.full_messages.join(', ')}")
      raise ActiveRecord::Rollback
    end
  end

  # Create the main branch for a seller if they don't have one and have required fields
  def create_main_branch_for_seller(seller)
    return unless seller.is_a?(Seller)
    return if seller.branches.exists?
    return unless seller.enterprise_name.present? && seller.location.present?

    branch = seller.branches.build(
      name: seller.enterprise_name,
      location: seller.location,
      is_main_branch: true
    )

    if branch.save
    else
      Rails.logger.error "Failed to create main branch for seller: #{branch.errors.full_messages.inspect}"
    end
  end

  # Check if user should get premium status for 2025 registrations
  def should_get_2026_premium?
    current_year = Time.current.year
    current_year == 2026
  end

  # Get premium tier for 2025 users
  def get_premium_tier
    Tier.find_by(name: 'Premium')
  end

  # Create seller tier for 2026 premium users
  def create_2026_premium_tier(seller)
    unless should_get_2026_premium?
      return
    end
    
    premium_tier = get_premium_tier
    unless premium_tier
      Rails.logger.error "❌ Premium tier not found in database"
      return
    end
    
    expires_at = Time.new(2027, 1, 1, 0, 0, 0)

    # Calculate remaining months until end of 2026
    current_date = Time.current
    end_of_2026 = Time.new(2026, 12, 31, 23, 59, 59)
    remaining_days = ((end_of_2026 - current_date) / 1.day).ceil
    duration_months = (remaining_days / 30.44).ceil # Average days per month
    
    # Create seller tier with premium status until end of 2025
    seller_tier = SellerTier.create!(
      seller: seller,
      tier: premium_tier,
      duration_months: duration_months,
      expires_at: expires_at
    )
    
  rescue => e
    Rails.logger.error "❌ Error creating premium tier: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def process_and_upload_ad_images(images)
    uploaded_urls = []

    begin
      Array(images).each do |image|
        begin
          # Check if tempfile exists and is readable
          unless image.tempfile && File.exist?(image.tempfile.path)
            Rails.logger.error "❌ Tempfile not found for image: #{image.original_filename}"
            next
          end

          # Check Cloudinary configuration
          unless ENV['UPLOAD_PRESET'].present?
            Rails.logger.error "❌ UPLOAD_PRESET environment variable is not set"
            raise "UPLOAD_PRESET not configured"
          end

          # Upload original image directly to Cloudinary without any processing
          uploaded_image = Cloudinary::Uploader.upload(
            image.tempfile.path,
            upload_preset: ENV['UPLOAD_PRESET'],
            format: nil,
            background: "transparent"
          )

          uploaded_urls << uploaded_image["secure_url"]
        rescue => e
          Rails.logger.error "❌ Error uploading image #{image.original_filename}: #{e.message}"
          Rails.logger.error "❌ Error class: #{e.class}"
          Rails.logger.error e.backtrace.join("\n")
          # Don't fail completely, just skip this image
        end
      end
    rescue => e
      Rails.logger.error "❌ Error in process_and_upload_ad_images: #{e.message}"
      Rails.logger.error "❌ Error class: #{e.class}"
      Rails.logger.error e.backtrace.join("\n")
      raise e # Re-raise to be caught by the calling method
    end

    uploaded_urls
  end

  def assign_free_tier(seller)
    default_tier = Tier.find_by(name: 'Free') || Tier.first
    if default_tier
      seller.seller_tier = SellerTier.create!(
        seller: seller,
        tier: default_tier,
        duration_months: 0 # Free tier has no expiration
      )
    end
  end

  def find_user_by_email(email)
    return nil if email.blank?
    normalized_email = email.to_s.strip.downcase
    # Priority: Seller -> Buyer -> Admin -> others
    # Sellers take priority — upgraded buyers no longer have a buyer record (it was destroyed).
    Seller.find_by(email: normalized_email) ||
    Buyer.find_by(email: normalized_email) ||
    Admin.find_by(email: normalized_email) ||
    SalesUser.find_by(email: normalized_email) ||
    MarketingUser.find_by(email: normalized_email)
  end


  # Generate username from the actual name provided
  # Note: We do NOT extract from email - we use the real name
  def generate_unique_username(name)
    # Handle nil or empty names
    if name.blank?
      Rails.logger.warn "⚠️ No name provided for username generation, using fallback"
      return generate_fallback_username
    end
    
    # Generate username from the actual name (not email extraction)
    base_username = name.downcase.gsub(/[^a-z0-9]/, '').first(15)
    
    # Ensure we have a valid base username
    if base_username.blank? || base_username.length < 3
      Rails.logger.warn "⚠️ Invalid name for username generation: '#{name}', using fallback"
      return generate_fallback_username
    end
    
    username = base_username
    counter = 1
    
    while Buyer.exists?(username: username) || Seller.exists?(username: username) || 
          Admin.exists?(username: username)
      username = "#{base_username}#{counter}"
      counter += 1
    end
    
    username
  end

  # Generate a fallback username when no proper name is available
  def generate_fallback_username
    base_username = "user"
    username = base_username
    counter = 1
    
    while Buyer.exists?(username: username) || Seller.exists?(username: username) || 
          Admin.exists?(username: username)
      username = "#{base_username}#{counter}"
      counter += 1
    end
    
    username
  end

  def generate_placeholder_phone
    # Generate a placeholder phone number that won't conflict
    loop do
      phone = "0#{rand(100000000..999999999)}"
      break phone unless Buyer.exists?(phone_number: phone) || Seller.exists?(phone_number: phone)
    end
  end


  def calculate_age(birth_date)
    today = Date.current
    age = today.year - birth_date.year
    age -= 1 if today.month < birth_date.month || (today.month == birth_date.month && today.day < birth_date.day)
    age
  end

  def find_user_by_id_and_role(user_id, role)
    case role
    when 'Buyer'
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
      nil
    end
  end

  def determine_role(user)
    case user
    when Buyer then 'Buyer'
    when Seller then 'Seller'
    when Admin then 'Admin'
    when SalesUser then 'Sales'
    when MarketingUser then 'Marketing'
    else 'Unknown'
    end
  end

  def generate_username(email)
    # Extract username from email (part before @)
    username = email.split('@').first
    # Remove any special characters and limit length
    username = username.gsub(/[^a-zA-Z0-9]/, '').downcase
    # Ensure it's at least 3 characters
    username = username.length >= 3 ? username : username + 'user'
    # Limit to 20 characters
    username = username[0..19]
    # Make it unique if needed
    base_username = username
    counter = 1
    while Buyer.exists?(username: username)
      username = "#{base_username}#{counter}"
      counter += 1
    end
    username
  end

  # Generate unique enterprise name to avoid duplicates
  def generate_unique_enterprise_name(base_name)
    return 'Business' if base_name.blank?
    
    # Clean the base name
    clean_name = base_name.strip.gsub(/[^a-zA-Z0-9\s]/, '')
    return 'Business' if clean_name.blank?
    
    enterprise_name = clean_name
    counter = 1
    
    while Seller.exists?(enterprise_name: enterprise_name)
      enterprise_name = "#{clean_name} #{counter}"
      counter += 1
    end
    
    enterprise_name
  end

  # Check which required seller fields are missing
  def check_seller_missing_fields(seller)
    missing_fields = []
    
    # Check each required field based on Seller model validations
    missing_fields << 'fullname' if seller.fullname.blank? || seller.fullname.strip.empty?
    missing_fields << 'phone_number' if seller.phone_number.blank? || seller.phone_number.strip.empty?
    missing_fields << 'enterprise_name' if seller.enterprise_name.blank? || seller.enterprise_name.strip.empty?
    missing_fields << 'location' if seller.location.blank? || seller.location.strip.empty? || seller.location == 'Location to be updated'
    missing_fields << 'county_id' if seller.county_id.blank?
    missing_fields << 'sub_county_id' if seller.sub_county_id.blank?
    missing_fields << 'description' if seller.description.blank? || seller.description.strip.empty?

    missing_fields
  end

end
