# app/services/google_oauth_service.rb
class GoogleOauthService
  GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'
  GOOGLE_USER_INFO_URL = 'https://www.googleapis.com/oauth2/v2/userinfo'
  
  def initialize(auth_code, redirect_uri)
    @auth_code = auth_code
    @redirect_uri = redirect_uri
  end

  def authenticate
    # Step 1: Exchange authorization code for access token
    access_token = exchange_code_for_token
    
    return { success: false, error: 'Failed to get access token' } unless access_token
    
    # Step 2: Get user info from Google
    user_info = get_user_info(access_token)
    
    return { success: false, error: 'Failed to get user info' } unless user_info
    
    # Step 3: Find or create user
    user = find_or_create_user(user_info)
    
    return { success: false, error: 'Failed to create user' } unless user
    
    { success: true, user: user, access_token: access_token }
  end

  private

  def exchange_code_for_token
    response = HTTParty.post(GOOGLE_TOKEN_URL, {
      body: {
        client_id: ENV['GOOGLE_CLIENT_ID'],
        client_secret: ENV['GOOGLE_CLIENT_SECRET'],
        code: @auth_code,
        grant_type: 'authorization_code',
        redirect_uri: @redirect_uri
      },
      headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
    })
    
    return nil unless response.success?
    
    JSON.parse(response.body)['access_token']
  end

  def get_user_info(access_token)
    response = HTTParty.get(GOOGLE_USER_INFO_URL, {
      headers: { 'Authorization' => "Bearer #{access_token}" }
    })
    
    return nil unless response.success?
    
    JSON.parse(response.body)
  end

  def find_or_create_user(user_info)
    email = user_info['email']
    provider = 'google'
    uid = user_info['id']
    
    # First, try to find existing user by email
    existing_user = find_user_by_email(email)
    
    if existing_user
      # Link Google account to existing user
      link_oauth_to_existing_user(existing_user, provider, uid, user_info)
      return existing_user
    end
    
    # Check if user exists with this Google account
    oauth_user = find_user_by_oauth(provider, uid)
    return oauth_user if oauth_user
    
    # Create new user (we'll need to determine the user type)
    # For now, we'll create as buyer by default
    create_new_oauth_user(user_info, provider, uid)
  end

  def find_user_by_email(email)
    Buyer.find_by(email: email) ||
    Seller.find_by(email: email) ||
    Admin.find_by(email: email) ||
    SalesUser.find_by(email: email)
  end

  def find_user_by_oauth(provider, uid)
    Buyer.find_by(provider: provider, uid: uid) ||
    Seller.find_by(provider: provider, uid: uid) ||
    Admin.find_by(provider: provider, uid: uid) ||
    SalesUser.find_by(provider: provider, uid: uid)
  end

  def link_oauth_to_existing_user(user, provider, uid, user_info)
    # Only link if not already linked to this provider
    unless user.provider == provider && user.uid == uid
      user.update!(
        provider: provider,
        uid: uid,
        oauth_token: user_info['access_token'],
        oauth_expires_at: Time.current + 1.hour # Google tokens typically last 1 hour
      )
    end
  end

  def create_new_oauth_user(user_info, provider, uid)
    # For now, create as buyer by default
    # In a real implementation, you might want to ask the user to choose their role
    user = Buyer.create!(
      fullname: user_info['name'],
      email: user_info['email'],
      username: generate_unique_username(user_info['name']),
      provider: provider,
      uid: uid,
      oauth_token: user_info['access_token'],
      oauth_expires_at: Time.current + 1.hour,
      # Set required fields with defaults
      phone_number: generate_placeholder_phone,
      age_group_id: AgeGroup.first&.id || 1, # Default to first age group
      gender: 'Other', # Default gender
      password: SecureRandom.hex(16) # Random password for OAuth users
    )
    
    user
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create OAuth user: #{e.message}"
    nil
  end

  def generate_unique_username(name)
    base_username = name.downcase.gsub(/[^a-z0-9]/, '').first(15)
    username = base_username
    counter = 1
    
    while Buyer.exists?(username: username) || Seller.exists?(username: username) || 
          Admin.exists?(username: username) || SalesUser.exists?(username: username)
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
end
