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

    # Generate new token with remember_me flag and appropriate expiration
    token_payload = if role == 'seller'
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

    render json: { user: user_response }, status: :ok
  end

  def google_oauth
    puts "🚨 GOOGLE OAUTH METHOD CALLED!"
    Rails.logger.info "🚨 GOOGLE OAUTH METHOD CALLED!"
    
    auth_code = params[:code]
    redirect_uri = params[:redirect_uri] || ENV['GOOGLE_REDIRECT_URI'] || "#{request.base_url}/auth/google_oauth2/callback"
    location_data = params[:location_data] # Get location data from frontend
    
    puts "🔍 Google OAuth Request Debug:"
    Rails.logger.info "🔍 Google OAuth Request Debug:"
    puts "📝 Auth code: #{auth_code ? auth_code[0..10] + '...' : 'nil'}"
    Rails.logger.info "📝 Auth code: #{auth_code ? auth_code[0..10] + '...' : 'nil'}"
    puts "🔗 Redirect URI: #{redirect_uri}"
    Rails.logger.info "🔗 Redirect URI: #{redirect_uri}"
    puts "🌍 Location data from frontend: #{location_data.inspect}"
    Rails.logger.info "🌍 Location data from frontend: #{location_data.inspect}"
    
    unless auth_code
      Rails.logger.error "❌ No authorization code provided"
      render json: { errors: ['Authorization code is required'] }, status: :bad_request
      return
    end

    begin
      Rails.logger.info "🔄 Creating Google OAuth service..."
      user_ip = request.remote_ip
      Rails.logger.info "🌐 User IP: #{user_ip}"
      oauth_service = GoogleOauthService.new(auth_code, redirect_uri, user_ip)
      
      Rails.logger.info "🔄 Calling authenticate method..."
      result = oauth_service.authenticate
      
      Rails.logger.info "🔄 OAuth service result: #{result.inspect}"

      # Check if result is a hash with missing fields
      if result.is_a?(Hash) && result[:missing_fields] && result[:user_data]
        Rails.logger.info "📝 Missing fields detected from hash: #{result[:missing_fields]}"
        render json: {
          success: false,
          error: result[:error],
          missing_fields: result[:missing_fields],
          user_data: result[:user_data]
        }, status: :unprocessable_entity
        return
      end

      # Check if result is a Buyer object with missing fields
      if result.is_a?(Buyer) && result.respond_to?(:missing_fields) && result.missing_fields.any?
        Rails.logger.info "📝 Missing fields detected from Buyer object: #{result.missing_fields}"
        render json: {
          success: false,
          error: "Missing required fields: #{result.missing_fields.join(', ')}",
          missing_fields: result.missing_fields,
          user_data: result.user_data_for_modal
        }, status: :unprocessable_entity
        return
      end

      # Handle the OAuth service result
      if result[:success]
        if result[:existing_user]
          Rails.logger.info "✅ Existing user logged in successfully"
          render json: {
            success: true,
            message: "User logged in successfully",
            token: result[:token],
            user: result[:user],
            existing_user: true
          }
        elsif result[:new_user]
          Rails.logger.info "✅ New user registered and logged in successfully"
          render json: {
            success: true,
            message: "User registered and logged in successfully",
            token: result[:token],
            user: result[:user],
            new_user: true
          }
        else
          Rails.logger.info "📊 Google OAuth data logged successfully"
          render json: {
            success: true,
            message: "Google OAuth data logged successfully",
            data_logged: true,
            token: "data-logging-mode",
            user: {
              id: "data-logging",
              email: "data-logging@example.com",
              name: "Data Logging Mode",
              role: "data-logging"
            }
          }
        end
      else
        Rails.logger.error "❌ Google OAuth failed: #{result[:error]}"
        
        # Check if this is a missing fields error
        if result[:missing_fields] && result[:user_data]
          Rails.logger.info "📝 Missing fields detected, returning modal data"
          Rails.logger.info "📝 Missing fields: #{result[:missing_fields]}"
          Rails.logger.info "📝 User data: #{result[:user_data]}"
          render json: {
            success: false,
            error: result[:error],
            missing_fields: result[:missing_fields],
            user_data: result[:user_data]
          }, status: :unprocessable_entity
        else
          render json: { 
            success: false, 
            error: result[:error] 
          }, status: :unprocessable_entity
        end
      end
    rescue => e
      Rails.logger.error "❌ Google OAuth error: #{e.message}"
      render json: { error: "Authentication failed: #{e.message}" }, status: :internal_server_error
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
      user_ip = request.remote_ip
      Rails.logger.info "🌐 User IP: #{user_ip}"
      oauth_service = GoogleOauthService.new(code, redirect_uri, user_ip)
      result = oauth_service.authenticate
      
      if result[:success]
        Rails.logger.info "🔍 OAuth result: #{result.inspect}"
        
        # Check if this is data logging mode (no user creation)
        if result[:data_logged] && result[:user].nil?
          Rails.logger.info "📊 Data logging mode - no user created, redirecting to frontend"
          redirect_url = "#{frontend_url}/auth/google/callback?data_logged=true"
          redirect_to redirect_url, allow_other_host: true
          return
        end
        
        user = result[:user]
        
        # Safety check - if user is nil, return error
        if user.nil?
          Rails.logger.error "❌ User is nil in OAuth result"
          redirect_url = "#{frontend_url}/auth/google/callback?error=#{CGI.escape('User creation failed')}"
          redirect_to redirect_url, allow_other_host: true
          return
        end
        
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
        
        # Include comprehensive Google OAuth data if available
        if user.respond_to?(:phone_number) && user.phone_number.present?
          user_response[:phone_number] = user.phone_number
        end
        
        if user.respond_to?(:gender) && user.gender.present?
          user_response[:gender] = user.gender
        end
        
        if user.respond_to?(:location) && user.location.present?
          user_response[:location] = user.location
        end
        
        if user.respond_to?(:city) && user.city.present?
          user_response[:city] = user.city
        end
        
        if user.respond_to?(:zipcode) && user.zipcode.present?
          user_response[:zipcode] = user.zipcode
        end
        
        if user.respond_to?(:age_group_id) && user.age_group_id.present?
          user_response[:age_group_id] = user.age_group_id
        end
        
        if user.respond_to?(:description) && user.description.present?
          user_response[:biography] = user.description
        end

        # Create token with appropriate ID field - Google OAuth users get remember_me by default
        token_payload = if role == 'seller'
          { seller_id: user.id, email: user.email, role: role, remember_me: true }
        else
          { user_id: user.id, email: user.email, role: role, remember_me: true }
        end
        
        # Use JsonWebToken.encode which now respects remember_me flag (30 days for Google OAuth)
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
      user_ip = request.remote_ip
      Rails.logger.info "🌐 User IP: #{user_ip}"
      oauth_service = GoogleOauthService.new(code, redirect_uri, user_ip)
      result = oauth_service.authenticate
      
      if result[:success]
        Rails.logger.info "🔍 OAuth result: #{result.inspect}"
        
        # Simple data logging mode - always return success
        Rails.logger.info "📊 Data logging mode - returning success response"
        render json: {
          success: true,
          message: "Google OAuth data logged successfully",
          data_logged: true,
          token: nil,
          user: nil
        }
        return
        
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
        
        # Include comprehensive Google OAuth data if available
        if user.respond_to?(:phone_number) && user.phone_number.present?
          user_response[:phone_number] = user.phone_number
        end
        
        if user.respond_to?(:gender) && user.gender.present?
          user_response[:gender] = user.gender
        end
        
        if user.respond_to?(:location) && user.location.present?
          user_response[:location] = user.location
        end
        
        if user.respond_to?(:city) && user.city.present?
          user_response[:city] = user.city
        end
        
        if user.respond_to?(:zipcode) && user.zipcode.present?
          user_response[:zipcode] = user.zipcode
        end
        
        if user.respond_to?(:age_group_id) && user.age_group_id.present?
          user_response[:age_group_id] = user.age_group_id
        end
        
        if user.respond_to?(:description) && user.description.present?
          user_response[:biography] = user.description
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

  # Complete registration with missing fields
  def complete_registration
    begin
      puts "📝 Complete registration request received"
      
      # Get the form data from the request
      form_data = params.permit(:fullname, :email, :phone_number, :location, :city, :age_group, :gender, :username, :profile_picture, :county_id, :sub_county_id)
      
      puts "📝 Form data: #{form_data.inspect}"
      
      # Find the user by email (assuming email is provided)
      user = Buyer.find_by(email: form_data[:email])
      
      if user.nil?
        puts "📝 User not found, creating new user with provided data"
        
        # Check if phone number already exists for another user
        if form_data[:phone_number].present?
          existing_user_with_phone = Buyer.find_by(phone_number: form_data[:phone_number])
          if existing_user_with_phone
            puts "❌ Phone number already exists for another user: #{form_data[:phone_number]}"
            render json: {
              success: false,
              error: "Phone number #{form_data[:phone_number]} is already registered to another account. Please use a different phone number."
            }, status: :unprocessable_entity
            return
          end
        end
        
        # Create new user with the provided data
        user_attributes = {}
        
        # Map form data to user attributes
        user_attributes[:fullname] = form_data[:fullname] if form_data[:fullname].present?
        user_attributes[:phone_number] = form_data[:phone_number] if form_data[:phone_number].present?
        user_attributes[:location] = form_data[:location] if form_data[:location].present?
        user_attributes[:city] = form_data[:city] if form_data[:city].present?
        user_attributes[:gender] = form_data[:gender] if form_data[:gender].present?
        user_attributes[:username] = form_data[:username] if form_data[:username].present?
        user_attributes[:email] = form_data[:email] if form_data[:email].present?
        user_attributes[:profile_picture] = form_data[:profile_picture] if form_data[:profile_picture].present?
        user_attributes[:county_id] = form_data[:county_id] if form_data[:county_id].present?
        user_attributes[:sub_county_id] = form_data[:sub_county_id] if form_data[:sub_county_id].present?
        
        # Handle age group
        if form_data[:age_group].present?
          age_group = AgeGroup.find_by(name: form_data[:age_group])
          if age_group
            user_attributes[:age_group_id] = age_group.id
          end
        end
        
        # Create the user as OAuth user (no password required)
        user_attributes[:provider] = 'google' # Mark as OAuth user
        user_attributes[:uid] = SecureRandom.hex(16) # Generate a random UID for OAuth users
        
        user = Buyer.new(user_attributes)
        
        if user.save
          puts "✅ User created successfully: #{user.email}"
        else
          puts "❌ Failed to create user: #{user.errors.full_messages.join(', ')}"
          render json: {
            success: false,
            error: "Failed to create user: #{user.errors.full_messages.join(', ')}"
          }, status: :unprocessable_entity
          return
        end
      else
        puts "📝 User found, updating with provided data"
        
        # Check if phone number already exists for another user (excluding current user)
        if form_data[:phone_number].present?
          existing_user_with_phone = Buyer.find_by(phone_number: form_data[:phone_number])
          if existing_user_with_phone && existing_user_with_phone.id != user.id
            puts "❌ Phone number already exists for another user: #{form_data[:phone_number]}"
            render json: {
              success: false,
              error: "Phone number #{form_data[:phone_number]} is already registered to another account. Please use a different phone number."
            }, status: :unprocessable_entity
            return
          end
        end
        
        # Update existing user with the provided data
        user_attributes = {}
        
        # Map form data to user attributes
        user_attributes[:fullname] = form_data[:fullname] if form_data[:fullname].present?
        user_attributes[:phone_number] = form_data[:phone_number] if form_data[:phone_number].present?
        user_attributes[:location] = form_data[:location] if form_data[:location].present?
        user_attributes[:city] = form_data[:city] if form_data[:city].present?
        user_attributes[:gender] = form_data[:gender] if form_data[:gender].present?
        user_attributes[:username] = form_data[:username] if form_data[:username].present?
        user_attributes[:profile_picture] = form_data[:profile_picture] if form_data[:profile_picture].present?
        user_attributes[:county_id] = form_data[:county_id] if form_data[:county_id].present?
        user_attributes[:sub_county_id] = form_data[:sub_county_id] if form_data[:sub_county_id].present?
        
        # Handle age group
        if form_data[:age_group].present?
          age_group = AgeGroup.find_by(name: form_data[:age_group])
          if age_group
            user_attributes[:age_group_id] = age_group.id
          end
        end
        
        # Update the user
        puts "🔄 Updating user with attributes: #{user_attributes.inspect}"
        if user.update(user_attributes)
          puts "✅ User updated successfully: #{user.email}"
        else
          puts "❌ Failed to update user: #{user.errors.full_messages.join(', ')}"
          render json: {
            success: false,
            error: "Failed to complete registration: #{user.errors.full_messages.join(', ')}"
          }, status: :unprocessable_entity
          return
        end
      end
      
      # Generate JWT token using JsonWebToken service
      token_payload = {
        user_id: user.id,
        email: user.email,
        role: 'buyer',
        remember_me: true
      }
      
      token = JsonWebToken.encode(token_payload)
      
      # Send welcome email
      begin
        WelcomeMailer.welcome_email(user).deliver_now
        puts "✅ Welcome email sent to: #{user.email}"
      rescue => e
        puts "❌ Failed to send welcome email: #{e.message}"
        # Don't fail the registration if email fails
      end
      
      render json: {
        success: true,
        message: "Registration completed successfully",
        token: token,
        user: {
          id: user.id,
          email: user.email,
          fullname: user.fullname,
          username: user.username,
          role: user.user_type,
          profile_picture: user.profile_picture
        }
      }
      
    rescue => e
      puts "❌ Error completing registration: #{e.message}"
      puts "❌ Backtrace: #{e.backtrace.first(5).join('\n')}"
      render json: {
        success: false,
        error: "Failed to complete registration: #{e.message}"
      }, status: :internal_server_error
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
    
    # Extract the best available name from Google
    fullname = extract_best_name_from_google(user_info)
    
    user_attributes = {
      email: email,
      fullname: fullname,
      username: generate_unique_username(fullname),
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

  # Extract the best available name from Google user info
  # Note: Google OAuth does not provide a separate "username" field
  # We use the actual name fields provided by Google
  def extract_best_name_from_google(user_info)
    # Try different name fields in order of preference
    name = user_info[:name] || 
           user_info[:display_name] || 
           user_info[:given_name] || 
           user_info[:full_name]
    
    # If we have a name, return it
    return name if name.present? && name.strip.length > 0
    
    # If no name is available, return nil to indicate missing data
    # This will be handled by the frontend as missing data
    Rails.logger.warn "⚠️ No name found in Google user info for email: #{user_info[:email]}"
    Rails.logger.warn "⚠️ Note: Google OAuth does not provide a separate username field"
    nil
  end

  # Generate username from the actual name provided by Google
  # Note: We do NOT extract from email - we use the real name from Google OAuth
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

  def complete_oauth_registration
    begin
      # Check if this is a new user creation with missing fields
      if params[:missing_fields].present?
        # Create new user with provided data
        user_attributes = {
          fullname: params[:fullname],
          email: params[:email],
          username: params[:username] || generate_username(params[:email]),
          phone_number: params[:phone_number],
          gender: params[:gender] || 'Other',
          city: params[:city],
          location: params[:location],
          profile_picture: params[:profile_picture],
          provider: 'google',
          uid: params[:uid],
          age_group_id: params[:age_group_id] || 1,
          county_id: params[:county_id] || 1,
          sub_county_id: params[:sub_county_id] || 1
        }

        # Create the buyer
        user = Buyer.new(user_attributes)
        
        if user.save
          puts "✅ Buyer created successfully with missing fields: #{user.email}"
          Rails.logger.info "✅ Buyer created successfully with missing fields: #{user.email}"
        else
          puts "❌ Failed to create buyer: #{user.errors.full_messages.join(', ')}"
          Rails.logger.error "❌ Failed to create buyer: #{user.errors.full_messages.join(', ')}"
          
          render json: { 
            success: false, 
            error: "Failed to create user: #{user.errors.full_messages.join(', ')}" 
          }, status: :unprocessable_entity
          return
        end
      else
        # Legacy flow - update existing user
        user_id = params[:user_id]
        user = Buyer.find(user_id)
        
        # Validate required fields
        required_fields = [:phone_number, :gender, :age_group_id]
        missing_fields = required_fields.select { |field| params[field].blank? }
        
        if missing_fields.any?
          render json: { 
            success: false, 
            message: "Missing required fields: #{missing_fields.join(', ')}" 
          }, status: :bad_request
          return
        end

        # Update user with provided information
        update_attributes = {
          phone_number: params[:phone_number],
          gender: params[:gender],
          age_group_id: params[:age_group_id]
        }

        # Add optional fields if provided
        update_attributes[:location] = params[:location] if params[:location].present?
        update_attributes[:city] = params[:city] if params[:city].present?
        update_attributes[:zipcode] = params[:zipcode] if params[:zipcode].present?
        update_attributes[:county_id] = params[:county_id] if params[:county_id].present?
        update_attributes[:sub_county_id] = params[:sub_county_id] if params[:sub_county_id].present?

        user.update!(update_attributes)
      end

      # Generate new token with complete user data
      token_payload = {
        user_id: user.id,
        email: user.email,
        role: 'buyer',
        remember_me: true
      }
      
      token = JsonWebToken.encode(token_payload)
      
      # Prepare user response
      user_response = {
        id: user.id,
        email: user.email,
        role: 'buyer',
        name: user.fullname || user.username,
        username: user.username,
        profile_picture: user.profile_picture
      }

      render json: { 
        success: true, 
        token: token, 
        user: user_response 
      }, status: :ok

    rescue ActiveRecord::RecordNotFound
      render json: { 
        success: false, 
        message: 'User not found' 
      }, status: :not_found
    rescue ActiveRecord::RecordInvalid => e
      render json: { 
        success: false, 
        message: e.record.errors.full_messages.join(', ') 
      }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "Error completing OAuth registration: #{e.message}"
      render json: { 
        success: false, 
        message: 'Failed to complete registration' 
      }, status: :internal_server_error
    end
  end

end
