# app/services/google_oauth_service.rb
require 'httparty'

class GoogleOauthService
  GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'
  GOOGLE_USER_INFO_URL = 'https://www.googleapis.com/oauth2/v2/userinfo'
  GOOGLE_PEOPLE_API_URL = 'https://people.googleapis.com/v1/people/me'
  
  def initialize(auth_code, redirect_uri)
    @auth_code = auth_code
    @redirect_uri = redirect_uri
  end

  def authenticate
    begin
      Rails.logger.info "🚀 Starting Google OAuth authentication"
      Rails.logger.info "📝 Auth code: #{@auth_code[0..10]}..." if @auth_code
      Rails.logger.info "🔗 Redirect URI: #{@redirect_uri}"
      
      # Step 1: Exchange authorization code for access token
      access_token = exchange_code_for_token
      
      unless access_token
        Rails.logger.error "❌ Failed to get access token"
        return { success: false, error: 'Failed to get access token' }
      end
      
      # Step 2: Get comprehensive user info from Google
      user_info = get_comprehensive_user_info(access_token)
      
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
    rescue => e
      Rails.logger.error "❌ Google OAuth authentication failed: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.join("\n")}"
      { success: false, error: "Authentication failed: #{e.message}" }
    end
  end

  private

  def exchange_code_for_token
    begin
      # For GSI popup authentication, use 'postmessage' as redirect_uri
      redirect_uri = @redirect_uri == 'postmessage' ? 'postmessage' : @redirect_uri
      
      Rails.logger.info "🔄 Exchanging code for token with redirect_uri: #{redirect_uri}"
      Rails.logger.info "🔑 Using client_id: #{ENV['GOOGLE_CLIENT_ID']}"
      
      # Validate required environment variables
      unless ENV['GOOGLE_CLIENT_ID'].present? && ENV['GOOGLE_CLIENT_SECRET'].present?
        Rails.logger.error "❌ Missing Google OAuth credentials"
        return nil
      end
      
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
    rescue => e
      Rails.logger.error "❌ Error exchanging code for token: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.join("\n")}"
      nil
    end
  end

  def get_comprehensive_user_info(access_token)
    begin
      Rails.logger.info "👤 Fetching comprehensive user info from Google"
      
      # Get basic profile info
      basic_info = get_basic_user_info(access_token)
      return nil unless basic_info
      
      # Get detailed info from People API
      detailed_info = get_detailed_user_info(access_token)
      
      # Merge the information
      comprehensive_info = basic_info.merge(detailed_info || {})
      
      Rails.logger.info "✅ Successfully obtained comprehensive user info: #{comprehensive_info['email']}"
      Rails.logger.info "📊 Available data: #{comprehensive_info.keys.join(', ')}"
      
      comprehensive_info
    rescue => e
      Rails.logger.error "❌ Error getting comprehensive user info: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.join("\n")}"
      nil
    end
  end

  def get_basic_user_info(access_token)
    begin
      Rails.logger.info "👤 Fetching basic user info from Google"
      
      response = HTTParty.get(GOOGLE_USER_INFO_URL, {
        headers: { 'Authorization' => "Bearer #{access_token}" }
      })
      
      Rails.logger.info "📡 Google user info response status: #{response.code}"
      Rails.logger.info "📡 Google user info response body: #{response.body}"
      
      unless response.success?
        Rails.logger.error "❌ Failed to get basic user info. Status: #{response.code}, Body: #{response.body}"
        return nil
      end
      
      user_info = JSON.parse(response.body)
      Rails.logger.info "✅ Successfully obtained basic user info: #{user_info['email']}"
      user_info
    rescue => e
      Rails.logger.error "❌ Error getting basic user info: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.join("\n")}"
      nil
    end
  end

  def get_detailed_user_info(access_token)
    begin
      Rails.logger.info "👤 Fetching detailed user info from Google People API"
      
      # Request comprehensive user data from People API
      person_fields = [
        'names',           # Full name, given name, family name
        'photos',          # Profile pictures
        'phoneNumbers',   # Phone numbers
        'addresses',       # Physical addresses
        'birthdays',      # Birthday information
        'genders',        # Gender information
        'ageRanges',      # Age range
        'locales',        # Language preferences
        'organizations',  # Work information
        'occupations',    # Job titles
        'biographies'     # About/bio information
      ].join(',')
      
      response = HTTParty.get(GOOGLE_PEOPLE_API_URL, {
        headers: { 'Authorization' => "Bearer #{access_token}" },
        query: { personFields: person_fields }
      })
      
      Rails.logger.info "📡 Google People API response status: #{response.code}"
      Rails.logger.info "📡 Google People API response body: #{response.body}"
      
      unless response.success?
        Rails.logger.warn "⚠️ Failed to get detailed user info from People API. Status: #{response.code}, Body: #{response.body}"
        return {}
      end
      
      detailed_info = JSON.parse(response.body)
      Rails.logger.info "✅ Successfully obtained detailed user info from People API"
      
      # Extract and format the detailed information
      extract_detailed_info(detailed_info)
    rescue => e
      Rails.logger.warn "⚠️ Error getting detailed user info from People API: #{e.message}"
      Rails.logger.warn "⚠️ Backtrace: #{e.backtrace.join("\n")}"
      {}
    end
  end

  def extract_detailed_info(people_data)
    extracted = {}
    
    # Extract names
    if people_data['names']&.any?
      name_info = people_data['names'].first
      extracted['given_name'] = name_info['givenName']
      extracted['family_name'] = name_info['familyName']
      extracted['display_name'] = name_info['displayName']
    end
    
    # Extract photos (profile pictures)
    if people_data['photos']&.any?
      photo_info = people_data['photos'].first
      extracted['picture'] = photo_info['url']
      extracted['picture_metadata'] = {
        'default' => photo_info['default'],
        'metadata' => photo_info['metadata']
      }
    end
    
    # Extract phone numbers
    if people_data['phoneNumbers']&.any?
      phone_info = people_data['phoneNumbers'].first
      extracted['phone_number'] = phone_info['value']
      extracted['phone_type'] = phone_info['type']
    end
    
    # Extract addresses
    if people_data['addresses']&.any?
      address_info = people_data['addresses'].first
      extracted['address'] = {
        'formatted' => address_info['formattedValue'],
        'street' => address_info['streetAddress'],
        'city' => address_info['city'],
        'region' => address_info['region'],
        'postal_code' => address_info['postalCode'],
        'country' => address_info['country']
      }
    end
    
    # Extract birthday
    if people_data['birthdays']&.any?
      birthday_info = people_data['birthdays'].first
      if birthday_info['date']
        date = birthday_info['date']
        extracted['birthday'] = "#{date['year']}-#{date['month']}-#{date['day']}"
      end
    end
    
    # Extract gender
    if people_data['genders']&.any?
      gender_info = people_data['genders'].first
      extracted['gender'] = gender_info['value']
    end
    
    # Extract age range
    if people_data['ageRanges']&.any?
      age_info = people_data['ageRanges'].first
      extracted['age_range'] = age_info['ageRange']
    end
    
    # Extract work information
    if people_data['organizations']&.any?
      org_info = people_data['organizations'].first
      extracted['work_info'] = {
        'company' => org_info['name'],
        'title' => org_info['title'],
        'department' => org_info['department']
      }
    end
    
    # Extract biography
    if people_data['biographies']&.any?
      bio_info = people_data['biographies'].first
      extracted['biography'] = bio_info['value']
    end
    
    Rails.logger.info "📊 Extracted detailed info: #{extracted.keys.join(', ')}"
    extracted
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
    
    # Extract comprehensive user information
    fullname = user_info['display_name'] || user_info['name'] || user_info['given_name'] || user_info['email'].split('@').first
    profile_picture = user_info['picture'] || user_info['photo_url']
    
    # Extract location information
    location_info = extract_location_info(user_info)
    
    user_attributes = {
      fullname: fullname,
      email: user_info['email'],
      username: generate_unique_username(fullname),
      phone_number: phone_number,
      provider: provider,
      uid: uid,
      oauth_token: user_info['access_token'],
      oauth_expires_at: Time.current + 1.hour,
      age_group_id: calculate_age_group(user_info),
      gender: extract_gender(user_info),
      profile_picture: profile_picture,
      location: location_info[:location],
      city: location_info[:city],
      zipcode: location_info[:zipcode]
    }
    
    # Add additional information if available
    if user_info['biography'].present?
      user_attributes[:description] = user_info['biography']
    end
    
    Rails.logger.info "🆕 Creating new OAuth user with comprehensive attributes"
    Rails.logger.info "📊 User data: #{user_attributes.except(:oauth_token, :oauth_expires_at).inspect}"
    
    user = Buyer.create!(user_attributes)
    
    Rails.logger.info "✅ Successfully created OAuth user: #{user.email}"
    Rails.logger.info "📸 Profile picture: #{user.profile_picture}"
    Rails.logger.info "📍 Location: #{user.location}"
    Rails.logger.info "🏙️ City: #{user.city}"
    
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
    # Try to get phone number from People API data
    phone_number = user_info['phone_number']
    
    if phone_number.present?
      # Clean and format the phone number
      cleaned_phone = phone_number.gsub(/[^\d+]/, '')
      
      # If it starts with +, keep it as is, otherwise add + if it looks international
      if cleaned_phone.start_with?('+')
        cleaned_phone
      elsif cleaned_phone.length > 10
        "+#{cleaned_phone}"
      else
        cleaned_phone
      end
    else
      nil
    end
  end

  def extract_location_info(user_info)
    location_info = { location: nil, city: nil, zipcode: nil }
    
    # Extract from address information
    if user_info['address'].present?
      address = user_info['address']
      location_info[:location] = address['formatted'] || address['street']
      location_info[:city] = address['city']
      location_info[:zipcode] = address['postal_code']
    end
    
    # Fallback to basic location if available
    if location_info[:location].blank? && user_info['locale'].present?
      location_info[:location] = user_info['locale']
    end
    
    location_info
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
