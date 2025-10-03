# app/services/google_oauth_service.rb
require 'httparty'

class GoogleOauthService
  GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'
  GOOGLE_USER_INFO_URL = 'https://www.googleapis.com/oauth2/v2/userinfo'
  GOOGLE_PEOPLE_API_URL = 'https://people.googleapis.com/v1/people/me'
  
  def initialize(auth_code, redirect_uri, user_ip = nil)
    @auth_code = auth_code
    @redirect_uri = redirect_uri
    @user_ip = user_ip
  end

  def authenticate
    begin
      puts "🚨 GOOGLE OAUTH SERVICE AUTHENTICATE CALLED!"
      Rails.logger.info "🚨 GOOGLE OAUTH SERVICE AUTHENTICATE CALLED!"
      
      puts "🚀 Starting Google OAuth authentication"
      Rails.logger.info "🚀 Starting Google OAuth authentication"
      puts "📝 Auth code: #{@auth_code[0..10]}..." if @auth_code
      Rails.logger.info "📝 Auth code: #{@auth_code[0..10]}..." if @auth_code
      puts "🔗 Redirect URI: #{@redirect_uri}"
      Rails.logger.info "🔗 Redirect URI: #{@redirect_uri}"
      
      # Step 1: Exchange authorization code for access token
      puts "🔄 Step 1: Exchanging authorization code for access token..."
      Rails.logger.info "🔄 Step 1: Exchanging authorization code for access token..."
      access_token = exchange_code_for_token
      
      unless access_token
        puts "❌ Failed to get access token"
        Rails.logger.error "❌ Failed to get access token"
        return { success: false, error: 'Failed to get access token' }
      end
      
      puts "✅ Access token obtained: #{access_token[0..20]}..."
      Rails.logger.info "✅ Access token obtained: #{access_token[0..20]}..."
      
      # Step 2: Get comprehensive user info from Google
      puts "🔄 Step 2: Getting user info from Google..."
      Rails.logger.info "🔄 Step 2: Getting user info from Google..."
      user_info = get_comprehensive_user_info(access_token)
      
      unless user_info
        puts "❌ Failed to get user info"
        Rails.logger.error "❌ Failed to get user info"
        return { success: false, error: 'Failed to get user info' }
      end
      
      puts "✅ User info obtained from Google"
      Rails.logger.info "✅ User info obtained from Google"
      
      # Step 3: Log ALL Google data (comprehensive logging)
      puts "=" * 100
      puts "📊 GOOGLE OAUTH DATA LOGGING"
      puts "=" * 100
      Rails.logger.info "=" * 100
      Rails.logger.info "📊 GOOGLE OAUTH DATA LOGGING"
      Rails.logger.info "=" * 100
      
      puts "🔑 Access Token: #{access_token}"
      Rails.logger.info "🔑 Access Token: #{access_token}"
      
      puts "📊 COMPREHENSIVE USER DATA FROM GOOGLE:"
      Rails.logger.info "📊 COMPREHENSIVE USER DATA FROM GOOGLE:"
      
      # Log all user data with detailed breakdown
      user_info.each do |key, value|
        puts "  #{key}: #{value.inspect}"
        Rails.logger.info "  #{key}: #{value.inspect}"
      end
      
      puts "=" * 50
      puts "📱 DETAILED USER INFORMATION BREAKDOWN:"
      puts "=" * 50
      Rails.logger.info "=" * 50
      Rails.logger.info "📱 DETAILED USER INFORMATION BREAKDOWN:"
      Rails.logger.info "=" * 50
      
      # Name information
      if user_info['name']
        puts "👤 NAME: #{user_info['name']}"
        Rails.logger.info "👤 NAME: #{user_info['name']}"
      end
      if user_info['given_name']
        puts "👤 GIVEN NAME: #{user_info['given_name']}"
        Rails.logger.info "👤 GIVEN NAME: #{user_info['given_name']}"
      end
      if user_info['family_name']
        puts "👤 FAMILY NAME: #{user_info['family_name']}"
        Rails.logger.info "👤 FAMILY NAME: #{user_info['family_name']}"
      end
      
      # Email information
      if user_info['email']
        puts "📧 EMAIL: #{user_info['email']}"
        Rails.logger.info "📧 EMAIL: #{user_info['email']}"
      end
      if user_info['email_verified']
        puts "📧 EMAIL VERIFIED: #{user_info['email_verified']}"
        Rails.logger.info "📧 EMAIL VERIFIED: #{user_info['email_verified']}"
      end
      
      # Phone numbers
      if user_info['phone_numbers']
        puts "📞 PHONE NUMBERS:"
        Rails.logger.info "📞 PHONE NUMBERS:"
        user_info['phone_numbers'].each_with_index do |phone, index|
          puts "  #{index + 1}. #{phone}"
          Rails.logger.info "  #{index + 1}. #{phone}"
        end
      end
      
      # Addresses
      if user_info['addresses']
        puts "🏠 ADDRESSES:"
        Rails.logger.info "🏠 ADDRESSES:"
        user_info['addresses'].each_with_index do |address, index|
          puts "  #{index + 1}. #{address}"
          Rails.logger.info "  #{index + 1}. #{address}"
        end
      end
      
      # Gender
      if user_info['gender']
        puts "⚧ GENDER: #{user_info['gender']}"
        Rails.logger.info "⚧ GENDER: #{user_info['gender']}"
      end
      
      # Birthday
      if user_info['birthday']
        puts "🎂 BIRTHDAY: #{user_info['birthday']}"
        Rails.logger.info "🎂 BIRTHDAY: #{user_info['birthday']}"
      end
      
      # Age range
      if user_info['age_range']
        puts "📅 AGE RANGE: #{user_info['age_range']}"
        Rails.logger.info "📅 AGE RANGE: #{user_info['age_range']}"
      end
      
      # Profile picture
      if user_info['picture']
        puts "🖼️ PROFILE PICTURE: #{user_info['picture']}"
        Rails.logger.info "🖼️ PROFILE PICTURE: #{user_info['picture']}"
      end
      
      # Google ID
      if user_info['id']
        puts "🆔 GOOGLE ID: #{user_info['id']}"
        Rails.logger.info "🆔 GOOGLE ID: #{user_info['id']}"
      end
      
      # Locale
      if user_info['locale']
        puts "🌍 LOCALE: #{user_info['locale']}"
        Rails.logger.info "🌍 LOCALE: #{user_info['locale']}"
      end
      
      # Organization
      if user_info['organization']
        puts "🏢 ORGANIZATION: #{user_info['organization']}"
        Rails.logger.info "🏢 ORGANIZATION: #{user_info['organization']}"
      end
      
      puts "=" * 100
      puts "✅ Google OAuth data logged successfully"
      puts "=" * 100
      Rails.logger.info "=" * 100
      Rails.logger.info "✅ Google OAuth data logged successfully"
      Rails.logger.info "=" * 100
      
      # Add workaround for missing address data
      puts "🔧 IMPLEMENTING MULTIPLE LOCATION DATA SOLUTIONS:"
      Rails.logger.info "🔧 IMPLEMENTING MULTIPLE LOCATION DATA SOLUTIONS:"
      
      location_info = {}
      
      # Method 1: Try to get location from user's locale
      if user_info['locale']
        location_info['locale'] = user_info['locale']
        puts "🌍 Found locale: #{user_info['locale']}"
        Rails.logger.info "🌍 Found locale: #{user_info['locale']}"
      end
      
      # Method 2: IP-based geolocation (we'll implement this)
      ip_location = get_location_from_ip(@user_ip)
      if ip_location
        location_info['ip_location'] = ip_location
        puts "🌐 IP-based location: #{ip_location.inspect}"
        Rails.logger.info "🌐 IP-based location: #{ip_location.inspect}"
      end
      
      # Method 3: Google Maps Geocoding API (if we have any location data)
      if location_info['locale'] || location_info['ip_location']
        geocoded_location = get_location_from_geocoding(location_info)
        if geocoded_location
          location_info['geocoded_location'] = geocoded_location
          puts "🗺️ Geocoded location: #{geocoded_location.inspect}"
          Rails.logger.info "🗺️ Geocoded location: #{geocoded_location.inspect}"
        end
      end
      
      # Add comprehensive location data
      location_info['location_sources'] = [
        "Google People API (limited)",
        "IP-based geolocation",
        "Google Maps Geocoding API",
        "Browser geolocation (frontend)",
        "User input form (fallback)"
      ]
      
      puts "📋 Comprehensive location data: #{location_info.inspect}"
      Rails.logger.info "📋 Comprehensive location data: #{location_info.inspect}"
      
      # Step 4: Register or Login User
      puts "🔄 Step 4: Registering or logging in user..."
      Rails.logger.info "🔄 Step 4: Registering or logging in user..."
      
      # Check if user exists in any model
      existing_user = find_existing_user(user_info['email'])
      
      if existing_user
        puts "✅ Existing user found: #{existing_user.class.name} - #{existing_user.email}"
        Rails.logger.info "✅ Existing user found: #{existing_user.class.name} - #{existing_user.email}"
        
        # Generate JWT token for existing user
        token = generate_jwt_token(existing_user)
        
        { 
          success: true, 
          user: format_user_response(existing_user), 
          token: token,
          existing_user: true,
          location_data: location_info
        }
      else
        puts "🆕 Creating new buyer user..."
        Rails.logger.info "🆕 Creating new buyer user..."
        
        # Create new buyer user
        new_buyer = create_buyer_user(user_info, location_info)
        
        # Check if this is a missing fields case
        if new_buyer.respond_to?(:missing_fields) && new_buyer.missing_fields.any?
          puts "📝 Missing required fields detected: #{new_buyer.missing_fields.join(', ')}"
          Rails.logger.info "📝 Missing required fields detected: #{new_buyer.missing_fields.join(', ')}"
          
          {
            success: false,
            error: "Missing required fields: #{new_buyer.missing_fields.join(', ')}",
            missing_fields: new_buyer.missing_fields,
            user_data: new_buyer.user_data_for_modal
          }
        elsif new_buyer.persisted?
          puts "✅ New buyer created successfully: #{new_buyer.email}"
          Rails.logger.info "✅ New buyer created successfully: #{new_buyer.email}"
          
          # Send welcome email
          begin
            WelcomeMailer.welcome_email(new_buyer).deliver_now
            puts "✅ Welcome email sent to: #{new_buyer.email}"
            Rails.logger.info "✅ Welcome email sent to: #{new_buyer.email}"
          rescue => e
            puts "❌ Failed to send welcome email: #{e.message}"
            Rails.logger.error "❌ Failed to send welcome email: #{e.message}"
            # Don't fail the registration if email fails
          end
          
          # Generate JWT token for new user
          token = generate_jwt_token(new_buyer)
          
          { 
            success: true, 
            user: format_user_response(new_buyer), 
            token: token,
            new_user: true,
            location_data: location_info
          }
        else
          puts "❌ Failed to create buyer: #{new_buyer.errors.full_messages.join(', ')}"
          Rails.logger.error "❌ Failed to create buyer: #{new_buyer.errors.full_messages.join(', ')}"
          
          # Check if it's a missing required fields error
          missing_fields = determine_missing_fields(new_buyer.errors, user_info)
          
          if missing_fields.any?
            puts "📝 Missing required fields detected: #{missing_fields.join(', ')}"
            Rails.logger.info "📝 Missing required fields detected: #{missing_fields.join(', ')}"
            
            {
              success: false,
              error: "Missing required fields: #{missing_fields.join(', ')}",
              missing_fields: missing_fields,
              user_data: format_user_data_for_modal(user_info, location_info)
            }
          else
            {
              success: false,
              error: "Failed to create user: #{new_buyer.errors.full_messages.join(', ')}"
            }
          end
        end
      end
    rescue => e
      Rails.logger.error "❌ Google OAuth error: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.join("\n")}"
      { success: false, error: "Authentication failed: #{e.message}" }
    end
  end

  # Format user data for the missing fields modal
  def format_user_data_for_modal(user_info, location_info)
    # Extract the best available name from Google
    fullname = extract_best_name(user_info)
    
    {
      fullname: fullname,
      email: user_info['email'],
      profile_picture: fix_google_profile_picture_url(user_info['picture']),
      gender: user_info['gender']&.capitalize,
      birthday: user_info['birthday'],
      # Location data from various sources
      city: location_info.dig('ip_location', 'city') || location_info.dig('address_from_coordinates', 'city'),
      location: location_info.dig('ip_location', 'region_name') || location_info.dig('address_from_coordinates', 'formatted_address'),
      # Any other relevant data
      phone_number: user_info['phone_number'],
      username: generate_unique_username(fullname)
    }
  end

  private

  # Find existing user in any model (Buyer or Seller)
  def find_existing_user(email)
    # Check all user types in order of priority
    # 1. Admin (highest priority)
    admin = Admin.find_by(email: email)
    return admin if admin

    # 2. SalesUser
    sales_user = SalesUser.find_by(email: email)
    return sales_user if sales_user

    # 3. Seller
    seller = Seller.find_by(email: email)
    return seller if seller

    # 4. Buyer (lowest priority)
    buyer = Buyer.find_by(email: email)
    return buyer if buyer

    nil
  end

  # Create new buyer user
  def create_buyer_user(user_info, location_info)
    puts "🆕 Creating buyer with data:"
    Rails.logger.info "🆕 Creating buyer with data:"
    
    # Extract phone number (use the first available phone)
    phone_number = user_info['phone_number'] || user_info['phone_numbers']&.first&.dig('value')
    
    # Clean phone number (remove spaces, +, etc.)
    if phone_number
      phone_number = phone_number.gsub(/\D/, '') # Remove non-digits
      # Remove country code if present (254 for Kenya)
      phone_number = phone_number[3..-1] if phone_number.start_with?('254') && phone_number.length == 12
      phone_number = phone_number[1..-1] if phone_number.start_with?('0') && phone_number.length == 11
    end

    # Generate username from email
    username = user_info['email'].split('@').first.gsub(/[^a-zA-Z0-9_]/, '')
    # Ensure username is unique
    original_username = username
    counter = 1
    while Buyer.exists?(username: username)
      username = "#{original_username}#{counter}"
      counter += 1
    end

    # Get location data
    city = location_info.dig('ip_location', 'city') || location_info.dig('geocoded_location', 'city') || 'Nairobi'
    location = location_info.dig('ip_location', 'formatted_address') || location_info.dig('geocoded_location', 'formatted_address') || city

    # Create buyer attributes
    buyer_attributes = {
      fullname: user_info['name'] || user_info['display_name'],
      email: user_info['email'],
      username: username,
      phone_number: phone_number,
      gender: user_info['gender']&.capitalize || 'Other',
      city: city,
      location: location,
      profile_picture: user_info['picture'],
      provider: 'google',
      uid: user_info['id'],
      # Set default age group (you might want to calculate this from birthday)
      age_group_id: 1, # Default age group - you should set this based on birthday
      # Set default county and sub_county (you might want to map this from location)
      county_id: 1, # Default county - you should map this from location
      sub_county_id: 1, # Default sub_county - you should map this from location
    }

    puts "📋 Buyer attributes: #{buyer_attributes.inspect}"
    Rails.logger.info "📋 Buyer attributes: #{buyer_attributes.inspect}"

    # Check for ALL required fields that would prevent user creation
    missing_fields = []
    
    # Required fields for user creation (based on Buyer model validations)
    missing_fields << 'fullname' if buyer_attributes[:fullname].blank?
    missing_fields << 'phone_number' if buyer_attributes[:phone_number].blank?
    missing_fields << 'gender' if buyer_attributes[:gender].blank?
    missing_fields << 'age_group' if buyer_attributes[:age_group_id].blank?
    
    # If we have missing required fields, return missing fields info for complete registration
    if missing_fields.any?
      puts "📝 Missing required fields detected: #{missing_fields.join(', ')}"
      Rails.logger.info "📝 Missing required fields detected: #{missing_fields.join(', ')}"
      
      # Create a buyer object that will fail validation but contains the missing fields info
      buyer = Buyer.new(buyer_attributes)
      service_instance = self
      buyer.define_singleton_method(:missing_fields) { missing_fields }
      buyer.define_singleton_method(:user_data_for_modal) { service_instance.format_user_data_for_modal(user_info, location_info) }
      return buyer
    end

    # Create the buyer
    buyer = Buyer.new(buyer_attributes)
    
    if buyer.save
      puts "✅ Buyer created successfully: #{buyer.email}"
      Rails.logger.info "✅ Buyer created successfully: #{buyer.email}"
    else
      puts "❌ Buyer creation failed: #{buyer.errors.full_messages.join(', ')}"
      Rails.logger.error "❌ Buyer creation failed: #{buyer.errors.full_messages.join(', ')}"
      
      # Log detailed validation errors for debugging
      puts "🔍 Detailed validation errors:"
      Rails.logger.info "🔍 Detailed validation errors:"
      buyer.errors.each do |field, messages|
        puts "  #{field}: #{messages.join(', ')}"
        Rails.logger.info "  #{field}: #{messages.join(', ')}"
      end
    end

    buyer
  end

  # Generate JWT token for user
  def generate_jwt_token(user)
    puts "🔑 Generating JWT token for #{user.class.name}: #{user.email}"
    Rails.logger.info "🔑 Generating JWT token for #{user.class.name}: #{user.email}"
    
    # Create payload with remember_me for Google OAuth users (30 days)
    payload = {
      email: user.email,
      role: user.user_type || user.class.name.downcase,
      remember_me: true  # Google OAuth users get remember_me by default
    }
    
    # Add appropriate ID field based on user type
    case user
    when Seller
      payload[:seller_id] = user.id
    when Admin
      payload[:admin_id] = user.id
    when SalesUser
      payload[:sales_id] = user.id
    else # Buyer and any other user types
      payload[:user_id] = user.id
    end
    
    # Generate token using JsonWebToken.encode which respects remember_me flag
    token = JsonWebToken.encode(payload)
    
    puts "✅ JWT token generated successfully with remember_me (30 days)"
    Rails.logger.info "✅ JWT token generated successfully with remember_me (30 days)"
    
    token
  end

  # Format user response for frontend
  def format_user_response(user)
    {
      id: user.id,
      email: user.email,
      name: user.fullname,
      role: user.user_type || user.class.name.downcase,
      profile_picture: user.profile_picture,
      phone_number: user.phone_number,
      location: user.location,
      city: user.city,
      username: user.username,
      profile_completion: user.respond_to?(:profile_completion_percentage) ? user.profile_completion_percentage : 0
    }
  end

  # Determine missing required fields from validation errors and user data
  def determine_missing_fields(errors, user_info = nil)
    missing_fields = []
    
    # Check for missing name from Google data
    if user_info && extract_best_name(user_info).blank?
      missing_fields << 'fullname'
      Rails.logger.warn "⚠️ Name missing from Google OAuth data, adding to missing fields"
    end
    
    # Check validation errors
    errors.each do |field, messages|
      case field.to_s
      when 'phone_number'
        missing_fields << 'phone_number' if messages.include?('is required for OAuth users')
      when 'location'
        missing_fields << 'location' if messages.include?("can't be blank")
      when 'city'
        missing_fields << 'city' if messages.include?("can't be blank")
      when 'fullname'
        missing_fields << 'fullname' if messages.include?("can't be blank")
      end
    end
    
    missing_fields.uniq
  end


  # Extract the best available name from Google user info
  # Note: Google OAuth does not provide a separate "username" field
  # We use the actual name fields provided by Google
  def extract_best_name(user_info)
    # Try different name fields in order of preference
    name = user_info['name'] || 
           user_info['display_name'] || 
           user_info['given_name'] || 
           user_info['full_name']
    
    # If we have a name, return it
    return name if name.present? && name.strip.length > 0
    
    # If no name is available, return nil to indicate missing data
    # This will be handled by the frontend as missing data
    Rails.logger.warn "⚠️ No name found in Google user info for email: #{user_info['email']}"
    Rails.logger.warn "⚠️ Note: Google OAuth does not provide a separate username field"
    nil
  end

  # Generate username from email (DEPRECATED - use generate_unique_username instead)
  def generate_username_from_email(email)
    # Extract username from email (part before @)
    username = email.split('@').first
    # Remove any special characters and limit length
    username = username.gsub(/[^a-zA-Z0-9]/, '').downcase
    # Ensure it's at least 3 characters
    username = username.length >= 3 ? username : username + 'user'
    # Limit to 20 characters
    username = username[0..19]
    username
  end

  # Method 2: IP-based geolocation
  def get_location_from_ip(user_ip = nil)
    begin
      puts "🌐 Getting location from IP address..."
      Rails.logger.info "🌐 Getting location from IP address..."
      
      # Use user's IP if provided, otherwise fallback to server IP
      ip_to_check = user_ip || request&.remote_ip
      puts "🌐 Using IP: #{ip_to_check}"
      Rails.logger.info "🌐 Using IP: #{ip_to_check}"
      
      # Use ip-api.com with specific IP
      api_url = if ip_to_check.present? && ip_to_check != '127.0.0.1' && ip_to_check != '::1'
        "http://ip-api.com/json/#{ip_to_check}"
      else
        'http://ip-api.com/json/'
      end
      
      response = HTTParty.get(api_url, timeout: 5)
      
      if response.success?
        ip_data = JSON.parse(response.body)
        location_data = {
          'country' => ip_data['country'],
          'country_code' => ip_data['countryCode'],
          'region' => ip_data['region'],
          'region_name' => ip_data['regionName'],
          'city' => ip_data['city'],
          'zip' => ip_data['zip'],
          'latitude' => ip_data['lat'],
          'longitude' => ip_data['lon'],
          'timezone' => ip_data['timezone'],
          'isp' => ip_data['isp'],
          'ip' => ip_data['query']
        }
        
        puts "✅ IP location data retrieved: #{location_data['city']}, #{location_data['country']}"
        Rails.logger.info "✅ IP location data retrieved: #{location_data['city']}, #{location_data['country']}"
        location_data
      else
        puts "❌ Failed to get IP location: #{response.code}"
        Rails.logger.error "❌ Failed to get IP location: #{response.code}"
        nil
      end
    rescue => e
      puts "❌ IP geolocation error: #{e.message}"
      Rails.logger.error "❌ IP geolocation error: #{e.message}"
      nil
    end
  end

  # Method 3: Google Maps Geocoding API
  def get_location_from_geocoding(location_info)
    begin
      puts "🗺️ Getting location from Google Maps Geocoding API..."
      Rails.logger.info "🗺️ Getting location from Google Maps Geocoding API..."
      
      # Use Google Maps Geocoding API to get more detailed location
      # This requires a Google Maps API key
      if ENV['GOOGLE_MAPS_API_KEY']
        # Build address string from available data
        address_parts = []
        address_parts << location_info['ip_location']['city'] if location_info['ip_location']&.dig('city')
        address_parts << location_info['ip_location']['region_name'] if location_info['ip_location']&.dig('region_name')
        address_parts << location_info['ip_location']['country'] if location_info['ip_location']&.dig('country')
        
        if address_parts.any?
          address_string = address_parts.join(', ')
          puts "📍 Geocoding address: #{address_string}"
          Rails.logger.info "📍 Geocoding address: #{address_string}"
          
          # Use Google Maps Geocoding API
          geocoding_url = "https://maps.googleapis.com/maps/api/geocode/json"
          response = HTTParty.get(geocoding_url, {
            query: {
              address: address_string,
              key: ENV['GOOGLE_MAPS_API_KEY']
            },
            timeout: 10
          })
          
          if response.success?
            geocoding_data = JSON.parse(response.body)
            if geocoding_data['status'] == 'OK' && geocoding_data['results'].any?
              result = geocoding_data['results'].first
              geocoded_location = {
                'formatted_address' => result['formatted_address'],
                'latitude' => result['geometry']['location']['lat'],
                'longitude' => result['geometry']['location']['lng'],
                'place_id' => result['place_id'],
                'address_components' => result['address_components']
              }
              
              puts "✅ Geocoded location: #{geocoded_location['formatted_address']}"
              Rails.logger.info "✅ Geocoded location: #{geocoded_location['formatted_address']}"
              geocoded_location
            else
              puts "❌ Geocoding failed: #{geocoding_data['status']}"
              Rails.logger.error "❌ Geocoding failed: #{geocoding_data['status']}"
              nil
            end
          else
            puts "❌ Geocoding API request failed: #{response.code}"
            Rails.logger.error "❌ Geocoding API request failed: #{response.code}"
            nil
          end
        else
          puts "❌ No address data available for geocoding"
          Rails.logger.error "❌ No address data available for geocoding"
          nil
        end
      else
        puts "❌ Google Maps API key not configured"
        Rails.logger.error "❌ Google Maps API key not configured"
        nil
      end
    rescue => e
      puts "❌ Geocoding error: #{e.message}"
      Rails.logger.error "❌ Geocoding error: #{e.message}"
      nil
    end
  end

  def exchange_code_for_token
    begin
      puts "🔄 EXCHANGING CODE FOR TOKEN..."
      Rails.logger.info "🔄 EXCHANGING CODE FOR TOKEN..."
      
      # For GSI popup authentication, use 'postmessage' as redirect_uri
      redirect_uri = @redirect_uri == 'postmessage' ? 'postmessage' : @redirect_uri
      
      puts "🔄 Exchanging code for token with redirect_uri: #{redirect_uri}"
      Rails.logger.info "🔄 Exchanging code for token with redirect_uri: #{redirect_uri}"
      puts "🔑 Using client_id: #{ENV['GOOGLE_CLIENT_ID']}"
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
      
      puts "📡 Google token response status: #{response.code}"
      Rails.logger.info "📡 Google token response status: #{response.code}"
      puts "📡 Google token response body: #{response.body}"
      Rails.logger.info "📡 Google token response body: #{response.body}"
      
      unless response.success?
        puts "❌ Failed to exchange code for token. Status: #{response.code}, Body: #{response.body}"
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
      puts "👤 Fetching comprehensive user info from Google"
      Rails.logger.info "👤 Fetching comprehensive user info from Google"
      
      # Get basic profile info
      puts "🔄 Getting basic user info..."
      Rails.logger.info "🔄 Getting basic user info..."
      basic_info = get_basic_user_info(access_token)
      return nil unless basic_info
      
      puts "✅ Basic user info obtained: #{basic_info['email']}"
      Rails.logger.info "✅ Basic user info obtained: #{basic_info['email']}"
      
      # Get detailed info from People API
      puts "🔄 Getting detailed user info from People API..."
      Rails.logger.info "🔄 Getting detailed user info from People API..."
      detailed_info = get_detailed_user_info(access_token)
      
      puts "✅ Detailed user info obtained: #{detailed_info ? 'Yes' : 'No'}"
      Rails.logger.info "✅ Detailed user info obtained: #{detailed_info ? 'Yes' : 'No'}"
      
      # Merge the information
      comprehensive_info = basic_info.merge(detailed_info || {})
      
      puts "✅ Successfully obtained comprehensive user info: #{comprehensive_info['email']}"
      Rails.logger.info "✅ Successfully obtained comprehensive user info: #{comprehensive_info['email']}"
      puts "📊 Available data: #{comprehensive_info.keys.join(', ')}"
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
      puts "👤 Fetching basic user info from Google"
      Rails.logger.info "👤 Fetching basic user info from Google"
      
      response = HTTParty.get(GOOGLE_USER_INFO_URL, {
        headers: { 'Authorization' => "Bearer #{access_token}" }
      })
      
      puts "📡 Google user info response status: #{response.code}"
      Rails.logger.info "📡 Google user info response status: #{response.code}"
      puts "📡 Google user info response body: #{response.body}"
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
      puts "👤 Fetching detailed user info from Google People API"
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
        'biographies',    # About/bio information
        'residences',     # Home addresses
        'locations'       # Location information
      ].join(',')
      
      response = HTTParty.get(GOOGLE_PEOPLE_API_URL, {
        headers: { 'Authorization' => "Bearer #{access_token}" },
        query: { personFields: person_fields }
      })
      
      puts "📡 Google People API response status: #{response.code}"
      Rails.logger.info "📡 Google People API response status: #{response.code}"
      puts "📡 Google People API response body: #{response.body}"
      Rails.logger.info "📡 Google People API response body: #{response.body}"
      
      unless response.success?
        puts "⚠️ Failed to get detailed user info from People API. Status: #{response.code}, Body: #{response.body}"
        Rails.logger.warn "⚠️ Failed to get detailed user info from People API. Status: #{response.code}, Body: #{response.body}"
        puts "⚠️ This might be because People API is not enabled in Google Cloud Console"
        Rails.logger.warn "⚠️ This might be because People API is not enabled in Google Cloud Console"
        puts "⚠️ Or the user has not granted permission for these scopes"
        Rails.logger.warn "⚠️ Or the user has not granted permission for these scopes"
        return {}
      end
      
      detailed_info = JSON.parse(response.body)
      puts "✅ Successfully obtained detailed user info from People API"
      Rails.logger.info "✅ Successfully obtained detailed user info from People API"
      puts "📊 People API data keys: #{detailed_info.keys.join(', ')}"
      Rails.logger.info "📊 People API data keys: #{detailed_info.keys.join(', ')}"
      
      # Log what data is actually available
      puts "🔍 DETAILED PEOPLE API DATA ANALYSIS:"
      Rails.logger.info "🔍 DETAILED PEOPLE API DATA ANALYSIS:"
      detailed_info.each do |key, value|
        if value.is_a?(Array)
          puts "  #{key}: #{value.length} items"
          Rails.logger.info "  #{key}: #{value.length} items"
        else
          puts "  #{key}: #{value.class} - #{value.inspect[0..100]}..."
          Rails.logger.info "  #{key}: #{value.class} - #{value.inspect[0..100]}..."
        end
      end
      
      # CRITICAL: Check if this is a Google People API limitation
      puts "🚨 GOOGLE PEOPLE API ADDRESS LIMITATION CHECK:"
      Rails.logger.info "🚨 GOOGLE PEOPLE API ADDRESS LIMITATION CHECK:"
      puts "📋 Requested person fields: #{person_fields}"
      Rails.logger.info "📋 Requested person fields: #{person_fields}"
      puts "📋 Available fields in response: #{detailed_info.keys.join(', ')}"
      Rails.logger.info "📋 Available fields in response: #{detailed_info.keys.join(', ')}"
      
      # Check if addresses field exists but is empty
      if detailed_info.key?('addresses')
        puts "✅ 'addresses' field exists in response"
        Rails.logger.info "✅ 'addresses' field exists in response"
        if detailed_info['addresses'].nil? || detailed_info['addresses'].empty?
          puts "❌ 'addresses' field is empty - This is a Google People API limitation!"
          Rails.logger.info "❌ 'addresses' field is empty - This is a Google People API limitation!"
          puts "💡 Google People API often doesn't return address data even when it exists in the profile"
          Rails.logger.info "💡 Google People API often doesn't return address data even when it exists in the profile"
        end
      else
        puts "❌ 'addresses' field not found in response"
        Rails.logger.info "❌ 'addresses' field not found in response"
        puts "🚨 GOOGLE PEOPLE API ADDRESS LIMITATION CONFIRMED!"
        Rails.logger.info "🚨 GOOGLE PEOPLE API ADDRESS LIMITATION CONFIRMED!"
        puts "📋 This is a known issue with Google People API - it often doesn't return address data"
        Rails.logger.info "📋 This is a known issue with Google People API - it often doesn't return address data"
        puts "💡 Alternative solutions:"
        Rails.logger.info "💡 Alternative solutions:"
        puts "   1. Use Google Maps Geocoding API for address data"
        Rails.logger.info "   1. Use Google Maps Geocoding API for address data"
        puts "   2. Request address data directly from user in your app"
        Rails.logger.info "   2. Request address data directly from user in your app"
        puts "   3. Use Google Places API for location services"
        Rails.logger.info "   3. Use Google Places API for location services"
      end
      
      # Log specific data that should be available
      if detailed_info['phoneNumbers']&.any?
        Rails.logger.info "📞 Phone numbers found: #{detailed_info['phoneNumbers'].length}"
      else
        Rails.logger.info "📞 No phone numbers found in People API response"
      end
      
      # Check for addresses in multiple possible fields
      puts "🔍 CHECKING FOR ADDRESS DATA IN PEOPLE API RESPONSE:"
      Rails.logger.info "🔍 CHECKING FOR ADDRESS DATA IN PEOPLE API RESPONSE:"
      
      # Check addresses field
      if detailed_info['addresses']&.any?
        puts "📍 Addresses found: #{detailed_info['addresses'].length}"
        Rails.logger.info "📍 Addresses found: #{detailed_info['addresses'].length}"
        detailed_info['addresses'].each_with_index do |address, index|
          puts "  #{index + 1}. #{address.inspect}"
          Rails.logger.info "  #{index + 1}. #{address.inspect}"
        end
      else
        puts "📍 No 'addresses' field found"
        Rails.logger.info "📍 No 'addresses' field found"
      end
      
      # Check residences field
      if detailed_info['residences']&.any?
        puts "🏠 Residences found: #{detailed_info['residences'].length}"
        Rails.logger.info "🏠 Residences found: #{detailed_info['residences'].length}"
        detailed_info['residences'].each_with_index do |residence, index|
          puts "  #{index + 1}. #{residence.inspect}"
          Rails.logger.info "  #{index + 1}. #{residence.inspect}"
        end
      else
        puts "🏠 No 'residences' field found"
        Rails.logger.info "🏠 No 'residences' field found"
      end
      
      # Check locations field
      if detailed_info['locations']&.any?
        puts "🌍 Locations found: #{detailed_info['locations'].length}"
        Rails.logger.info "🌍 Locations found: #{detailed_info['locations'].length}"
        detailed_info['locations'].each_with_index do |location, index|
          puts "  #{index + 1}. #{location.inspect}"
          Rails.logger.info "  #{index + 1}. #{location.inspect}"
        end
      else
        puts "🌍 No 'locations' field found"
        Rails.logger.info "🌍 No 'locations' field found"
      end
      
      # Check if any address-related data exists
      address_keys = detailed_info.keys.select { |key| key.downcase.include?('address') || key.downcase.include?('location') || key.downcase.include?('residence') }
      if address_keys.any?
        puts "🔍 Found address-related keys: #{address_keys.join(', ')}"
        Rails.logger.info "🔍 Found address-related keys: #{address_keys.join(', ')}"
        address_keys.each do |key|
          puts "  #{key}: #{detailed_info[key].inspect}"
          Rails.logger.info "  #{key}: #{detailed_info[key].inspect}"
        end
      else
        puts "❌ NO ADDRESS DATA FOUND - This is the issue!"
        Rails.logger.info "❌ NO ADDRESS DATA FOUND - This is the issue!"
        puts "❌ The Google People API is not returning address data despite having addresses in Google profile"
        Rails.logger.info "❌ The Google People API is not returning address data despite having addresses in Google profile"
      end
      
      if detailed_info['genders']&.any?
        Rails.logger.info "⚧ Gender found: #{detailed_info['genders'].first['value']}"
      else
        Rails.logger.info "⚧ No gender found in People API response"
      end
      
      # Extract and format the detailed information
      extracted_info = extract_detailed_info(detailed_info)
      Rails.logger.info "📊 Extracted detailed info keys: #{extracted_info.keys.join(', ')}"
      Rails.logger.info "📊 Extracted phone: #{extracted_info['phone_number'] || 'Not found'}"
      Rails.logger.info "📊 Extracted gender: #{extracted_info['gender'] || 'Not found'}"
      Rails.logger.info "📊 Extracted address: #{extracted_info['address'] ? 'Found' : 'Not found'}"
      extracted_info
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
    
    # Log all available Google user data for debugging
    Rails.logger.info "📊 Complete Google user info structure:"
    user_info.each do |key, value|
      Rails.logger.info "   #{key}: #{value.inspect}"
    end
    
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
      update_attributes = {
        provider: provider,
        uid: uid,
        oauth_token: user_info['access_token'],
        oauth_expires_at: Time.current + 1.hour # Google tokens typically last 1 hour
      }
      
      # Update profile picture if user doesn't have one and Google provides one
      if user.respond_to?(:profile_picture) && user.profile_picture.blank? && user_info['picture'].present?
        fixed_profile_picture = fix_google_profile_picture_url(user_info['picture'])
        update_attributes[:profile_picture] = fixed_profile_picture
        Rails.logger.info "📸 Updating profile picture for existing user: #{user.email}"
        Rails.logger.info "📸 Fixed profile picture URL: #{fixed_profile_picture}"
      elsif user.respond_to?(:profile_picture) && user.profile_picture.present?
        Rails.logger.info "📸 User already has profile picture, keeping existing: #{user.email}"
      end
      
      # Update fullname if user doesn't have one and Google provides one
      if user.respond_to?(:fullname) && user.fullname.blank? && (user_info['display_name'].present? || user_info['name'].present?)
        update_attributes[:fullname] = user_info['display_name'] || user_info['name']
        Rails.logger.info "👤 Updating fullname for existing user: #{user.email}"
      elsif user.respond_to?(:fullname) && user.fullname.present?
        Rails.logger.info "👤 User already has fullname, keeping existing: #{user.email}"
      end
      
      # Update phone number if user doesn't have one and Google provides one
      if user.respond_to?(:phone_number) && user.phone_number.blank? && user_info['phone_number'].present?
        update_attributes[:phone_number] = user_info['phone_number']
        Rails.logger.info "📞 Updating phone number for existing user: #{user.email}"
      elsif user.respond_to?(:phone_number) && user.phone_number.present?
        Rails.logger.info "📞 User already has phone number, keeping existing: #{user.email}"
      end
      
      # Update location if user doesn't have one and Google provides one
      if user.respond_to?(:location) && user.location.blank? && user_info['address'].present?
        update_attributes[:location] = user_info['address']
        Rails.logger.info "📍 Updating location for existing user: #{user.email}"
      elsif user.respond_to?(:location) && user.location.present?
        Rails.logger.info "📍 User already has location, keeping existing: #{user.email}"
      end
      
      # Update city if user doesn't have one and Google provides one
      if user.respond_to?(:city) && user.city.blank? && user_info['city'].present?
        update_attributes[:city] = user_info['city']
        Rails.logger.info "🏙️ Updating city for existing user: #{user.email}"
      elsif user.respond_to?(:city) && user.city.present?
        Rails.logger.info "🏙️ User already has city, keeping existing: #{user.email}"
      end
      
      # Update zipcode if user doesn't have one and Google provides one
      if user.respond_to?(:zipcode) && user.zipcode.blank? && user_info['zipcode'].present?
        update_attributes[:zipcode] = user_info['zipcode']
        Rails.logger.info "📮 Updating zipcode for existing user: #{user.email}"
      elsif user.respond_to?(:zipcode) && user.zipcode.present?
        Rails.logger.info "📮 User already has zipcode, keeping existing: #{user.email}"
      end
      
      # Update gender if user doesn't have one and Google provides one
      if user.respond_to?(:gender) && user.gender.blank? && user_info['gender'].present?
        update_attributes[:gender] = user_info['gender']
        Rails.logger.info "⚧ Updating gender for existing user: #{user.email}"
      elsif user.respond_to?(:gender) && user.gender.present?
        Rails.logger.info "⚧ User already has gender, keeping existing: #{user.email}"
      end
      
      # Update age group if user doesn't have one and Google provides birthday
      if user.respond_to?(:age_group_id) && user.age_group_id.blank? && (user_info['birthday'].present? || user_info['birth_date'].present?)
        birthday = user_info['birthday'] || user_info['birth_date']
        age_group_id = calculate_age_group_from_birthday(birthday)
        if age_group_id.present?
          update_attributes[:age_group_id] = age_group_id
          Rails.logger.info "🎂 Updating age group for existing user: #{user.email}"
        end
      elsif user.respond_to?(:age_group_id) && user.age_group_id.present?
        Rails.logger.info "🎂 User already has age group, keeping existing: #{user.email}"
      end
      
      Rails.logger.info "🔄 Updating existing user with attributes: #{update_attributes.keys.join(', ')}"
      user.update!(update_attributes)
    end
  end

  def create_new_oauth_user(user_info, provider, uid)
    # Create as buyer by default for Google OAuth users
    phone_number = extract_phone_number(user_info)
    
    # If no phone number from Google, leave blank for user to complete
    # We'll handle this in the frontend with a completion modal
    
    # Extract comprehensive user information
    fullname = extract_best_name(user_info)
    profile_picture = fix_google_profile_picture_url(user_info['picture'] || user_info['photo_url'])
    
    Rails.logger.info "📸 Profile picture from Google: #{profile_picture.present? ? 'Available' : 'Not available'}"
    Rails.logger.info "📸 Fixed profile picture URL: #{profile_picture}" if profile_picture.present?
    Rails.logger.info "👤 Full name from Google: #{fullname || 'MISSING - will be required in frontend'}"
    
    # Extract location information
    location_info = extract_location_info(user_info)
    
    # Ensure we have a valid age group
    age_group_id = calculate_age_group(user_info)
    
    # Ensure we have a valid gender
    gender = extract_gender(user_info)
    
    user_attributes = {
      fullname: fullname,
      email: user_info['email'],
      username: generate_unique_username(fullname),
      phone_number: phone_number,
      provider: provider,
      uid: uid,
      oauth_token: user_info['access_token'],
      oauth_expires_at: Time.current + 1.hour,
      age_group_id: age_group_id,
      gender: gender,
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
    Rails.logger.info "📞 Phone number being stored: #{phone_number || 'Not available'}"
    Rails.logger.info "⚧ Gender being stored: #{gender || 'Not available'}"
    Rails.logger.info "📍 Location being stored: #{location_info[:location] || 'Not available'}"
    Rails.logger.info "🏙️ City being stored: #{location_info[:city] || 'Not available'}"
    Rails.logger.info "📮 Zipcode being stored: #{location_info[:zipcode] || 'Not available'}"
    
    # For OAuth users, we'll allow incomplete data and let user complete it later
    # Set defaults for required fields that are missing
    age_group_id = age_group_id.present? ? age_group_id : AgeGroup.first&.id || 1
    gender = gender.present? ? gender : 'Male'
    
    # Update attributes with defaults
    user_attributes[:age_group_id] = age_group_id
    user_attributes[:gender] = gender
    
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
    
    while Buyer.exists?(username: username) || Seller.exists?(username: username)
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
    
    while Buyer.exists?(username: username) || Seller.exists?(username: username)
      username = "#{base_username}#{counter}"
      counter += 1
    end
    
    username
  end

  def generate_placeholder_phone
    # Generate a placeholder phone number that won't conflict
    # Use 10-digit format (Kenya mobile format: 07XXXXXXXX)
    loop do
      phone = "07#{rand(10000000..99999999)}"
      break phone unless Buyer.exists?(phone_number: phone) || Seller.exists?(phone_number: phone)
    end
  end

  def extract_phone_number(user_info)
    # Try to get phone number from People API data
    phone_number = user_info['phone_number']
    
    if phone_number.present?
      # Clean and format the phone number
      cleaned_phone = phone_number.gsub(/[^\d+]/, '')
      
      # Validate phone number format
      if cleaned_phone.start_with?('+')
        # International format - convert to 10-digit format for Kenya
        if cleaned_phone.start_with?('+254')
          # Remove +254 and keep the last 10 digits
          local_number = cleaned_phone[4..-1]
          if local_number.length == 9 && local_number.start_with?('7')
            "0#{local_number}"
          else
            Rails.logger.warn "❌ Invalid Kenya phone number format: #{cleaned_phone}"
            nil
          end
        else
          Rails.logger.warn "❌ Non-Kenya international number: #{cleaned_phone}"
          nil
        end
      elsif cleaned_phone.length == 10 && cleaned_phone.start_with?('0')
        # Already in correct format
        cleaned_phone
      elsif cleaned_phone.length == 9 && cleaned_phone.start_with?('7')
        # Add leading zero
        "0#{cleaned_phone}"
      else
        Rails.logger.warn "❌ Invalid phone number format: #{cleaned_phone}"
        nil
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
    when 'other', 'o'
      'Other'
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
          AgeGroup.find_by(name: '18-25')&.id || AgeGroup.first&.id || 1
        when 26..35
          AgeGroup.find_by(name: '26-35')&.id || AgeGroup.first&.id || 1
        when 36..45
          AgeGroup.find_by(name: '36-45')&.id || AgeGroup.first&.id || 1
        when 46..55
          AgeGroup.find_by(name: '46-55')&.id || AgeGroup.first&.id || 1
        when 56..65
          AgeGroup.find_by(name: '56-65')&.id || AgeGroup.first&.id || 1
        else
          AgeGroup.find_by(name: '65+')&.id || AgeGroup.first&.id || 1
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

  def calculate_age_group_from_birthday(birthday)
    return nil unless birthday.present?
    
    begin
      # Parse birthday - handle different formats
      birth_date = if birthday.is_a?(String)
        Date.parse(birthday)
      else
        birthday
      end
      
      age = Date.current.year - birth_date.year
      age -= 1 if Date.current < birth_date + age.years
      
      case age
      when 18..25
        AgeGroup.find_by(name: '18-25')&.id || AgeGroup.first&.id || 1
      when 26..35
        AgeGroup.find_by(name: '26-35')&.id || AgeGroup.first&.id || 1
      when 36..45
        AgeGroup.find_by(name: '36-45')&.id || AgeGroup.first&.id || 1
      when 46..55
        AgeGroup.find_by(name: '46-55')&.id || AgeGroup.first&.id || 1
      when 56..65
        AgeGroup.find_by(name: '56-65')&.id || AgeGroup.first&.id || 1
      else
        AgeGroup.find_by(name: '65+')&.id || AgeGroup.first&.id || 1
      end
    rescue => e
      Rails.logger.error "❌ Error calculating age from birthday #{birthday}: #{e.message}"
      AgeGroup.first&.id || 1
    end
  end

  private

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
