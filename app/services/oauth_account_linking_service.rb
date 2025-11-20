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
    Rails.logger.info "OAuth Account Linking Service Debug:"
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
    
    # Use profile picture from OAuth provider
    profile_picture = @picture if @picture.present?
    
    user_attributes = {
      fullname: @name || @email.split('@').first,
      email: @email,
      username: generate_unique_username(@name || @email.split('@').first),
      provider: @provider,
      uid: @uid,
      oauth_token: @auth_hash.dig(:credentials, :token),
      oauth_refresh_token: @auth_hash.dig(:credentials, :refresh_token),
      oauth_expires_at: @auth_hash.dig(:credentials, :expires_at),
      # Use OAuth profile data
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
    
    # Only add phone number if we have one from OAuth provider
    user_attributes[:phone_number] = phone_number if phone_number.present?
    
    Buyer.create!(user_attributes)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create OAuth buyer: #{e.message}"
    Rails.logger.error "Validation errors: #{e.record.errors.full_messages}"
    nil
  end

  def create_seller
    phone_number = extract_phone_number
    location_data = get_user_location_data
    
    # Use profile picture from OAuth provider
    profile_picture = @picture if @picture.present?
    
    # Get county/sub-county from location data or use defaults
    county_id = location_data[:county_id]
    sub_county_id = location_data[:sub_county_id]
    
    # Default to Nairobi if no location found
    if county_id.blank?
      nairobi_county = County.find_by(name: 'Nairobi')
      if nairobi_county
        county_id = nairobi_county.id
        sub_county_id = nairobi_county.sub_counties.first&.id
      end
    end
    
    user_attributes = {
      fullname: @name || @email.split('@').first,
      email: @email,
      username: generate_unique_username(@name || @email.split('@').first),
      provider: @provider,
      uid: @uid,
      oauth_token: @auth_hash.dig(:credentials, :token),
      oauth_refresh_token: @auth_hash.dig(:credentials, :refresh_token),
      oauth_expires_at: @auth_hash.dig(:credentials, :expires_at),
      # Use OAuth profile data
      age_group_id: calculate_age_group,
      gender: extract_gender,
      profile_picture: profile_picture, # Set fixed profile picture from OAuth
      # Add location data (required for sellers)
      location: location_data[:location] || location_data[:city] || 'Nairobi',
      city: location_data[:city] || 'Nairobi',
      county_id: county_id,
      sub_county_id: sub_county_id,
      # Enterprise name defaults to fullname if not provided
      enterprise_name: @name || @email.split('@').first
    }
    
    # Only add phone number if we have one from OAuth provider
    user_attributes[:phone_number] = phone_number if phone_number.present?
    
    Rails.logger.info "🔍 Creating seller with attributes: #{user_attributes.except(:oauth_token, :oauth_refresh_token).inspect}"
    
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
    # OAuth providers may not provide phone number in basic profile
    # Return nil to indicate no phone number available
    nil
  end

  def extract_gender
    # Get gender from OAuth profile
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
    # Get birthday from OAuth profile
    birthday = @auth_hash.dig(:info, :birthday) || @auth_hash.dig(:info, :birth_date)
    
    if birthday.present?
      begin
        # Parse birthday (typically in YYYY-MM-DD format)
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
        
        # Log full API response for debugging
        Rails.logger.info "IP API Response: #{ip_data.inspect}"
        
        if ip_data['status'] == 'success'
          city = ip_data['city']
          region = ip_data['region'] # Region code (e.g., "01", "02")
          region_name = ip_data['regionName'] # Full region name
          country = ip_data['country']
          country_code = ip_data['countryCode']
          lat = ip_data['lat']
          lon = ip_data['lon']
          
          location_data[:city] = city
          location_data[:location] = "#{city}, #{region_name}, #{country}"
          location_data[:zipcode] = ip_data['zip']
          
          Rails.logger.info "Parsed location data: city=#{city}, region=#{region}, regionName=#{region_name}, country=#{country}"
          
          # Map to Kenyan counties and sub-counties using API data
          county_mapping = map_to_kenyan_county_from_api(ip_data)
          if county_mapping
            location_data[:county_id] = county_mapping[:county_id]
            location_data[:sub_county_id] = county_mapping[:sub_county_id]
            Rails.logger.info "Mapped to Kenyan location: County ID #{county_mapping[:county_id]}, Sub-County ID #{county_mapping[:sub_county_id]}"
          end
          
          Rails.logger.info "User location detected: #{location_data[:location]}"
        else
          Rails.logger.warn "IP API returned error: #{ip_data['message']}"
        end
      end
    rescue => e
      Rails.logger.warn "Failed to get location from IP: #{e.message}"
      Rails.logger.warn "Backtrace: #{e.backtrace.first(3).join("\n")}"
    end
    
    location_data
  end

  def map_to_kenyan_county_from_api(ip_data)
    country = ip_data['country']
    country_code = ip_data['countryCode']
    
    # Only process if country is Kenya
    return nil unless country&.downcase&.include?('kenya') || country_code&.upcase == 'KE'
    
    city = ip_data['city']
    region = ip_data['region'] # Region code
    region_name = ip_data['regionName'] # Full region name
    district = ip_data['district'] # District (if available)
    
    Rails.logger.info "Mapping from API data: city='#{city}', region='#{region}', regionName='#{region_name}', district='#{district}'"
    
    # Get all counties from database for matching
    counties = County.all
    
    # Try to match by regionName first (most reliable for Kenya)
    if region_name.present?
      region_normalized = region_name.downcase.strip
      
      # Try exact match first
      county = counties.find { |c| c.name.downcase == region_normalized }
      
      # Try partial match if exact match fails
      if county.nil?
        county = counties.find do |c|
          county_name_normalized = c.name.downcase
          county_name_normalized.include?(region_normalized) || region_normalized.include?(county_name_normalized)
        end
      end
      
      if county
        sub_county = county.sub_counties.first
        Rails.logger.info "Matched by regionName: #{county.name} (ID: #{county.id})"
        return {
          county_id: county.id,
          sub_county_id: sub_county&.id
        }
      end
    end
    
    # Try to match by city name
    if city.present?
      city_normalized = city.downcase.strip
      
      # Get all county names and try to match
      county = counties.find do |c|
        county_name_normalized = c.name.downcase
        # Check if city name matches county name or vice versa
        city_normalized == county_name_normalized ||
        city_normalized.include?(county_name_normalized) ||
        county_name_normalized.include?(city_normalized)
      end
      
      if county
        sub_county = county.sub_counties.first
        Rails.logger.info "Matched by city: #{county.name} (ID: #{county.id})"
        return {
          county_id: county.id,
          sub_county_id: sub_county&.id
        }
      end
    end
    
    # Try to match by district if available
    if district.present?
      district_normalized = district.downcase.strip
      
      county = counties.find do |c|
        county_name_normalized = c.name.downcase
        district_normalized.include?(county_name_normalized) || county_name_normalized.include?(district_normalized)
      end
      
      if county
        sub_county = county.sub_counties.first
        Rails.logger.info "Matched by district: #{county.name} (ID: #{county.id})"
        return {
          county_id: county.id,
          sub_county_id: sub_county&.id
        }
      end
    end
    
    # Default to Nairobi if no mapping found
    Rails.logger.info "No county mapping found from API data, defaulting to Nairobi"
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

end
