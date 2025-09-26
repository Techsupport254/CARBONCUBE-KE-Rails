class ManualOauthController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def google_oauth2_initiate
    # Store the role in a way that can be passed to the OAuth flow
    role = params[:role] || 'buyer'
    
    # Redirect to Google OAuth manually
    google_oauth_url = "https://accounts.google.com/oauth/authorize?" +
      "client_id=#{ENV['GOOGLE_CLIENT_ID']}&" +
      "redirect_uri=#{ENV['GOOGLE_REDIRECT_URI'] || "#{ENV['REACT_APP_BACKEND_URL'] || 'http://localhost:3001'}/auth/google_oauth2/callback"}&" +
      "response_type=code&" +
      "scope=email%20profile%20openid%20https://www.googleapis.com/auth/user.birthday.read&" +
      "state=#{role}&" +
      "access_type=offline&" +
      "prompt=select_account"
    
    redirect_to google_oauth_url, allow_other_host: true
  end

  def google_oauth2_callback
    # Handle OAuth callback manually
    code = params[:code]
    state = params[:state] || 'buyer'
    
    if code.blank?
      render json: { error: 'Authorization code not received' }, status: :bad_request
      return
    end
    
    # Exchange code for access token
    token_response = exchange_code_for_token(code)
    
    if token_response[:error]
      render json: { error: token_response[:error] }, status: :unauthorized
      return
    end
    
    # Get user info from Google
    user_info = get_user_info_from_google(token_response[:access_token])
    
    if user_info[:error]
      render json: { error: user_info[:error] }, status: :unauthorized
      return
    end
    
    # Create auth hash similar to OmniAuth format
    auth_hash = {
      provider: 'google_oauth2',
      uid: user_info[:id],
      info: {
        email: user_info[:email],
        name: user_info[:name],
        first_name: user_info[:given_name],
        last_name: user_info[:family_name],
        image: user_info[:picture],
        verified_email: user_info[:verified_email]
      },
      credentials: {
        token: token_response[:access_token],
        refresh_token: token_response[:refresh_token],
        expires_at: token_response[:expires_in] ? Time.now + token_response[:expires_in].seconds : nil
      }
    }
    
    # Use the OAuth account linking service
    service = OauthAccountLinkingService.new(auth_hash, state)
    result = service.call

    if result[:success]
      user = result[:user]
      role = determine_role(user)
      
      # Generate JWT token
      token_payload = if role == 'seller'
        { seller_id: user.id, email: user.email, role: role, remember_me: true }
      else
        { user_id: user.id, email: user.email, role: role, remember_me: true }
      end
      
      token = JsonWebToken.encode(token_payload)
      user_response = build_user_response(user, role)
      
      # Redirect to frontend with token and user data
      frontend_url = "#{ENV['REACT_APP_FRONTEND_URL'] || 'http://localhost:3001'}/auth/google/callback"
      redirect_url = "#{frontend_url}?token=#{token}&user=#{CGI.escape(JSON.generate(user_response))}&message=#{CGI.escape(result[:message])}"
      
      redirect_to redirect_url, allow_other_host: true
    else
      # Redirect to frontend with error
      frontend_url = "#{ENV['REACT_APP_FRONTEND_URL'] || 'http://localhost:3001'}/auth/google/callback"
      redirect_url = "#{frontend_url}?error=#{CGI.escape(result[:error])}&error_type=#{result[:error_type]}"
      
      redirect_to redirect_url, allow_other_host: true
    end
  end

  def google_oauth2_failure
    render json: { error: 'Google authentication failed' }, status: :unauthorized
  end

  private

  def exchange_code_for_token(code)
    uri = URI('https://oauth2.googleapis.com/token')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    request.body = URI.encode_www_form({
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      code: code,
      grant_type: 'authorization_code',
      redirect_uri: ENV['GOOGLE_REDIRECT_URI'] || "#{ENV['REACT_APP_BACKEND_URL'] || 'http://localhost:3001'}/auth/google_oauth2/callback"
    })
    
    response = http.request(request)
    data = JSON.parse(response.body)
    
    if data['error']
      { error: data['error_description'] || data['error'] }
    else
      {
        access_token: data['access_token'],
        refresh_token: data['refresh_token'],
        expires_in: data['expires_in']
      }
    end
  rescue => e
    { error: "Token exchange failed: #{e.message}" }
  end

  def get_user_info_from_google(access_token)
    uri = URI('https://www.googleapis.com/oauth2/v2/userinfo')
    uri.query = URI.encode_www_form({ access_token: access_token })
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    response = http.request(request)
    data = JSON.parse(response.body)
    
    if data['error']
      { error: data['error']['message'] }
    else
      {
        id: data['id'],
        email: data['email'],
        name: data['name'],
        given_name: data['given_name'],
        family_name: data['family_name'],
        picture: data['picture'],
        verified_email: data['verified_email']
      }
    end
  rescue => e
    { error: "Failed to get user info: #{e.message}" }
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

  def build_user_response(user, role)
    response = {
      id: user.id,
      email: user.email,
      role: role
    }
    
    # Add name fields based on user type
    if user.respond_to?(:fullname) && user.fullname.present?
      response[:name] = user.fullname
    elsif user.respond_to?(:username) && user.username.present?
      response[:name] = user.username
    end
    
    # Always include username if available
    if user.respond_to?(:username) && user.username.present?
      response[:username] = user.username
    end
    
    # Add profile picture if available
    if user.respond_to?(:profile_picture) && user.profile_picture.present?
      response[:profile_picture] = user.profile_picture
    end
    
    response
  end
end
