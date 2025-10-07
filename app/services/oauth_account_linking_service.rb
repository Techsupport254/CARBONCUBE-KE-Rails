# app/services/oauth_account_linking_service.rb
class OauthAccountLinkingService
  def initialize(auth_hash, role = 'Buyer', user_ip = nil)
    @auth_hash = auth_hash
    @role = role
    @provider = auth_hash[:provider]
    @uid = auth_hash[:uid]
    @email = auth_hash.dig(:info, :email)
    @name = auth_hash.dig(:info, :name)
    @picture = auth_hash.dig(:info, :image)
    @user_ip = user_ip
    
    # Debug: Log the profile picture information
    Rails.logger.info "🔍 OAuth Account Linking Service Debug:"
    Rails.logger.info "   Provider: #{@provider}"
    Rails.logger.info "   Email: #{@email}"
    Rails.logger.info "   Name: #{@name}"
    Rails.logger.info "   Picture: #{@picture.inspect}"
    Rails.logger.info "   Auth hash info: #{auth_hash[:info].inspect}"
  end

  def call
    # First, try to find existing user by email
    existing_user = find_user_by_email(@email)
    
    if existing_user
      # Link OAuth account to existing user
      link_oauth_to_existing_user(existing_user)
      return { success: true, user: existing_user, message: 'Account linked successfully' }
    end
    
    # Check if user exists with this OAuth account
    oauth_user = find_user_by_oauth(@provider, @uid)
    if oauth_user
      return { success: true, user: oauth_user, message: 'Welcome back!' }
    end
    
    # Create new user based on role
    new_user = create_new_oauth_user
    if new_user
      { success: true, user: new_user, message: 'Account created successfully' }
    else
      { success: false, error: 'Failed to create account', error_type: 'creation_failed' }
    end
  rescue => e
    Rails.logger.error "OAuth account linking error: #{e.message}"
    { success: false, error: 'Authentication failed', error_type: 'system_error' }
  end

  private

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

  def link_oauth_to_existing_user(user)
    # Only link if not already linked to this provider
    unless user.provider == @provider && user.uid == @uid
      user.update!(
        provider: @provider,
        uid: @uid,
        oauth_token: @auth_hash.dig(:credentials, :token),
        oauth_refresh_token: @auth_hash.dig(:credentials, :refresh_token),
        oauth_expires_at: @auth_hash.dig(:credentials, :expires_at)
      )
    end
  end

  def create_new_oauth_user
    case @role
    when 'seller'
      create_seller
    when 'admin'
      create_admin
    when 'sales_user'
      create_sales_user
    else
      create_buyer # Default to buyer
    end
  end

  def create_buyer
    phone_number = extract_phone_number
    location_data = get_user_location_data
    
    # Fix Google profile picture URL to make it publicly accessible
    profile_picture = fix_google_profile_picture_url(@picture) if @picture.present?
    
    user_attributes = {
      fullname: @name || @email.split('@').first,
      email: @email,
      username: generate_unique_username(@name || @email.split('@').first),
      provider: @provider,
      uid: @uid,
      oauth_token: @auth_hash.dig(:credentials, :token),
      oauth_refresh_token: @auth_hash.dig(:credentials, :refresh_token),
      oauth_expires_at: @auth_hash.dig(:credentials, :expires_at),
      # Use Google profile data
      age_group_id: calculate_age_group,
      gender: extract_gender,
      profile_picture: profile_picture, # Set fixed profile picture from OAuth
      # Add location data
      location: location_data[:location],
      city: location_data[:city],
      zipcode: location_data[:zipcode],
      county_id: location_data[:county_id],
      sub_county_id: location_data[:sub_county_id]
    }
    
    # Only add phone number if we have one from Google
    user_attributes[:phone_number] = phone_number if phone_number.present?
    
    Buyer.create!(user_attributes)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create OAuth buyer: #{e.message}"
    Rails.logger.error "Validation errors: #{e.record.errors.full_messages}"
    nil
  end

  def create_seller
    phone_number = extract_phone_number
    
    # Fix Google profile picture URL to make it publicly accessible
    profile_picture = fix_google_profile_picture_url(@picture) if @picture.present?
    
    user_attributes = {
      fullname: @name || @email.split('@').first,
      email: @email,
      username: generate_unique_username(@name || @email.split('@').first),
      provider: @provider,
      uid: @uid,
      oauth_token: @auth_hash.dig(:credentials, :token),
      oauth_refresh_token: @auth_hash.dig(:credentials, :refresh_token),
      oauth_expires_at: @auth_hash.dig(:credentials, :expires_at),
      # Use Google profile data
      age_group_id: calculate_age_group,
      gender: extract_gender,
      profile_picture: profile_picture # Set fixed profile picture from OAuth
    }
    
    # Only add phone number if we have one from Google
    user_attributes[:phone_number] = phone_number if phone_number.present?
    
    Seller.create!(user_attributes)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create OAuth seller: #{e.message}"
    Rails.logger.error "Validation errors: #{e.record.errors.full_messages}"
    nil
  end

  def create_admin
    random_password = SecureRandom.hex(16)
    
    Admin.create!(
      fullname: @name || @email.split('@').first,
      email: @email,
      username: generate_unique_username(@name || @email.split('@').first),
      provider: @provider,
      uid: @uid,
      oauth_token: @auth_hash.dig(:credentials, :token),
      oauth_refresh_token: @auth_hash.dig(:credentials, :refresh_token),
      oauth_expires_at: @auth_hash.dig(:credentials, :expires_at),
      password: random_password, # Random password for OAuth users
      password_confirmation: random_password
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create OAuth admin: #{e.message}"
    Rails.logger.error "Validation errors: #{e.record.errors.full_messages}"
    nil
  end

  def create_sales_user
    random_password = SecureRandom.hex(16)
    
    SalesUser.create!(
      fullname: @name || @email.split('@').first,
      email: @email,
      provider: @provider,
      uid: @uid,
      oauth_token: @auth_hash.dig(:credentials, :token),
      oauth_refresh_token: @auth_hash.dig(:credentials, :refresh_token),
      oauth_expires_at: @auth_hash.dig(:credentials, :expires_at),
      password: random_password, # Random password for OAuth users
      password_confirmation: random_password
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create OAuth sales user: #{e.message}"
    Rails.logger.error "Validation errors: #{e.record.errors.full_messages}"
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

  def extract_phone_number
    # Google OAuth doesn't provide user's own phone number in basic profile
    # The phone number scope is for accessing user's contacts, not their own number
    # Return nil to indicate no phone number available
    nil
  end

  def extract_gender
    # Get gender from Google profile
    gender = @auth_hash.dig(:info, :gender)
    
    case gender&.downcase
    when 'male', 'm'
      'Male'
    when 'female', 'f'
      'Female'
    else
      'Male' # Default to Male if not specified or unrecognized
    end
  end

  def calculate_age_group
    # Get birthday from Google profile
    birthday = @auth_hash.dig(:info, :birthday) || @auth_hash.dig(:info, :birth_date)
    
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

  def get_user_location_data
    location_data = { 
      location: nil, 
      city: nil, 
      zipcode: nil, 
      county_id: nil, 
      sub_county_id: nil 
    }
    
    return location_data unless @user_ip.present?
    
    begin
      # Use ip-api.com to get location from user's IP
      api_url = "http://ip-api.com/json/#{@user_ip}"
      response = HTTParty.get(api_url, timeout: 5)
      
      if response.success?
        ip_data = JSON.parse(response.body)
        if ip_data['status'] == 'success'
          city = ip_data['city']
          region = ip_data['regionName']
          country = ip_data['country']
          
          location_data[:city] = city
          location_data[:location] = "#{city}, #{region}, #{country}"
          location_data[:zipcode] = ip_data['zip']
          
          # Map to Kenyan counties and sub-counties
          county_mapping = map_to_kenyan_county(city, region, country)
          if county_mapping
            location_data[:county_id] = county_mapping[:county_id]
            location_data[:sub_county_id] = county_mapping[:sub_county_id]
            Rails.logger.info "🗺️ Mapped to Kenyan location: County ID #{county_mapping[:county_id]}, Sub-County ID #{county_mapping[:sub_county_id]}"
          end
          
          Rails.logger.info "🌐 User location detected: #{location_data[:location]}"
        end
      end
    rescue => e
      Rails.logger.warn "Failed to get location from IP: #{e.message}"
    end
    
    location_data
  end

  def map_to_kenyan_county(city, region, country)
    return nil unless country&.downcase&.include?('kenya')
    
    # Normalize city and region names for matching
    city_normalized = city&.downcase&.strip
    region_normalized = region&.downcase&.strip
    
    Rails.logger.info "🗺️ Mapping location: City='#{city}', Region='#{region}', Country='#{country}'"
    
    # Direct city to county mapping for major Kenyan cities
    city_county_mapping = {
      'nairobi' => 'Nairobi',
      'mombasa' => 'Mombasa',
      'kisumu' => 'Kisumu',
      'nakuru' => 'Nakuru',
      'eldoret' => 'Uasin Gishu',
      'thika' => 'Kiambu',
      'malindi' => 'Kilifi',
      'kitale' => 'Trans Nzoia',
      'garissa' => 'Garissa',
      'kakamega' => 'Kakamega',
      'meru' => 'Meru',
      'kisii' => 'Kisii',
      'nyeri' => 'Nyeri',
      'machakos' => 'Machakos',
      'kericho' => 'Kericho',
      'lamu' => 'Lamu',
      'bomet' => 'Bomet',
      'vihiga' => 'Vihiga',
      'baringo' => 'Baringo',
      'bungoma' => 'Bungoma',
      'busia' => 'Busia',
      'embu' => 'Embu',
      'homa bay' => 'Homa Bay',
      'isiolo' => 'Isiolo',
      'kajiado' => 'Kajiado',
      'kilifi' => 'Kilifi',
      'kirinyaga' => 'Kirinyaga',
      'kitui' => 'Kitui',
      'kwale' => 'Kwale',
      'laikipia' => 'Laikipia',
      'lamu' => 'Lamu',
      'makueni' => 'Makueni',
      'mandera' => 'Mandera',
      'marsabit' => 'Marsabit',
      'murang\'a' => 'Murang\'a',
      'muranga' => 'Murang\'a',
      'nyamira' => 'Nyamira',
      'nyandarua' => 'Nyandarua',
      'nyeri' => 'Nyeri',
      'samburu' => 'Samburu',
      'siaya' => 'Siaya',
      'taita taveta' => 'Taita Taveta',
      'tana river' => 'Tana River',
      'tharaka nithi' => 'Tharaka Nithi',
      'trans nzoia' => 'Trans Nzoia',
      'turkana' => 'Turkana',
      'uasin gishu' => 'Uasin Gishu',
      'vihiga' => 'Vihiga',
      'wajir' => 'Wajir',
      'west pokot' => 'West Pokot'
    }
    
    # Try to find county by city name
    county_name = city_county_mapping[city_normalized]
    
    # If not found by city, try by region
    if county_name.nil?
      county_name = city_county_mapping[region_normalized]
    end
    
    # If still not found, try partial matching
    if county_name.nil?
      city_county_mapping.each do |key, value|
        if city_normalized&.include?(key) || key.include?(city_normalized)
          county_name = value
          break
        end
      end
    end
    
    if county_name
      county = County.find_by(name: county_name)
      if county
        # For now, use the first sub-county of the county
        # In a more sophisticated system, you could use additional logic to determine the specific sub-county
        sub_county = county.sub_counties.first
        
        Rails.logger.info "🗺️ Found county: #{county.name} (ID: #{county.id})"
        Rails.logger.info "🗺️ Using sub-county: #{sub_county&.name} (ID: #{sub_county&.id})"
        
        return {
          county_id: county.id,
          sub_county_id: sub_county&.id
        }
      end
    end
    
    # Default to Nairobi if no mapping found
    Rails.logger.info "🗺️ No county mapping found, defaulting to Nairobi"
    nairobi_county = County.find_by(name: 'Nairobi')
    if nairobi_county
      nairobi_sub_county = nairobi_county.sub_counties.first
      return {
        county_id: nairobi_county.id,
        sub_county_id: nairobi_sub_county&.id
      }
    end
    
    nil
  end

  # Fix Google profile picture URL to make it publicly accessible
  def fix_google_profile_picture_url(original_url)
    return nil if original_url.blank?
    
    Rails.logger.info "🔧 Original profile picture URL: #{original_url}"
    
    # Google profile picture URLs often need modification to be publicly accessible
    # Remove size restrictions and make the URL publicly accessible
    fixed_url = original_url.dup
    
    # Remove size parameters that might cause access issues
    fixed_url = fixed_url.gsub(/=s\d+/, '=s0') # Change size to 0 (full size)
    fixed_url = fixed_url.gsub(/=w\d+-h\d+/, '=s0') # Remove width/height restrictions
    fixed_url = fixed_url.gsub(/=c\d+/, '=s0') # Remove crop restrictions
    
    # Ensure the URL is publicly accessible
    if fixed_url.include?('googleusercontent.com')
      # For Google profile pictures, ensure we have the right format
      fixed_url = fixed_url.gsub(/=s\d+/, '=s0') if fixed_url.include?('=s')
    end
    
    Rails.logger.info "🔧 Fixed profile picture URL: #{fixed_url}"
    fixed_url
  rescue => e
    Rails.logger.error "❌ Error fixing profile picture URL: #{e.message}"
    original_url # Return original URL if fixing fails
  end
end
