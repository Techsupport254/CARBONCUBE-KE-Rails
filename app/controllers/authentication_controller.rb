class AuthenticationController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false
  require 'timeout'
  require 'digest'


  def login
    email = params[:email]
    unless email.present?
      render json: { errors: ['Email is required'] }, status: :bad_request
      return
    end
    remember_me = params[:remember_me] == true || params[:remember_me] == 'true'
    @user = find_user_by_email(email)

    if @user&.authenticate(params[:password])
      role = determine_role(@user)

      # Block login if the user is soft-deleted
      if (@user.is_a?(Buyer) || @user.is_a?(Seller)) && @user.deleted?
        render json: { errors: ['Your account has been deleted. Please contact support.'] }, status: :unauthorized
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
      # Return cached profile picture URLs - frontend will convert them to absolute URLs
      if @user.respond_to?(:profile_picture) && @user.profile_picture.present?
        user_response[:profile_picture] = @user.profile_picture
      end
      
      # Include enterprise_name for sellers
      if @user.respond_to?(:enterprise_name) && @user.enterprise_name.present?
        user_response[:enterprise_name] = @user.enterprise_name
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
    token = request.headers['Authorization']&.split(' ')&.last
    
    if token
      # Extract user info before blacklisting
      begin
        payload = JsonWebToken.decode(token)
        user_id = payload[:user_id] || payload[:seller_id]
        role = payload[:role]
        
        # Update last_active_at for sellers before logout
        if role == 'Seller' && user_id
          seller = Seller.find_by(id: user_id)
          seller&.update_last_active!
        end
        
        # Blacklist the token
        JwtService.blacklist_token(token)
        
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
        error: 'Account has been deleted',
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
    # Return cached profile picture URLs - frontend will convert them to absolute URLs
    if user.respond_to?(:profile_picture) && user.profile_picture.present?
      user_response[:profile_picture] = user.profile_picture
    end

    render json: { user: user_response }, status: :ok
  end

  def google_oauth
    Rails.logger.info "🌐 [GoogleOAuth] Google OAuth endpoint called"
    Rails.logger.info "   Method: #{request.method}"
    Rails.logger.info "   Params: #{params.except(:controller, :action).keys.join(', ')}"

    # If we have a code, process it (frontend sending authorization code from GSI popup)
    if params[:code].present?
      Rails.logger.info "🔄 [GoogleOAuth] Authorization code detected - processing authentication"
      process_google_oauth_code
      return
    end
    
    # Otherwise, generate OAuth URL (legacy flow or fallback)
    Rails.logger.info "🔄 [GoogleOAuth] Generating OAuth URL (no code provided)"
    
    # Log all Google OAuth environment variables for debugging
    Rails.logger.info "=" * 80
    Rails.logger.info "🔍 Google OAuth Environment Variables Debug:"
    Rails.logger.info "=" * 80
    Rails.logger.info "   GOOGLE_OAUTH_CLIENT_ID: #{ENV['GOOGLE_OAUTH_CLIENT_ID'].inspect}"
    Rails.logger.info "   GOOGLE_OAUTH_CLIENT_SECRET: #{ENV['GOOGLE_OAUTH_CLIENT_SECRET'] ? '***' + ENV['GOOGLE_OAUTH_CLIENT_SECRET'][-4..-1] : 'nil'}"
    Rails.logger.info "   GOOGLE_REDIRECT_URI: #{ENV['GOOGLE_REDIRECT_URI'].inspect}"
    Rails.logger.info "   REACT_APP_GOOGLE_CLIENT_ID: #{ENV['REACT_APP_GOOGLE_CLIENT_ID'].inspect}"
    Rails.logger.info "   REACT_APP_GOOGLE_REDIRECT_URI: #{ENV['REACT_APP_GOOGLE_REDIRECT_URI'].inspect}"
    Rails.logger.info "   RAILS_ENV: #{ENV['RAILS_ENV'].inspect}"
    Rails.logger.info "   Request base_url: #{request.base_url}"
    Rails.logger.info "=" * 80
    
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
    
    # Log redirect URI for debugging
    Rails.logger.info "🔍 Google OAuth Configuration:"
    Rails.logger.info "   Client ID: #{client_id}"
    Rails.logger.info "   Client ID (from ENV): #{ENV['GOOGLE_OAUTH_CLIENT_ID']}"
    Rails.logger.info "   Redirect URI: #{redirect_uri}"
    Rails.logger.info "   Redirect URI (from ENV): #{ENV['GOOGLE_REDIRECT_URI']}"
    Rails.logger.info "   Request base_url: #{request.base_url}"
    Rails.logger.info "   ⚠️  Make sure this EXACT redirect URI is in Google Cloud Console!"
    Rails.logger.info "   ⚠️  Also verify the Client ID matches exactly!"
    
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
    Rails.logger.info "🔍 OAuth Query Parameters:"
    Rails.logger.info "   redirect_uri (raw): #{redirect_uri}"
    Rails.logger.info "   Full auth URL: #{auth_url}"
    
    Rails.logger.info "Generated Google OAuth URL for role: #{role}"
    Rails.logger.info "Full OAuth URL (first 200 chars): #{auth_url[0..200]}..."
    Rails.logger.info "Full OAuth URL: #{auth_url}"
    
    
    render json: { 
      success: true, 
      auth_url: auth_url 
    }, status: :ok
  end

  # GET endpoint for initiating OAuth flow with redirect (generates signed state)
  def google_oauth_initiate
    # Get role from params (default to buyer)
    role = params[:role] || 'buyer'
    
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
    Rails.logger.info "🔄 [GoogleOAuth] Processing Google OAuth code request"
    Rails.logger.info "   IP: #{request.remote_ip}"
    Rails.logger.info "   User-Agent: #{request.user_agent}"

    code = params[:code]
    redirect_uri = params[:redirect_uri] || 'postmessage' # GSI uses 'postmessage'
    role = params[:role] || 'buyer'
    location_data = params[:location_data]
    is_registration = params[:is_registration] == true || params[:is_registration] == 'true'
    user_ip = request.remote_ip

    Rails.logger.info "🔍 [GoogleOAuth] Parameters received:"
    Rails.logger.info "   code: #{code ? 'present (' + code[0..10] + '...)' : 'MISSING'}"
    Rails.logger.info "   redirect_uri: #{redirect_uri}"
    Rails.logger.info "   role: #{role}"
    Rails.logger.info "   is_registration: #{is_registration}"
    Rails.logger.info "   user_ip: #{user_ip}"
    Rails.logger.info "   location_data: #{location_data ? 'present' : 'none'}"
    
    
    begin
      Rails.logger.info "🔧 [GoogleOAuth] Initializing GoogleOauthService"
      Rails.logger.info "   Role: #{role.capitalize}"
      Rails.logger.info "   Registration mode: #{is_registration}"

      # Initialize GoogleOauthService
      oauth_service = GoogleOauthService.new(
        code,
        redirect_uri,
        user_ip,
        role.capitalize,
        location_data,
        is_registration
      )

      Rails.logger.info "✅ [GoogleOAuth] GoogleOauthService initialized successfully"

      # Authenticate user
      Rails.logger.info "[GoogleOAuth] Calling authenticate method"
      result = oauth_service.authenticate
      Rails.logger.info "📋 [GoogleOAuth] Authentication completed"
      Rails.logger.info "   Result type: #{result.class}"
      Rails.logger.info "   Success: #{result.is_a?(Hash) ? result[:success] : 'N/A'}"
      
      # Ensure result is always a hash (safety check)
      unless result.is_a?(Hash)
        Rails.logger.error "❌ [GoogleOAuth] Result is not a hash: #{result.class}"
        Rails.logger.error "   Result: #{result.inspect}"
        result = {
          success: false,
          error: "Authentication service returned an unexpected response format."
        }
      end

      Rails.logger.info "📊 [GoogleOAuth] Processing authentication result"
      Rails.logger.info "   Success: #{result[:success]}"
      Rails.logger.info "   Error: #{result[:error]}" if result[:error]
      Rails.logger.info "   User: #{result[:user] ? 'present' : 'none'}" if result[:user]
      Rails.logger.info "   Token: #{result[:token] ? 'present' : 'none'}" if result[:token]
      Rails.logger.info "   Existing user: #{result[:existing_user]}" if result.key?(:existing_user)
      Rails.logger.info "   New user: #{result[:new_user]}" if result.key?(:new_user)
      Rails.logger.info "   Missing fields: #{result[:missing_fields]}" if result[:missing_fields]
      Rails.logger.info "   Account exists: #{result[:account_exists]}" if result.key?(:account_exists)

      if result[:success]
        Rails.logger.info "✅ [GoogleOAuth] Authentication successful - rendering success response"
        render json: result, status: :ok
      else
        Rails.logger.warn "⚠️ [GoogleOAuth] Authentication failed - rendering error response"
        Rails.logger.warn "   Error: #{result[:error]}" if result[:error]

        # Ensure error field is present for better frontend error handling
        result[:error] ||= "Authentication failed. Please try again." unless result[:error]
        render json: result, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "=" * 80
      Rails.logger.error "❌ [GoogleOAuth] Exception processing OAuth code"
      Rails.logger.error "   Error class: #{e.class}"
      Rails.logger.error "   Error message: #{e.message}"
      Rails.logger.error "   Parameters at time of error:"
      Rails.logger.error "     code: #{code ? 'present' : 'MISSING'}"
      Rails.logger.error "     redirect_uri: #{redirect_uri}"
      Rails.logger.error "     role: #{role}"
      Rails.logger.error "     is_registration: #{is_registration}"
      Rails.logger.error "   Backtrace (first 15 lines):"
      Rails.logger.error e.backtrace.first(15).join("\n")
      Rails.logger.error "=" * 80

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
    rescue ActiveSupport::MessageVerifier::InvalidSignature => e
      redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Invalid state parameter')}", allow_other_host: true, status: 302
      return
    rescue => e
      redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Invalid state parameter')}", allow_other_host: true, status: 302
      return
    end
    
    # Exchange authorization code for tokens
    code = params[:code]
    unless code.present?
      redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Authorization code missing')}", allow_other_host: true, status: 302
      return
    end
    
    begin
      # Exchange code for access token
      token_response = exchange_code_for_tokens(code)

      unless token_response && token_response['access_token']
        redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Failed to authenticate with Google')}", allow_other_host: true, status: 302
        return
      end
      
      access_token = token_response['access_token']
      refresh_token = token_response['refresh_token']
      expires_at = token_response['expires_in'] ? Time.current + token_response['expires_in'].seconds : nil
      
      # Get user info from Google
      user_info = get_google_user_info(access_token)

      unless user_info && user_info['email']
        redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Failed to retrieve user information')}", allow_other_host: true, status: 302
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
      
      # Use OauthAccountLinkingService to create or link account
      user_ip = request.remote_ip
      linking_service = OauthAccountLinkingService.new(auth_hash, role.capitalize, user_ip)
      result = linking_service.call
      
      unless result[:success] && result[:user]
        redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape(result[:error] || 'Failed to create or link account')}", allow_other_host: true, status: 302
        return
      end
      
      user = result[:user]
      user_role = determine_role(user)
      
      # Block login if the user is soft-deleted
      if (user.is_a?(Buyer) || user.is_a?(Seller)) && user.deleted?
        redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Your account has been deleted. Please contact support.')}", allow_other_host: true, status: 302
        return
      end
      
      # Block login if the user is blocked
      if (user.is_a?(Buyer) || user.is_a?(Seller)) && user.blocked?
        redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Your account has been blocked. Please contact support.')}", allow_other_host: true, status: 302
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
      
      # Update last active timestamp
      if user.respond_to?(:update_last_active!)
        user.update_last_active!
      end
      
      # Check for missing fields if this is a seller (for completion modal)
      missing_fields = []
      if user.is_a?(Seller)
        missing_fields = check_seller_missing_fields(user)
        Rails.logger.info "🔍 Seller missing fields detected: #{missing_fields.join(', ')}" if missing_fields.any?
      end
      
      # Encode token and user data as base64 JSON for URL fragment (no cache needed)
      # URL fragments (#) are client-side only and not sent to server, making them more secure
      auth_data = {
        token: token,
        user: user_response
      }
      
      # Include missing fields if any (frontend will show modal)
      if missing_fields.any?
        auth_data[:missing_fields] = missing_fields
      end
      
      # Base64 encode the JSON data for URL-safe transmission
      # Base64 is part of Ruby standard library, no require needed
      encoded_data = Base64.urlsafe_encode64(auth_data.to_json)
      
      # Redirect to frontend with token in query parameter (URL encoded)
      # No cache needed - token is passed directly in redirect
      redirect_url = "#{frontend_url}/auth/google/callback?token=#{CGI.escape(encoded_data)}"
      
      # Use redirect_to for proper redirect handling
      redirect_to redirect_url, allow_other_host: true, status: 302
      
    rescue => e
      redirect_to "#{frontend_url}/auth/google/callback?error=#{CGI.escape('Authentication failed: ' + e.message)}", allow_other_host: true, status: 302
    end
  end
  
  # Retrieve OAuth data from cache using the code
  # The code can be either:
  # 1. An auth_code generated by google_oauth_callback (stored in cache)
  # 2. A Google authorization code that needs to be processed first
  def retrieve_oauth_data
    # Force JSON format for API responses
    request.format = :json if request.format == :html || request.format == Mime::Type.lookup('*/*')
    
    Rails.logger.info "=" * 80
    Rails.logger.info "📥 [GoogleOAuth] retrieve_oauth_data called"
    Rails.logger.info "   Request method: #{request.method}"
    Rails.logger.info "   Request path: #{request.path}"
    Rails.logger.info "   Request format: #{request.format}"
    Rails.logger.info "   Accept header: #{request.headers['Accept']}"
    Rails.logger.info "   Request IP: #{request.remote_ip}"
    Rails.logger.info "   User-Agent: #{request.user_agent}"
    Rails.logger.info "   All params: #{params.except(:controller, :action).inspect}"
    Rails.logger.info "   Code present: #{params[:code].present?}"
    Rails.logger.info "   Code length: #{params[:code]&.length || 0}"
    Rails.logger.info "   Code (first 30 chars): #{params[:code] ? params[:code][0..30] + '...' : 'nil'}"
    Rails.logger.info "   Code (last 10 chars): #{params[:code] && params[:code].length > 10 ? '...' + params[:code][-10..-1] : params[:code]}"
    Rails.logger.info "=" * 80
    
    code = params[:code]
    
    unless code.present?
      Rails.logger.warn "⚠️ [GoogleOAuth] No code provided in retrieve_oauth_data"
      Rails.logger.warn "   All params keys: #{params.keys.inspect}"
      render json: { success: false, error: 'Authorization code is required' }, status: :bad_request
      return
    end
    
    # Analyze code format
    code_length = code.length
    is_hex_format = code.match?(/\A[0-9a-f]+\z/i)
    Rails.logger.info "🔍 [GoogleOAuth] Code analysis:"
    Rails.logger.info "   Length: #{code_length}"
    Rails.logger.info "   Format: #{is_hex_format ? 'hex (likely our auth_code)' : 'not hex (likely Google code)'}"
    Rails.logger.info "   Expected auth_code length: 32 (SecureRandom.hex(16))"
    
    # First, try to retrieve from cache (this is the auth_code from callback handler)
    cache_key = "oauth_auth_#{code}"
    Rails.logger.info "🔍 [GoogleOAuth] Looking up cache key: #{cache_key}"
    Rails.logger.info "   Cache key length: #{cache_key.length}"
    cached_data = Rails.cache.read(cache_key)
    Rails.logger.info "   Cache read result: #{cached_data ? 'HIT (data present)' : 'MISS (no data)'}"
    
    if cached_data
      Rails.logger.info "✅ [GoogleOAuth] Cache hit, retrieving auth data"
      Rails.logger.info "   Cached data length: #{cached_data.length} characters"
      Rails.logger.info "   Cached data (first 100 chars): #{cached_data[0..100]}..."
      
      begin
        auth_data = JSON.parse(cached_data)
        
        Rails.logger.info "✅ [GoogleOAuth] Auth data parsed successfully"
        Rails.logger.info "   Auth data keys: #{auth_data.keys.inspect}"
        Rails.logger.info "   Has token: #{auth_data['token'].present?}"
        Rails.logger.info "   Token length: #{auth_data['token']&.length || 0}"
        Rails.logger.info "   Has user: #{auth_data['user'].present?}"
        Rails.logger.info "   User keys: #{auth_data['user']&.keys&.inspect}"
        Rails.logger.info "   User email: #{auth_data['user']&.dig('email')}"
        Rails.logger.info "   User role: #{auth_data['user']&.dig('role')}"
        Rails.logger.info "   User ID: #{auth_data['user']&.dig('id')}"
        
        # Delete from cache after retrieval (one-time use)
        Rails.cache.delete(cache_key)
        Rails.logger.info "🗑️ [GoogleOAuth] Deleted cache key (one-time use)"
        
        Rails.logger.info "✅ [GoogleOAuth] Returning success response"
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
        Rails.logger.error "   Cached data: #{cached_data.inspect}"
        render json: { success: false, error: 'Invalid auth data format' }, status: :internal_server_error
        return
      end
    end
    
    # Cache miss - check if this is our auth_code format or a Google authorization code
    # Our auth_codes are 32 hex characters (SecureRandom.hex(16))
    # Google authorization codes are typically longer and have a different format
    is_our_auth_code = code.length == 32 && code.match?(/\A[0-9a-f]+\z/i)
    
    Rails.logger.info "🔍 [GoogleOAuth] Cache miss analysis:"
    Rails.logger.info "   Code length: #{code.length}"
    Rails.logger.info "   Is hex format: #{code.match?(/\A[0-9a-f]+\z/i)}"
    Rails.logger.info "   Is our auth_code format (32 hex chars): #{is_our_auth_code}"
    
    if is_our_auth_code
      # This is our auth_code format, but it's not in cache (expired or invalid)
      Rails.logger.warn "⚠️ [GoogleOAuth] Auth code not found in cache (may have expired)"
      Rails.logger.warn "   Code: #{code[0..10]}..."
      Rails.logger.warn "   Cache key tried: #{cache_key}"
      Rails.logger.warn "   Possible reasons:"
      Rails.logger.warn "   1. Code expired (cache TTL: 5 minutes)"
      Rails.logger.warn "   2. Code already used (one-time use)"
      Rails.logger.warn "   3. Code never stored (callback handler didn't run)"
      Rails.logger.warn "   4. Cache backend issue"
      
      # Check if there are any similar keys in cache (for debugging)
      Rails.logger.info "🔍 [GoogleOAuth] Checking for similar cache keys..."
      # Note: Rails.cache doesn't support listing keys, so we can't check this
      
      render json: { success: false, error: 'Invalid or expired authorization code' }, status: :not_found
      return
    end
    
    # This appears to be a Google authorization code - check if already processed
    processed_cache_key = "oauth_code_#{Digest::MD5.hexdigest(code)}"
    Rails.logger.info "🔍 [GoogleOAuth] Checking if code already processed"
    Rails.logger.info "   Processed cache key: #{processed_cache_key}"
    already_processed = Rails.cache.exist?(processed_cache_key)
    Rails.logger.info "   Already processed: #{already_processed}"
    
    if already_processed
      Rails.logger.warn "⚠️ [GoogleOAuth] Google code already processed"
      Rails.logger.warn "   Code: #{code[0..20]}..."
      Rails.logger.warn "   This code was already used to authenticate"
      render json: { success: false, error: 'This authorization code has already been used' }, status: :bad_request
      return
    end
    
    # Try to process it as a Google authorization code
    # This handles the case where the frontend receives the Google code directly
    Rails.logger.info "=" * 80
    Rails.logger.info "🔄 [GoogleOAuth] Cache miss - attempting to process as Google authorization code"
    Rails.logger.info "   Code length: #{code.length}"
    Rails.logger.info "   Code format: #{is_our_auth_code ? 'our_auth_code' : 'google_code'}"
    Rails.logger.info "   Code (first 50 chars): #{code[0..50]}..."
    Rails.logger.info "=" * 80
    
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
      
      Rails.logger.info "🔄 [GoogleOAuth] Trying token exchange with redirect_uris: #{redirect_uris_to_try.inspect}"
      
      redirect_uris_to_try.each do |uri|
        Rails.logger.info "🔄 [GoogleOAuth] Attempting exchange with redirect_uri: #{uri}"
        Rails.logger.info "   Code (first 20 chars): #{code[0..20]}..."
        token_response = exchange_code_for_tokens_with_redirect_uri(code, uri)
        if token_response && token_response['access_token']
          Rails.logger.info "✅ [GoogleOAuth] Token exchange successful with redirect_uri: #{uri}"
          break
        else
          Rails.logger.warn "⚠️ [GoogleOAuth] Token exchange failed with redirect_uri: #{uri}"
        end
      end
      
      # Check if token exchange succeeded
      unless token_response && token_response['access_token']
        Rails.logger.error "❌ [GoogleOAuth] Failed to exchange code for tokens with any redirect_uri"
        Rails.logger.error "   Code length: #{code.length}"
        Rails.logger.error "   Code format: #{code.match?(/\A[0-9a-f]+\z/i) ? 'hex (likely our auth_code)' : 'not hex (likely Google code)'}"
        Rails.logger.error "   Tried redirect_uris: #{redirect_uris_to_try.inspect}"
        Rails.logger.error "   This usually means:"
        Rails.logger.error "   1. The code has already been used (Google codes are single-use)"
        Rails.logger.error "   2. The code has expired (Google codes expire quickly)"
        Rails.logger.error "   3. The code doesn't match any configured redirect_uri"
        Rails.logger.error "   4. The code is actually our auth_code but cache expired"
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
      linking_service = OauthAccountLinkingService.new(auth_hash, role.capitalize, user_ip)
      result = linking_service.call
      
      unless result[:success] && result[:user]
        Rails.logger.error "❌ [GoogleOAuth] OAuth account linking failed: #{result[:error]}"
        render json: { success: false, error: result[:error] || 'Failed to create or link account' }, status: :unprocessable_entity
        return
      end
      
      user = result[:user]
      user_role = determine_role(user)
      
      # Block login if the user is soft-deleted or blocked
      if (user.is_a?(Buyer) || user.is_a?(Seller)) && (user.deleted? || user.blocked?)
        error_msg = user.deleted? ? 'Your account has been deleted. Please contact support.' : 'Your account has been blocked. Please contact support.'
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
      
      # Update last active timestamp
      if user.respond_to?(:update_last_active!)
        user.update_last_active!
      end
      
      # Mark code as processed
      Rails.cache.write(processed_cache_key, true, expires_in: 5.minutes)
      
      Rails.logger.info "✅ [GoogleOAuth] Successfully processed Google authorization code"
      
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
      Rails.logger.info "📝 Complete registration request received"
      
      # Get the form data from the request
      form_data = params.permit(:fullname, :email, :phone_number, :location, :city, :age_group, :gender, :username, :profile_picture, :county_id, :sub_county_id, :age_group_id, :birthday, :given_name, :family_name, :display_name, :provider, :uid, :user_type, :enterprise_name, :business_registration_number, :document_type_id, :description)
      
      Rails.logger.info "📝 Form data: #{form_data.inspect}"
      
      # Determine user type (default to buyer if not specified)
      user_type = form_data[:user_type] || 'Buyer'
      Rails.logger.info "📝 User type: #{user_type}"
      
      # Find the user by email (assuming email is provided)
      user = case user_type
             when 'seller'
               Seller.find_by(email: form_data[:email])
             else
               Buyer.find_by(email: form_data[:email])
             end
      
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
                Rails.logger.info "✅ Premium tier assigned to OAuth seller (complete_registration): #{user.email}, expires #{expiry_date}"
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
          end
        else
          render json: {
            success: false,
            error: "Failed to create user: #{user.errors.full_messages.join(', ')}"
          }, status: :unprocessable_entity
          return
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
                Rails.logger.info "✅ Premium tier assigned to OAuth seller (existing user, complete_registration): #{user.email}"
              end
            elsif should_get_2026_premium?
              create_2026_premium_tier(user)
            end
          end
        else
          render json: {
            success: false,
            error: "Failed to complete registration: #{user.errors.full_messages.join(', ')}"
          }, status: :unprocessable_entity
          return
        end
      end
      
      # Check if user is deleted or blocked before generating token
      if (user.is_a?(Buyer) || user.is_a?(Seller)) && user.deleted?
        render json: {
          success: false,
          error: 'Your account has been deleted. Please contact support.'
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
      token_payload = {
        email: user.email,
        role: user_type == 'seller' ? 'Seller' : 'Buyer',
        remember_me: true
      }
      
      # Add appropriate ID field based on user type
      if user_type == 'seller'
        token_payload[:seller_id] = user.id
      else
        token_payload[:user_id] = user.id
      end
      
      token = JsonWebToken.encode(token_payload)
      
      # Send welcome email
      begin
        WelcomeMailer.welcome_email(user).deliver_now
      rescue => e
        # Don't fail the registration if email fails
      end
      
      # Reload user to get the latest phone_number after update
      user.reload
      
      # Send welcome WhatsApp message only in these scenarios:
      # 1. Google OAuth WITHOUT phone: phone_provided_by_oauth = false, phone was just added
      # 2. Manual registration WITHOUT phone: phone_provided_by_oauth = false, phone was just added
      # 
      # Do NOT send if:
      # - Google OAuth WITH phone: phone_provided_by_oauth = true (already sent during OAuth)
      # - Manual registration WITH phone: phone already existed (already sent during registration)
      # - Phone was not just added in this request
      
      should_send_welcome = false
      
      if user.phone_number.present? && !user.phone_provided_by_oauth
        # Check if phone was just added in this request
        # For new users created in complete_registration, phone is always "just added" if present
        # For existing users, check if phone_being_added flag is set
        phone_was_just_added = defined?(phone_being_added) ? phone_being_added : true
        
        if phone_was_just_added
          should_send_welcome = true
          Rails.logger.info "📱 Will send welcome message - phone was just added, phone_provided_by_oauth: false"
        else
          Rails.logger.info "📱 Skipping welcome message - phone already existed before this update"
        end
      else
        if user.phone_provided_by_oauth
          Rails.logger.info "📱 Skipping welcome message - phone was provided by OAuth (already sent during OAuth)"
        elsif !user.phone_number.present?
          Rails.logger.info "📱 Skipping welcome message - no phone number present"
        end
      end
      
      if should_send_welcome
        Rails.logger.info "📱 Sending welcome WhatsApp message - phone number: #{user.phone_number}"
        begin
          WhatsAppNotificationService.send_welcome_message(user)
        rescue => e
          Rails.logger.error "Failed to send welcome WhatsApp message: #{e.message}"
          Rails.logger.error e.backtrace.first(5).join("\n")
          # Don't fail registration if WhatsApp message fails
        end
      end
      
      # Prepare user response data
      user_response = {
        id: user.id,
        email: user.email,
        fullname: user.fullname,
        username: user.username,
        role: user.user_type,
        profile_picture: user.profile_picture
      }
      
      # Add seller-specific fields if applicable
      if user_type == 'seller'
        user_response[:enterprise_name] = user.enterprise_name if user.respond_to?(:enterprise_name)
        user_response[:business_registration_number] = user.business_registration_number if user.respond_to?(:business_registration_number)
      end
      
      render json: {
        success: true,
        message: "Registration completed successfully",
        token: token,
        user: user_response
      }
      
    rescue => e
      render json: {
        success: false,
        error: "Failed to complete registration: #{e.message}"
      }, status: :internal_server_error
    end
  end

  private
  
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

  # Check if user should get premium status for 2025 registrations
  def should_get_2026_premium?
    current_year = Time.current.year
    Rails.logger.info "🔍 Checking 2026 premium status: current_year=#{current_year}, is_2026=#{current_year == 2026}"
    current_year == 2026
  end

  # Get premium tier for 2025 users
  def get_premium_tier
    Tier.find_by(name: 'Premium')
  end

  # Create seller tier for 2026 premium users
  def create_2026_premium_tier(seller)
    Rails.logger.info "🔍 create_2026_premium_tier called for seller: #{seller.email}"
    
    unless should_get_2026_premium?
      Rails.logger.info "❌ Not 2025, skipping premium tier assignment"
      return
    end
    
    premium_tier = get_premium_tier
    unless premium_tier
      Rails.logger.error "❌ Premium tier not found in database"
      return
    end
    
    Rails.logger.info "✅ Premium tier found: #{premium_tier.name} (ID: #{premium_tier.id})"
    
    # Calculate expiry date (end of 2026) - expires at midnight on January 1, 2027
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
    
    Rails.logger.info "✅ Premium tier assigned to seller #{seller.email} until end of 2026 (#{remaining_days} days, ~#{duration_months} months, SellerTier ID: #{seller_tier.id})"
  rescue => e
    Rails.logger.error "❌ Error creating premium tier: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def assign_free_tier(seller)
    default_tier = Tier.find_by(name: 'Free') || Tier.first
    if default_tier
      seller.seller_tier = SellerTier.create!(
        seller: seller,
        tier: default_tier,
        duration_months: 0 # Free tier has no expiration
      )
      Rails.logger.info "✅ Default tier assigned to seller: #{default_tier.name}"
    end
  end

  def find_user_by_email(email)
    # Only search by email
    Buyer.find_by(email: email) ||
    Seller.find_by(email: email) ||
    Admin.find_by(email: email) ||
    SalesUser.find_by(email: email) ||
    MarketingUser.find_by(email: email)
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
    
    Rails.logger.info "🔍 Missing fields for seller #{seller.id}: #{missing_fields.join(', ')}"
    missing_fields
  end

end
