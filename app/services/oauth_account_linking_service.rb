# app/services/oauth_account_linking_service.rb
class OauthAccountLinkingService
  def initialize(auth_hash, role = 'Buyer', user_ip = nil)
    @auth_hash = auth_hash
    # Normalize role to handle both "Seller" and "seller" formats
    @role = role.to_s.strip
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
    Rails.logger.info "   Role: #{@role.inspect} (#{@role.class})"
    Rails.logger.info "   Auth hash info: #{auth_hash[:info].inspect}"
  end

  def call
    # Normalize role for comparison
    normalized_requested_role = @role.to_s.downcase.strip
    
    # First, try to find existing user by email
    existing_user = find_user_by_email(@email)
    
    if existing_user
      # Check if the existing user's role matches the requested role
      existing_role = determine_user_role(existing_user)
      existing_role_normalized = existing_role.to_s.downcase.strip
      
      Rails.logger.info "🔍 [OauthAccountLinkingService] Existing user found: #{existing_user.class.name}"
      Rails.logger.info "   Existing role: #{existing_role_normalized}"
      Rails.logger.info "   Requested role: #{normalized_requested_role}"
      
      # If roles don't match, return an error
      if existing_role_normalized != normalized_requested_role
        Rails.logger.error "❌ [OauthAccountLinkingService] Role mismatch!"
        Rails.logger.error "   User #{@email} already exists as #{existing_role}"
        Rails.logger.error "   Cannot create #{normalized_requested_role.capitalize} account with same email"
        
        return {
          success: false,
          error: "This email is already registered as a #{existing_role}. Please sign in with your existing account or use a different email address.",
          role_mismatch: true,
          existing_role: existing_role,
          requested_role: normalized_requested_role.capitalize
        }
      end
      
      # Roles match, link OAuth account to existing user
      link_oauth_to_existing_user(existing_user)
      return { success: true, user: existing_user, message: 'Account linked successfully' }
    end
    
    # Check if user exists with this OAuth account
    oauth_user = find_user_by_oauth(@provider, @uid)
    if oauth_user
      # Check if the OAuth user's role matches the requested role
      oauth_role = determine_user_role(oauth_user)
      oauth_role_normalized = oauth_role.to_s.downcase.strip
      
      Rails.logger.info "🔍 [OauthAccountLinkingService] OAuth user found: #{oauth_user.class.name}"
      Rails.logger.info "   OAuth user role: #{oauth_role_normalized}"
      Rails.logger.info "   Requested role: #{normalized_requested_role}"
      
      # If roles don't match, return an error
      if oauth_role_normalized != normalized_requested_role
        Rails.logger.error "❌ [OauthAccountLinkingService] Role mismatch for OAuth account!"
        Rails.logger.error "   User #{@email} already has OAuth account linked as #{oauth_role}"
        Rails.logger.error "   Cannot use same OAuth account for #{normalized_requested_role.capitalize} registration"
        
        return {
          success: false,
          error: "This Google account is already linked to a #{oauth_role} account. Please sign in with your existing #{oauth_role} account or use a different Google account.",
          role_mismatch: true,
          existing_role: oauth_role,
          requested_role: normalized_requested_role.capitalize
        }
      end
      
      return { success: true, user: oauth_user, message: 'Welcome back!' }
    end
    
    # Create new user based on role
    new_user_result = create_new_oauth_user
    # Check if result is an error hash (from seller creation when phone is missing)
    if new_user_result.is_a?(Hash) && new_user_result[:success] == false
      return new_user_result
    elsif new_user_result
      { success: true, user: new_user_result, message: 'Account created successfully' }
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

  def determine_user_role(user)
    case user.class.name
    when 'Admin'
      'Admin'
    when 'SalesUser'
      'Sales'
    when 'Seller'
      'Seller'
    when 'Buyer'
      'Buyer'
    else
      'Buyer' # default fallback
    end
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
    
    # Auto-verify email for Google OAuth users (email is already verified by Google)
    mark_email_as_verified(@email)
  end

  def create_new_oauth_user
    # Normalize role to lowercase for case-insensitive matching
    # Remove all whitespace and convert to lowercase
    normalized_role = @role.to_s.strip.downcase.gsub(/\s+/, '')
    Rails.logger.info "=" * 80
    Rails.logger.info "🔍 [OauthAccountLinkingService] Creating new user"
    Rails.logger.info "   Original @role: #{@role.inspect} (#{@role.class})"
    Rails.logger.info "   After strip: #{@role.to_s.strip.inspect}"
    Rails.logger.info "   After downcase: #{@role.to_s.strip.downcase.inspect}"
    Rails.logger.info "   Final normalized_role: #{normalized_role.inspect}"
    Rails.logger.info "   Will match against: 'seller', 'admin', 'sales_user', 'salesuser'"
    Rails.logger.info "=" * 80
    
    # Use explicit string comparison to ensure exact match
    if normalized_role == 'seller'
      Rails.logger.info "✅ [OauthAccountLinkingService] MATCHED 'seller' - Creating Seller account"
      create_seller
    elsif normalized_role == 'admin'
      Rails.logger.info "✅ [OauthAccountLinkingService] MATCHED 'admin' - Creating Admin account"
      create_admin
    elsif normalized_role == 'sales_user' || normalized_role == 'salesuser'
      Rails.logger.info "✅ [OauthAccountLinkingService] MATCHED 'sales_user'/'salesuser' - Creating SalesUser account"
      create_sales_user
    else
      Rails.logger.error "❌ [OauthAccountLinkingService] NO MATCH for role '#{normalized_role}'"
      Rails.logger.error "   This will default to Buyer - THIS IS THE BUG!"
      Rails.logger.error "   @role was: #{@role.inspect}"
      Rails.logger.error "   normalized_role was: #{normalized_role.inspect}"
      Rails.logger.error "   normalized_role bytes: #{normalized_role.bytes.inspect}"
      Rails.logger.error "   'seller' bytes: #{'seller'.bytes.inspect}"
      Rails.logger.error "   Are they equal? #{normalized_role == 'seller'}"
      create_buyer # Default to buyer
    end
  end

  def create_buyer
    # Check if user already exists as a different role (safety check)
    existing_seller = Seller.find_by(email: @email)
    if existing_seller
      Rails.logger.error "❌ [OauthAccountLinkingService] Cannot create buyer - user #{@email} already exists as Seller"
      raise ActiveRecord::RecordInvalid.new(Seller.new.tap { |s| s.errors.add(:email, "already registered as Seller") })
    end
    
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
    
    # Phone number is optional for buyers, but always include if available
    user_attributes[:phone_number] = phone_number if phone_number.present?
    
    Rails.logger.info "📞 Creating buyer - Phone number: #{phone_number || 'Not provided (optional for buyers)'}"
    
    buyer = Buyer.create!(user_attributes)
    
    # Auto-verify email for Google OAuth users (email is already verified by Google)
    mark_email_as_verified(@email)
    
    buyer
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create OAuth buyer: #{e.message}"
    Rails.logger.error "Validation errors: #{e.record.errors.full_messages}"
    nil
  end

  def create_seller
    # Check if user already exists as a different role (safety check)
    existing_buyer = Buyer.find_by(email: @email)
    if existing_buyer
      Rails.logger.error "❌ [OauthAccountLinkingService] Cannot create seller - user #{@email} already exists as Buyer"
      raise ActiveRecord::RecordInvalid.new(Buyer.new.tap { |b| b.errors.add(:email, "already registered as Buyer") })
    end
    
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
    
    # Phone number is optional - only include if provided by Google OAuth
    # Users can add it later if needed
    user_attributes[:phone_number] = phone_number if phone_number.present?
    
    Rails.logger.info "🔍 Creating seller with attributes: #{user_attributes.except(:oauth_token, :oauth_refresh_token).inspect}"
    Rails.logger.info "📞 Phone number: #{phone_number}"

    seller = Seller.create!(user_attributes)
    
    # Auto-verify email for Google OAuth users (email is already verified by Google)
    mark_email_as_verified(@email)
    
    # Apply 2025 premium logic for all users registering in 2025
    if should_get_2025_premium?
      create_2025_premium_tier(seller)
    end
    
    seller
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create OAuth seller: #{e.message}"
    Rails.logger.error "Validation errors: #{e.record.errors.full_messages}"
    nil
  end

  def create_admin
    random_password = SecureRandom.hex(16)
    
    admin = Admin.create!(
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
    
    # Auto-verify email for Google OAuth users (email is already verified by Google)
    mark_email_as_verified(@email)
    
    admin
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create OAuth admin: #{e.message}"
    Rails.logger.error "Validation errors: #{e.record.errors.full_messages}"
    nil
  end

  def create_sales_user
    random_password = SecureRandom.hex(16)
    
    sales_user = SalesUser.create!(
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
    
    # Auto-verify email for Google OAuth users (email is already verified by Google)
    mark_email_as_verified(@email)
    
    sales_user
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
    # Try to extract phone number from OAuth auth hash
    phone_number = nil
    
    Rails.logger.info "=" * 80
    Rails.logger.info "🔍 [OauthAccountLinkingService] Extracting phone number from auth_hash"
    Rails.logger.info "   auth_hash[:info][:phone_number]: #{@auth_hash.dig(:info, :phone_number).inspect}"
    Rails.logger.info "   auth_hash[:info][:phone]: #{@auth_hash.dig(:info, :phone).inspect}"
    Rails.logger.info "   auth_hash[:extra][:raw_info][:phone_number]: #{@auth_hash.dig(:extra, :raw_info, :phone_number).inspect}"
    Rails.logger.info "   auth_hash[:extra][:raw_info][:phone_numbers]: #{@auth_hash.dig(:extra, :raw_info, :phone_numbers).inspect}"
    Rails.logger.info "   auth_hash[:extra][:raw_info][:phone_numbers] class: #{@auth_hash.dig(:extra, :raw_info, :phone_numbers).class}"
    Rails.logger.info "=" * 80
    
    # Try multiple sources for phone number
    if @auth_hash.dig(:info, :phone_number).present?
      phone_number = @auth_hash.dig(:info, :phone_number)
      Rails.logger.info "✅ Found phone number in auth_hash[:info][:phone_number]: #{phone_number}"
    elsif @auth_hash.dig(:info, :phone).present?
      phone_number = @auth_hash.dig(:info, :phone)
      Rails.logger.info "✅ Found phone number in auth_hash[:info][:phone]: #{phone_number}"
    elsif @auth_hash.dig(:extra, :raw_info, :phone_number).present?
      phone_number = @auth_hash.dig(:extra, :raw_info, :phone_number)
      Rails.logger.info "✅ Found phone number in auth_hash[:extra][:raw_info][:phone_number]: #{phone_number}"
    elsif @auth_hash.dig(:extra, :raw_info, :phone_numbers)&.is_a?(Array) && @auth_hash.dig(:extra, :raw_info, :phone_numbers).any?
      Rails.logger.info "🔍 Checking phone_numbers array: #{@auth_hash.dig(:extra, :raw_info, :phone_numbers).inspect}"
      # Try to get mobile phone first
      mobile_phone = @auth_hash.dig(:extra, :raw_info, :phone_numbers).find { |p| 
        p.is_a?(Hash) && (p['type']&.downcase == 'mobile' || p['type']&.downcase == 'cell' || p[:type]&.downcase == 'mobile' || p[:type]&.downcase == 'cell')
      }
      phone_info = mobile_phone || @auth_hash.dig(:extra, :raw_info, :phone_numbers).first
      Rails.logger.info "   Selected phone_info: #{phone_info.inspect}"
      if phone_info.is_a?(Hash)
        phone_number = phone_info['value'] || phone_info[:value]
        Rails.logger.info "✅ Extracted phone number from phone_info hash: #{phone_number}"
      elsif phone_info.is_a?(String)
        phone_number = phone_info
        Rails.logger.info "✅ Using phone_info as string: #{phone_number}"
      end
    end
    
    if phone_number.present?
      # Clean and format the phone number
      original_phone = phone_number.to_s
      cleaned_phone = phone_number.to_s.gsub(/[^\d+]/, '')
      
      Rails.logger.info "📞 Phone number processing:"
      Rails.logger.info "   Original: #{original_phone}"
      Rails.logger.info "   After removing non-digits: #{cleaned_phone}"
      
      # Format Kenya phone numbers
      if cleaned_phone.start_with?('+254')
        local_number = cleaned_phone[4..-1]
        if local_number.length == 9 && local_number.start_with?('7')
          cleaned_phone = "0#{local_number}"
        elsif local_number.length == 10 && local_number.start_with?('0')
          cleaned_phone = local_number
        end
      elsif cleaned_phone.start_with?('254') && cleaned_phone.length == 12
        local_number = cleaned_phone[3..-1]
        cleaned_phone = local_number.start_with?('0') ? local_number : "0#{local_number}"
      elsif cleaned_phone.length == 9 && cleaned_phone.start_with?('7')
        cleaned_phone = "0#{cleaned_phone}"
      elsif cleaned_phone.length == 11 && cleaned_phone.start_with?('0')
        # Already formatted correctly
      end
      
      Rails.logger.info "   Final formatted: #{cleaned_phone}"
      Rails.logger.info "✅ Successfully extracted and formatted phone number: #{original_phone} -> #{cleaned_phone}"
      return cleaned_phone
    end
    
    Rails.logger.warn "⚠️ [OauthAccountLinkingService] No phone number found in OAuth auth hash"
    Rails.logger.warn "   Full auth_hash structure:"
    Rails.logger.warn "   auth_hash keys: #{@auth_hash.keys.inspect}"
    Rails.logger.warn "   auth_hash[:info] keys: #{@auth_hash[:info]&.keys.inspect}" if @auth_hash[:info]
    Rails.logger.warn "   auth_hash[:extra] keys: #{@auth_hash[:extra]&.keys.inspect}" if @auth_hash[:extra]
    Rails.logger.warn "   auth_hash[:extra][:raw_info] keys: #{@auth_hash[:extra][:raw_info]&.keys.inspect}" if @auth_hash.dig(:extra, :raw_info)
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

  # Mark email as verified for Google OAuth users
  # Google OAuth emails are already verified by Google, so we can skip OTP verification
  def mark_email_as_verified(email)
    return unless email.present?
    
    # Remove any existing unverified OTPs for this email
    EmailOtp.where(email: email, verified: false).delete_all
    
    # Create or update EmailOtp record with verified: true
    email_otp = EmailOtp.find_or_initialize_by(email: email)
    email_otp.update!(
      verified: true,
      otp_code: nil, # No OTP needed for Google OAuth users
      expires_at: nil # No expiration for verified emails
    )
    
    Rails.logger.info "✅ [OauthAccountLinkingService] Email #{email} marked as verified (Google OAuth)"
  rescue => e
    Rails.logger.error "❌ [OauthAccountLinkingService] Failed to mark email as verified: #{e.message}"
    # Don't fail the entire process if email verification marking fails
  end

  # Check if user should get premium status for 2025 registrations
  def should_get_2025_premium?
    current_year = Time.current.year
    Rails.logger.info "🔍 [OauthAccountLinkingService] Checking 2025 premium status: current_year=#{current_year}, is_2025=#{current_year == 2025}"
    current_year == 2025
  end

  # Get premium tier for 2025 users
  def get_premium_tier
    Tier.find_by(name: 'Premium')
  end

  # Create seller tier for 2025 premium users
  def create_2025_premium_tier(seller)
    Rails.logger.info "🔍 [OauthAccountLinkingService] create_2025_premium_tier called for seller: #{seller.email}"
    
    unless should_get_2025_premium?
      Rails.logger.info "❌ [OauthAccountLinkingService] Not 2025, skipping premium tier assignment"
      return
    end
    
    premium_tier = get_premium_tier
    unless premium_tier
      Rails.logger.error "❌ [OauthAccountLinkingService] Premium tier not found in database"
      return
    end
    
    Rails.logger.info "✅ [OauthAccountLinkingService] Premium tier found: #{premium_tier.name} (ID: #{premium_tier.id})"
    
    # Calculate expiry date (end of 2025) - expires at midnight on January 1, 2026
    expires_at = Time.new(2026, 1, 1, 0, 0, 0)
    
    # Calculate remaining months until end of 2025
    current_date = Time.current
    end_of_2025 = Time.new(2025, 12, 31, 23, 59, 59)
    remaining_days = ((end_of_2025 - current_date) / 1.day).ceil
    duration_months = (remaining_days / 30.44).ceil # Average days per month
    
    # Create seller tier with premium status until end of 2025
    seller_tier = SellerTier.create!(
      seller: seller,
      tier: premium_tier,
      duration_months: duration_months,
      expires_at: expires_at
    )
    
    Rails.logger.info "✅ [OauthAccountLinkingService] Premium tier assigned to seller #{seller.email} until end of 2025 (#{remaining_days} days, ~#{duration_months} months, SellerTier ID: #{seller_tier.id})"
  rescue => e
    Rails.logger.error "❌ [OauthAccountLinkingService] Error creating premium tier: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

end
