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
    
    # Production debugging
    Rails.logger.info "🔍 Google OAuth Request Debug:"
    Rails.logger.info "📝 Auth code: #{auth_code ? auth_code[0..10] + '...' : 'nil'}"
    Rails.logger.info "🔗 Redirect URI: #{redirect_uri}"
    Rails.logger.info "🌐 Request origin: #{request.origin}"
    Rails.logger.info "🌐 Request host: #{request.host}"
    Rails.logger.info "🔑 GOOGLE_CLIENT_ID: #{ENV['GOOGLE_CLIENT_ID'] ? 'Set' : 'Missing'}"
    Rails.logger.info "🔐 GOOGLE_CLIENT_SECRET: #{ENV['GOOGLE_CLIENT_SECRET'] ? 'Set' : 'Missing'}"
    
    unless auth_code
      Rails.logger.error "❌ No authorization code provided"
      render json: { errors: ['Authorization code is required'] }, status: :bad_request
      return
    end

    # For GSI popup authentication, use 'postmessage' as redirect_uri
    if redirect_uri == 'postmessage'
      redirect_uri = 'postmessage'
    end

    begin
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
      render json: { errors: [result[:error] || 'Authentication failed'] }, status: :unauthorized
    end
    rescue => e
      Rails.logger.error "❌ Google OAuth controller error: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.join("\n")}"
      render json: { errors: ['Internal server error during authentication'] }, status: :internal_server_error
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

  def google_oauth_popup_callback
    # Handle popup-based OAuth callback
    code = params[:code]
    state = params[:state]
    error = params[:error]
    
    if error
      # Handle OAuth error - send error message to parent window
      render html: "<script>
        if (window.opener) {
          window.opener.postMessage({
            type: 'GOOGLE_AUTH_ERROR',
            error: '#{error}'
          }, '*');
        }
        window.close();
      </script>".html_safe
      return
    end
    
    unless code
      # No code received
      render html: "<script>
        if (window.opener) {
          window.opener.postMessage({
            type: 'GOOGLE_AUTH_ERROR',
            error: 'No authorization code received'
          }, '*');
        }
        window.close();
      </script>".html_safe
      return
    end
    
    # Process the OAuth code
    begin
      redirect_uri = ENV['GOOGLE_REDIRECT_URI'] || "#{request.base_url}/auth/google_oauth2/popup_callback"
      oauth_service = GoogleOauthService.new(code, redirect_uri)
      result = oauth_service.authenticate
      
      if result[:success]
        user = result[:user]
        role = determine_role(user)
        
        # Block login if the user is soft-deleted
        if (user.is_a?(Buyer) || user.is_a?(Seller)) && user.deleted?
          render html: "<script>
            if (window.opener) {
              window.opener.postMessage({
                type: 'GOOGLE_AUTH_ERROR',
                error: 'Your account has been deleted. Please contact support.'
              }, '*');
            }
            window.close();
          </script>".html_safe
          return
        end

        # 🚫 Pilot restriction for sellers outside Nairobi (only if pilot phase is enabled)
        if ENV['PILOT_PHASE_ENABLED'] == 'true' && role == 'seller' && user.county&.county_code.to_i != 47
          render html: "<script>
            if (window.opener) {
              window.opener.postMessage({
                type: 'GOOGLE_AUTH_ERROR',
                error: 'Access restricted during pilot phase. Only Nairobi-based sellers can log in.'
              }, '*');
            }
            window.close();
          </script>".html_safe
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
        
        # Send success message to parent window
        render html: "<script>
          if (window.opener) {
            window.opener.postMessage({
              type: 'GOOGLE_AUTH_SUCCESS',
              token: '#{token}',
              user: #{user_response.to_json}
            }, '*');
          }
          window.close();
        </script>".html_safe
      else
        # Authentication failed
        render html: "<script>
          if (window.opener) {
            window.opener.postMessage({
              type: 'GOOGLE_AUTH_ERROR',
              error: '#{result[:error] || 'Authentication failed'}'
            }, '*');
          }
          window.close();
        </script>".html_safe
      end
    rescue => e
      Rails.logger.error "Google OAuth popup callback error: #{e.message}"
      render html: "<script>
        if (window.opener) {
          window.opener.postMessage({
            type: 'GOOGLE_AUTH_ERROR',
            error: 'Authentication failed'
          }, '*');
        }
        window.close();
      </script>".html_safe
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

    # Create new buyer by default with all required fields
    phone_number = extract_phone_number(user_info)
    
    user_attributes = {
      email: email,
      fullname: user_info[:name] || email.split('@').first,
      username: generate_unique_username(user_info[:name] || email.split('@').first),
      profile_picture: user_info[:picture],
      age_group_id: calculate_age_group(user_info),
      gender: extract_gender(user_info)
    }
    
    # Only add phone number if we have one from Google
    user_attributes[:phone_number] = phone_number if phone_number.present?
    
    Buyer.create!(user_attributes)
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

  def generate_unique_username(name)
    base_username = name.downcase.gsub(/[^a-z0-9]/, '').first(15)
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

  def extract_phone_number(user_info)
    # Google OAuth doesn't provide user's own phone number in basic profile
    # The phone number scope is for accessing user's contacts, not their own number
    # Return nil to indicate no phone number available
    nil
  end

  def extract_gender(user_info)
    # Get gender from Google profile
    gender = user_info[:gender]
    
    case gender&.downcase
    when 'male', 'm'
      'Male'
    when 'female', 'f'
      'Female'
    else
      'Male' # Default to Male if not specified or unrecognized
    end
  end

  def calculate_age_group(user_info)
    # Get birthday from Google profile
    birthday = user_info[:birthday] || user_info[:birth_date]
    
    if birthday.present?
      begin
        # Parse birthday (Google provides in YYYY-MM-DD format)
        birth_date = Date.parse(birthday)
        age = calculate_age(birth_date)
        
        # Map age to age group
        case age
        when 18..25
          AgeGroup.find_by(name: '18-25')&.id || 1
        when 26..35
          AgeGroup.find_by(name: '26-35')&.id || 2
        when 36..45
          AgeGroup.find_by(name: '36-45')&.id || 3
        when 46..55
          AgeGroup.find_by(name: '46-55')&.id || 4
        when 56..65
          AgeGroup.find_by(name: '56-65')&.id || 5
        else
          AgeGroup.find_by(name: '65+')&.id || 6
        end
      rescue => e
        Rails.logger.warn "Failed to parse birthday: #{birthday}, error: #{e.message}"
        # Default to first age group if parsing fails
        AgeGroup.first&.id || 1
      end
    else
      # No birthday provided, default to first age group
      AgeGroup.first&.id || 1
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
