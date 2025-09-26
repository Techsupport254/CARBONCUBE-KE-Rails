# app/services/google_oauth_service.rb
class GoogleOauthService
  GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'
  GOOGLE_USER_INFO_URL = 'https://www.googleapis.com/oauth2/v2/userinfo'
  
  def initialize(auth_code, redirect_uri)
    @auth_code = auth_code
    @redirect_uri = redirect_uri
  end

  def authenticate
    Rails.logger.info "🚀 Starting Google OAuth authentication"
    Rails.logger.info "📝 Auth code: #{@auth_code[0..10]}..." if @auth_code
    Rails.logger.info "🔗 Redirect URI: #{@redirect_uri}"
    
    # Step 1: Exchange authorization code for access token
    access_token = exchange_code_for_token
    
    unless access_token
      Rails.logger.error "❌ Failed to get access token"
      return { success: false, error: 'Failed to get access token' }
    end
    
    # Step 2: Get user info from Google
    user_info = get_user_info(access_token)
    
    unless user_info
      Rails.logger.error "❌ Failed to get user info"
      return { success: false, error: 'Failed to get user info' }
    end
    
    # Step 3: Find or create user
    Rails.logger.info "👤 Finding or creating user for email: #{user_info['email']}"
    user = find_or_create_user(user_info)
    
    unless user
      Rails.logger.error "❌ Failed to create user"
      return { success: false, error: 'Failed to create user' }
    end
    
    Rails.logger.info "✅ Google OAuth authentication successful for user: #{user.email}"
    { success: true, user: user, access_token: access_token }
  end

  private

  def exchange_code_for_token
    # For GSI popup authentication, use 'postmessage' as redirect_uri
    redirect_uri = @redirect_uri == 'postmessage' ? 'postmessage' : @redirect_uri
    
    Rails.logger.info "🔄 Exchanging code for token with redirect_uri: #{redirect_uri}"
    Rails.logger.info "🔑 Using client_id: #{ENV['GOOGLE_CLIENT_ID']}"
    
    response = HTTParty.post(GOOGLE_TOKEN_URL, {
      body: {
        client_id: ENV['GOOGLE_CLIENT_ID'],
        client_secret: ENV['GOOGLE_CLIENT_SECRET'],
        code: @auth_code,
        grant_type: 'authorization_code',
        redirect_uri: redirect_uri
      },
      headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
    })
    
    Rails.logger.info "📡 Google token response status: #{response.code}"
    Rails.logger.info "📡 Google token response body: #{response.body}"
    
    unless response.success?
      Rails.logger.error "❌ Failed to exchange code for token. Status: #{response.code}, Body: #{response.body}"
      return nil
    end
    
    token_data = JSON.parse(response.body)
    access_token = token_data['access_token']
    
    if access_token.nil?
      Rails.logger.error "❌ No access token in response: #{token_data}"
      return nil
    end
    
    Rails.logger.info "✅ Successfully obtained access token"
    access_token
  end

  def get_user_info(access_token)
    Rails.logger.info "👤 Fetching user info from Google"
    
    response = HTTParty.get(GOOGLE_USER_INFO_URL, {
      headers: { 'Authorization' => "Bearer #{access_token}" }
    })
    
    Rails.logger.info "📡 Google user info response status: #{response.code}"
    Rails.logger.info "📡 Google user info response body: #{response.body}"
    
    unless response.success?
      Rails.logger.error "❌ Failed to get user info. Status: #{response.code}, Body: #{response.body}"
      return nil
    end
    
    user_info = JSON.parse(response.body)
    Rails.logger.info "✅ Successfully obtained user info: #{user_info['email']}"
    user_info
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
    # Create as buyer by default for Google OAuth users
    phone_number = extract_phone_number(user_info)
    
    # If no phone number from Google, generate a placeholder
    # This is needed because the validation runs before the record is saved
    if phone_number.blank?
      phone_number = generate_placeholder_phone
    end
    
    user_attributes = {
      fullname: user_info['name'] || user_info['email'].split('@').first,
      email: user_info['email'],
      username: generate_unique_username(user_info['name'] || user_info['email'].split('@').first),
      phone_number: phone_number, # Always provide a phone number for validation
      provider: provider,
      uid: uid,
      oauth_token: user_info['access_token'],
      oauth_expires_at: Time.current + 1.hour,
      age_group_id: calculate_age_group(user_info),
      gender: extract_gender(user_info),
      profile_picture: user_info['picture'] # Set profile picture from Google
    }
    
    Rails.logger.info "🆕 Creating new OAuth user with attributes: #{user_attributes.except(:oauth_token, :oauth_expires_at)}"
    
    user = Buyer.create!(user_attributes)
    
    Rails.logger.info "✅ Successfully created OAuth user: #{user.email}"
    user
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "❌ Failed to create OAuth user: #{e.message}"
    Rails.logger.error "User info: #{user_info.inspect}"
    Rails.logger.error "Validation errors: #{e.record.errors.full_messages}"
    Rails.logger.error "User attributes: #{user_attributes.inspect}"
    nil
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
    gender = user_info['gender']
    
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
    birthday = user_info['birthday'] || user_info['birth_date']
    
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
end
