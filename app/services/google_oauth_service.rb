# app/services/google_oauth_service.rb
require 'httparty'

class GoogleOauthService
  GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'
  GOOGLE_USER_INFO_URL = 'https://www.googleapis.com/oauth2/v2/userinfo'
  GOOGLE_PEOPLE_API_URL = 'https://people.googleapis.com/v1/people/me'
  
  def initialize(auth_code, redirect_uri, user_ip = nil, role = 'Buyer', location_data = nil, is_registration = false, device_hash = nil)
    Rails.logger.info "🔧 GoogleOauthService#initialize called with:"
    Rails.logger.info "  - auth_code: #{auth_code ? auth_code[0..10] + '...' : 'nil'}"
    Rails.logger.info "  - redirect_uri: #{redirect_uri}"
    Rails.logger.info "  - user_ip: #{user_ip}"
    Rails.logger.info "  - role: #{role.inspect} (#{role.class})"
    Rails.logger.info "  - location_data: #{location_data.inspect}"
    Rails.logger.info "  - is_registration: #{is_registration.inspect}"
    Rails.logger.info "  - device_hash: #{device_hash ? device_hash[0..10] + '...' : 'nil'}"
    
    @auth_code = auth_code
    @redirect_uri = redirect_uri
    @user_ip = user_ip
    @role = role
    @location_data = location_data
    @is_registration = is_registration
    @device_hash = device_hash
    
    Rails.logger.info "✅ GoogleOauthService initialized with @role = #{@role.inspect}, @is_registration = #{@is_registration.inspect}"
  end

  def authenticate
    begin
      Rails.logger.info "🚀 [GoogleOauthService] Starting authentication process"
      Rails.logger.info "   Role: #{@role}"
      Rails.logger.info "   Registration: #{@is_registration}"
      Rails.logger.info "   IP: #{@user_ip}"
      Rails.logger.info "   Location data: #{@location_data ? 'present' : 'none'}"

      # Step 1: Exchange authorization code for access token
      Rails.logger.info "🔑 [GoogleOauthService] Step 1: Exchanging code for access token"
      access_token = exchange_code_for_token
      
      unless access_token
        Rails.logger.error "❌ [GoogleOauthService] Failed to get access token"
        Rails.logger.error "   This usually means the authorization code is invalid or expired"
        return { success: false, error: 'Failed to get access token' }
      end

      Rails.logger.info "✅ [GoogleOauthService] Access token obtained successfully"

      # Step 2: Get comprehensive user info from Google
      Rails.logger.info "👤 [GoogleOauthService] Step 2: Getting user info from Google"
      user_info = get_comprehensive_user_info(access_token)
      
      unless user_info
        Rails.logger.error "❌ [GoogleOauthService] Failed to get user info"
        Rails.logger.error "   This could be due to invalid access token or Google API issues"
        return { success: false, error: 'Failed to get user info' }
      end

      Rails.logger.info "✅ [GoogleOauthService] User info obtained successfully"
      Rails.logger.info "   Email: #{user_info['email']}"
      Rails.logger.info "   Name: #{user_info['name'] || 'not provided'}"
      Rails.logger.info "   Has phone: #{user_info['phone_number'].present?}"
      
      # Step 3: Process location data
      Rails.logger.info "📍 [GoogleOauthService] Step 3: Processing location data"

      # Try to get location from multiple sources
      location_info = {}
      
      # Method 1: Try to get location from user's locale
      if user_info['locale']
        location_info['locale'] = user_info['locale']
      end
      
      # Method 2: IP-based geolocation with county/sub-county mapping
      ip_location = get_location_from_ip(@user_ip)
      if ip_location
        # Enhance IP location with county/sub-county mapping
        enhanced_location = enhance_location_with_county_mapping(ip_location)
        location_info['ip_location'] = enhanced_location
      end
      
      # Method 3: Google Maps Geocoding API (if we have any location data)
      if location_info['locale'] || location_info['ip_location']
        geocoded_location = get_location_from_geocoding(location_info)
        if geocoded_location
          # Enhance geocoded location with county/sub-county mapping
          enhanced_geocoded = enhance_location_with_county_mapping(geocoded_location)
          location_info['geocoded_location'] = enhanced_geocoded
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
      
      # Check for existing user
      Rails.logger.info "🔍 [GoogleOauthService] Step 4: Checking for existing user"
      Rails.logger.info "   Looking up user by email: #{user_info['email']}"

      # Check if user exists in any model
      existing_user = find_existing_user(user_info['email'])
      
      if existing_user
        Rails.logger.info "✅ [GoogleOauthService] Existing #{existing_user.class.name} found: #{existing_user.email}"
        Rails.logger.info "   User ID: #{existing_user.id}"
        Rails.logger.info "   Blocked: #{existing_user.respond_to?(:blocked?) ? existing_user.blocked? : 'N/A'}"
        Rails.logger.info "   Deleted: #{existing_user.respond_to?(:deleted?) ? existing_user.deleted? : 'N/A'}"
        
        # Block login if the user is soft-deleted
        if (existing_user.is_a?(Buyer) || existing_user.is_a?(Seller)) && existing_user.deleted?
          Rails.logger.warn "🚫 Login blocked: Account deleted for #{existing_user.email}"
          return {
            success: false,
            error: 'Your account has been deleted. Please contact support.'
          }
        end

        # Block login if the user is blocked (both Buyer and Seller)
        if existing_user.is_a?(Buyer) && existing_user.blocked?
          Rails.logger.warn "🚫 Login blocked: Account blocked for buyer #{existing_user.email}"
          return {
            success: false,
            error: 'Your account has been blocked. Please contact support.'
          }
        end

        if existing_user.is_a?(Seller) && existing_user.blocked?
          Rails.logger.warn "🚫 Login blocked: Account blocked for seller #{existing_user.email}"
          return {
            success: false,
            error: 'Your account has been blocked. Please contact support.'
          }
        end
        
        # During registration, check if roles match
        if @is_registration
          requested_role = @role.to_s.downcase.strip
          existing_role = existing_user.is_a?(Seller) ? 'seller' : 'buyer'
          
          Rails.logger.info "Registration mode: existing #{existing_role} account found (requested: #{requested_role})"
          
          # If roles match, sign them in directly
          if requested_role == existing_role
            Rails.logger.info "Roles match - signing in existing #{existing_role} user"
            # Update existing user with fresh Google data
            link_oauth_to_existing_user(existing_user, 'google', user_info['id'], user_info)
            
            # Generate JWT token for existing user
            token = generate_jwt_token(existing_user)
            user_response = format_user_response(existing_user)
            
            return { 
              success: true, 
              user: user_response, 
              token: token,
              existing_user: true,
              location_data: location_info
            }
          end
          
          # Roles don't match - return error
          Rails.logger.warn "Role mismatch: existing #{existing_role} account found (requested: #{requested_role})"
          return {
            success: false,
            error: "This email is already registered as a #{existing_role.capitalize}. Please sign in with your existing account or use a different email address.",
            role_mismatch: true,
            existing_role: existing_role.capitalize,
            requested_role: requested_role.capitalize
          }
        end
        
        # For existing users in login mode, or when role matches during registration, allow login
        Rails.logger.info "Allowing login for existing user: #{existing_user.email}"

        # Update existing user with fresh Google data (profile picture, phone number, etc.)
        link_oauth_to_existing_user(existing_user, 'google', user_info['id'], user_info)
        
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
        Rails.logger.info "🆕 [GoogleOauthService] No existing user found - attempting to create new user"
        Rails.logger.info "=" * 80

        # Try to create a new user - this will return missing fields if any are missing
        Rails.logger.info "👥 [GoogleOauthService] Step 5: Creating new user"
        
        # In login mode, always create a buyer account if user doesn't exist
        # In registration mode, use the requested role
        if @is_registration
          user_type = determine_user_type_from_context
          Rails.logger.info "   Registration mode - Requested role: #{@role}"
          Rails.logger.info "   Determined user type: #{user_type}"
        else
          # Login mode - always create buyer account for new users
          user_type = 'buyer'
          Rails.logger.info "   Login mode - Creating buyer account for new user"
        end
        
        # Check for role mismatch during registration (user creation)
        # This should only happen when creating new accounts, not during login
        requested_role = @role || 'Buyer'
        Rails.logger.info "🔍 User creation attempt for role: #{user_type}"
        
        if user_type == 'buyer'
          create_buyer_user(user_info, location_info, @device_hash)
        elsif user_type == 'seller'
          create_seller_user(user_info, location_info, @device_hash)
        else
          Rails.logger.error "Unknown user type: #{user_type}"
          {
            success: false,
            error: "Invalid user type. Please try again.",
            not_registered: true,
            user_data: format_user_data_for_modal(user_info, location_info)
          }
        end
      end
    rescue => e
      Rails.logger.error "Google OAuth error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      { success: false, error: "Authentication failed: #{e.message}" }
    end
  end

  # Format user data for the missing fields modal
  def format_user_data_for_modal(user_info, location_info)
    # Extract the best available name from Google
    fullname = extract_best_name(user_info)
    
    # Extract and fix profile picture URL from Google
    profile_picture = nil
    if user_info['picture'].present?
      profile_picture = fix_google_profile_picture_url(user_info['picture'])
    elsif user_info['photo_url'].present?
      profile_picture = fix_google_profile_picture_url(user_info['photo_url'])
    elsif user_info['image'].present?
      profile_picture = fix_google_profile_picture_url(user_info['image'])
    end
    
    # Extract comprehensive location data - no fallbacks, only use actual detected data
    city = location_info.dig('ip_location', 'city') || 
           location_info.dig('geocoded_location', 'city') || 
           location_info.dig('address_from_coordinates', 'city')
    
    # Fix city name based on county mapping if we have better county information
    city = fix_city_based_on_county(city, location_info)
    
    location = location_info.dig('ip_location', 'formatted_address') || 
               location_info.dig('geocoded_location', 'formatted_address') || 
               location_info.dig('address_from_coordinates', 'formatted_address')
    
    # Extract phone number from multiple sources
    phone_number = user_info['phone_number'] || 
                   user_info['phone_numbers']&.first&.dig('value') ||
                   nil
    
    # Clean phone number if present
    if phone_number.present?
      phone_number = phone_number.gsub(/\D/, '') # Remove non-digits
      # Remove country code if present (254 for Kenya)
      phone_number = phone_number[3..-1] if phone_number.start_with?('254') && phone_number.length == 12
      phone_number = phone_number[1..-1] if phone_number.start_with?('0') && phone_number.length == 11
      phone_number = "0#{phone_number}" if phone_number.length == 9 && phone_number.start_with?('7')
    end
    
    # Extract gender with proper formatting
    gender = user_info['gender']&.capitalize || 'Male'
    
    # Extract birthday and calculate age group
    birthday = user_info['birthday'] || user_info['birth_date']
    age_group_id = calculate_age_group(user_info) if birthday.present?
    
    # Generate username from name
    username = generate_unique_username(fullname)
    
    # For seller-specific data - don't auto-set enterprise_name, let user set it
    business_type = 'Other' # Default business type
    
    {
      # Basic user info
      fullname: fullname,
      email: user_info['email'],
      username: username,
      profile_picture: profile_picture,
      gender: gender,
      birthday: birthday,
      age_group_id: age_group_id,
      
      # Contact info
      phone_number: phone_number,
      
      # Location data - don't auto-set, let user set it themselves
      # city: city,
      # location: location,
      # county_id: location_info.dig('ip_location', 'county_id'),
      # sub_county_id: location_info.dig('ip_location', 'sub_county_id'),
      
      # Seller-specific data - don't auto-set enterprise_name, let user set it
      # enterprise_name: enterprise_name,
      business_type: business_type,
      
      # Additional Google data
      given_name: user_info['given_name'],
      family_name: user_info['family_name'],
      display_name: user_info['display_name'],
      
      # Location sources for debugging
      location_sources: location_info['location_sources'] || []
    }
  end

  private

  # Determine user type from OAuth context
  def determine_user_type_from_context
    # Use the role parameter passed during initialization
    # Default to 'buyer' only if role is nil or empty
    Rails.logger.info "🔍 Determining user type - @role: #{@role.inspect}"
    Rails.logger.info "🔍 @role.class: #{@role.class}"
    Rails.logger.info "🔍 @role.nil?: #{@role.nil?}"
    Rails.logger.info "🔍 @role.empty?: #{@role.empty? if @role.respond_to?(:empty?)}"
    
    # Convert to string and downcase for consistency
    role_string = @role.to_s.downcase
    Rails.logger.info "🔍 Role string: #{role_string}"
    
    return 'buyer' if role_string.nil? || role_string.empty?
    Rails.logger.info "🔍 User type determined as: #{role_string}"
    role_string
  end

  # Create new seller user
  def create_seller_user(user_info, location_info, device_hash = nil)
    Rails.logger.info "Creating seller with data"
    
    # Check if user already exists as a different role (registration conflict)
    email = user_info['email']
    existing_buyer = Buyer.find_by(email: email)
    if existing_buyer
      Rails.logger.error "❌ Registration conflict: User #{email} already exists as a Buyer"
      return {
        success: false,
        error: "This email is already registered as a Buyer. Please sign in with your existing account or use a different email address.",
        role_mismatch: true,
        existing_role: 'Buyer',
        requested_role: 'Seller'
      }
    end
    
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
    while Seller.exists?(username: username)
      username = "#{original_username}#{counter}"
      counter += 1
    end

    # Get location data
    city = location_info.dig('ip_location', 'city') || location_info.dig('geocoded_location', 'city')
    location = location_info.dig('ip_location', 'formatted_address') || location_info.dig('geocoded_location', 'formatted_address') 
    # Extract and fix profile picture URL from Google
    profile_picture = nil
    if user_info['picture'].present?
      profile_picture = fix_google_profile_picture_url(user_info['picture'])
    elsif user_info['photo_url'].present?
      profile_picture = fix_google_profile_picture_url(user_info['photo_url'])
    elsif user_info['image'].present?
      profile_picture = fix_google_profile_picture_url(user_info['image'])
    end

    # Don't auto-set enterprise_name - let user set it themselves in the completion modal
    # Generate unique enterprise name
    # base_enterprise_name = user_info['name'] || user_info['display_name'] || 'Business'
    # enterprise_name = generate_unique_enterprise_name(base_enterprise_name)

    # Create seller attributes
    seller_attributes = {
      fullname: user_info['name'] || user_info['display_name'],
      email: user_info['email'],
      username: username,
      phone_number: phone_number,
      phone_provided_by_oauth: phone_number.present?,
      gender: user_info['gender']&.capitalize || 'Other',
      profile_picture: profile_picture,
      provider: 'google',
      uid: user_info['id'],
      # Don't auto-set enterprise_name - let user set it themselves
      # enterprise_name: enterprise_name,
      age_group_id: calculate_age_group(user_info)
    }
    
    # Don't auto-set location fields - let user set them themselves
    # User will complete missing fields via modal
    # seller_attributes[:city] = city if city.present?
    # seller_attributes[:location] = location if location.present? && location != "Location to be updated"
    
    # Don't auto-set county/sub_county - let user set them themselves
    # detected_county_id = location_info.dig('ip_location', 'county_id')
    # detected_sub_county_id = location_info.dig('ip_location', 'sub_county_id')
    # seller_attributes[:county_id] = detected_county_id if detected_county_id.present?
    # seller_attributes[:sub_county_id] = detected_sub_county_id if detected_sub_county_id.present?

    Rails.logger.info "Seller attributes: #{seller_attributes.inspect}"

    # Check for missing fields that need to be collected later
    missing_fields = []
    
    # Track missing fields for the completion modal
    missing_fields << 'fullname' if seller_attributes[:fullname].blank?
    missing_fields << 'enterprise_name' if seller_attributes[:enterprise_name].blank?
    missing_fields << 'age_group_id' if seller_attributes[:age_group_id].blank?
    missing_fields << 'county_id' if seller_attributes[:county_id].blank?
    missing_fields << 'sub_county_id' if seller_attributes[:sub_county_id].blank?
    missing_fields << 'location' if seller_attributes[:location].blank?
    
    # Don't set default values for county, sub_county, or location
    # User will complete these via the modal
    # Only keep actual detected values, remove any placeholder/default values
    if seller_attributes[:location] == "Location to be updated" || seller_attributes[:location].blank?
      seller_attributes.delete(:location)
    end
    
    # Remove county/sub_county if they're defaults (we'll let user choose)
    # Only keep if they were actually detected from location data
    # (The location_info should only have real detected values)
    
    if seller_attributes[:age_group_id].blank?
      # Default to first age group if not calculated (this is less critical)
      default_age_group = AgeGroup.first
      if default_age_group
        seller_attributes[:age_group_id] = default_age_group.id
        Rails.logger.info "Using default age group: #{default_age_group.id}"
      end
    end

    # Create the seller
    seller = Seller.new(seller_attributes)
    
    # Capture device hash if provided for guest click association
    if device_hash.present?
      seller.device_hash_for_association = device_hash
    end
    
    # Try to save, with retry logic for sequence sync issues
    save_success = false
    retry_count = 0
    max_retries = 2
    
    begin
      save_success = seller.save
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => e
      if e.message.include?('vendors_pkey') || e.message.include?('duplicate key value') ||
         (e.respond_to?(:cause) && e.cause.is_a?(PG::UniqueViolation) && e.cause.message.include?('vendors_pkey'))
        Rails.logger.warn "⚠️ Sequence sync issue detected for sellers table, attempting to fix..."
        
        # Fix the sequence
        ActiveRecord::Base.connection.execute(
          "SELECT setval('vendors_id_seq', COALESCE((SELECT MAX(id) FROM sellers), 0) + 1, false);"
        )
        
        retry_count += 1
        if retry_count <= max_retries
          Rails.logger.info "🔄 Retrying seller creation after sequence fix (attempt #{retry_count})"
          seller = Seller.new(seller_attributes) # Create new instance
          retry
        else
          Rails.logger.error "❌ Failed to create seller after #{max_retries} retries: #{e.message}"
          raise
        end
      else
        raise
      end
    end
    
    if save_success
      Rails.logger.info "Seller created successfully: #{seller.email}"
      
      # Handle seller tier assignment - always assign premium tier for 6 months
      expiry_date = 6.months.from_now

      Rails.logger.info "Google OAuth Seller Registration: Assigning Premium tier to seller #{seller.id}, expires at #{expiry_date} (6 months)"
      premium_tier = Tier.find_by(name: 'Premium') || Tier.find_by(id: 4)
      if premium_tier
        seller_tier = SellerTier.create!(
          seller: seller,
          tier: premium_tier,
          duration_months: 6,
          expires_at: expiry_date
        )
        Rails.logger.info "✅ Premium tier assigned to seller via Google OAuth: #{premium_tier.name}"
      else
        Rails.logger.error "❌ Premium tier not found in database for Google OAuth seller creation"
      end
      
      # Cache the profile picture after user creation to avoid rate limiting
      # Store original URL before caching so we can fallback if caching fails
      original_google_url = seller.profile_picture if seller.profile_picture.present? && seller.profile_picture.include?('googleusercontent.com')
      
      if original_google_url.present?
        Rails.logger.info "🔄 Attempting to cache profile picture for seller #{seller.id}: #{original_google_url}"
        cache_service = ProfilePictureCacheService.new
        cached_url = cache_service.cache_google_profile_picture(original_google_url, seller.id)
        
        if cached_url.present?
          # Verify the file actually exists before updating
          filename = cached_url.gsub('/cached_profile_pictures/', '')
          file_path = Rails.root.join('public', 'cached_profile_pictures', filename)
          
          if File.exist?(file_path)
            seller.update_column(:profile_picture, cached_url)
            Rails.logger.info "✅ Profile picture cached and updated: #{cached_url}"
          else
            Rails.logger.warn "⚠️ Cached URL returned but file doesn't exist, keeping original Google URL"
            # Keep the original Google URL if file doesn't exist
          end
        else
          Rails.logger.warn "⚠️ Failed to cache profile picture for seller #{seller.id}, keeping original Google URL"
          # Keep the original Google URL if caching fails
        end
      else
        Rails.logger.info "ℹ️ No Google profile picture to cache for seller #{seller.id}: #{seller.profile_picture}"
      end
      
      # Generate JWT token for new user
      token = generate_jwt_token(seller)
      
      # Send welcome WhatsApp message (non-blocking)
      begin
        WhatsAppNotificationService.send_welcome_message(seller)
      rescue => e
        Rails.logger.error "Failed to send welcome WhatsApp message: #{e.message}"
        # Don't fail registration if WhatsApp message fails
      end
      
      # Return success response with missing fields if any
      # Frontend will show modal to collect missing fields
      response = { 
        success: true, 
        user: format_user_response(seller), 
        token: token,
        new_user: true
      }
      
      # Include missing fields if any were detected (user will complete via modal)
      if missing_fields.any?
        response[:missing_fields] = missing_fields
        response[:user_data] = format_user_data_for_modal(user_info, location_info)
        Rails.logger.info "Seller created with missing fields - will be collected via modal: #{missing_fields.join(', ')}"
      end
      
      response
    else
      Rails.logger.error "Seller creation failed: #{seller.errors.full_messages.join(', ')}"
      
      # Log detailed validation errors for debugging
      Rails.logger.info "Detailed validation errors:"
      seller.errors.each do |field, messages|
        Rails.logger.info "  #{field}: #{messages.join(', ')}"
      end
      
      # Determine missing fields from validation errors
      missing_fields = determine_missing_fields(seller.errors, user_info)
      
      # Return proper hash format with error information
      {
        success: false,
        error: seller.errors.full_messages.join(', '),
        missing_fields: missing_fields.any? ? missing_fields : nil,
        user_data: missing_fields.any? ? format_user_data_for_modal(user_info, location_info) : nil
      }
    end
  end

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

  # Determine the role of an existing user
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

  # Create new buyer user
  def create_buyer_user(user_info, location_info, device_hash = nil)
    Rails.logger.info "Creating buyer with data"
    
    # Check if user already exists as a different role (registration conflict)
    email = user_info['email']
    existing_seller = Seller.find_by(email: email)
    if existing_seller
      Rails.logger.error "❌ Registration conflict: User #{email} already exists as a Seller"
      return {
        success: false,
        error: "This email is already registered as a Seller. Please sign in with your existing account or use a different email address.",
        role_mismatch: true,
        existing_role: 'Seller',
        requested_role: 'Buyer'
      }
    end
    Rails.logger.info "🔍 Profile picture data in create_buyer_user:"
    Rails.logger.info "   user_info['profile_picture']: #{user_info['profile_picture'].inspect}"
    Rails.logger.info "   user_info[:profile_picture]: #{user_info[:profile_picture].inspect}"
    Rails.logger.info "   user_info['picture']: #{user_info['picture'].inspect}"
    
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
    city = location_info.dig('ip_location', 'city') || location_info.dig('geocoded_location', 'city')
    location = location_info.dig('ip_location', 'formatted_address') || location_info.dig('geocoded_location', 'formatted_address') 
    # Extract and fix profile picture URL from Google
    profile_picture = nil
    if user_info['picture'].present?
      profile_picture = fix_google_profile_picture_url(user_info['picture'])
    elsif user_info['photo_url'].present?
      profile_picture = fix_google_profile_picture_url(user_info['photo_url'])
    elsif user_info['image'].present?
      profile_picture = fix_google_profile_picture_url(user_info['image'])
    end

    # Create buyer attributes
    buyer_attributes = {
      fullname: user_info['name'] || user_info['display_name'],
      email: user_info['email'],
      username: username,
      phone_number: phone_number,
      phone_provided_by_oauth: phone_number.present?,
      gender: user_info['gender']&.capitalize || 'Other',
      city: city,
      location: location,
      profile_picture: profile_picture,
      provider: 'google',
      uid: user_info['id'],
      # Use actual detected data - no hardcoded defaults
      age_group_id: calculate_age_group(user_info),
      county_id: location_info.dig('ip_location', 'county_id'),
      sub_county_id: location_info.dig('ip_location', 'sub_county_id')
    }

    Rails.logger.info "Buyer attributes: #{buyer_attributes.inspect}"

    # Check for ALL required fields that would prevent user creation
    missing_fields = []
    
    # Required fields for user creation (based on Buyer model validations)
    missing_fields << 'fullname' if buyer_attributes[:fullname].blank?
    # Note: phone_number, gender, age_group_id, county_id, and sub_county_id are now optional for buyers
    # Users can verify their accounts later
    
    # If we have missing required fields, return missing fields info for complete registration
    if missing_fields.any?
      Rails.logger.info "Missing required fields detected: #{missing_fields.join(', ')}"
      
      # Return proper hash format with missing fields info
      return {
        success: false,
        missing_fields: missing_fields,
        user_data: format_user_data_for_modal(user_info, location_info),
        error: "Please complete your registration by providing the required information."
      }
    end

    # Create the buyer
    buyer = Buyer.new(buyer_attributes)
    
    # Capture device hash if provided for guest click association
    if device_hash.present?
      buyer.device_hash_for_association = device_hash
    end
    
    # Ensure UUID is set before saving (safety check in case callback doesn't fire)
    buyer.id ||= SecureRandom.uuid if buyer.id.blank?
    
    Rails.logger.info "🔧 Buyer ID before save: #{buyer.id.inspect}"
    
    # Try to save, with retry logic for sequence sync issues
    save_success = false
    retry_count = 0
    max_retries = 2
    
    begin
      save_success = buyer.save
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => e
      # After UUID migration, buyers.id is UUID and doesn't use sequences
      # Handle duplicate key errors (which can happen with UUIDs too)
      if e.message.include?('duplicate key value') || 
         (e.respond_to?(:cause) && e.cause.is_a?(PG::UniqueViolation))
        Rails.logger.warn "⚠️ Duplicate key violation detected for buyers table"
        
        # Check if it's a unique constraint violation on email or other unique fields
        if e.message.include?('email') || e.message.include?('username') || e.message.include?('phone_number')
          Rails.logger.error "❌ Unique constraint violation on email/username/phone: #{e.message}"
          raise
        else
          # For other unique violations, try to find existing buyer
          Rails.logger.warn "⚠️ Attempting to find existing buyer by email: #{buyer.email}"
          existing_buyer = Buyer.find_by(email: buyer.email)
          if existing_buyer
            Rails.logger.info "✅ Found existing buyer: #{existing_buyer.id}"
            buyer = existing_buyer
            save_success = true
          else
            Rails.logger.error "❌ Failed to create buyer: #{e.message}"
            raise
          end
        end
      else
        raise
      end
    end
    
    if save_success
      Rails.logger.info "Buyer created successfully: #{buyer.email}"
      
      # Cache the profile picture after user creation to avoid rate limiting
      # Store original URL before caching so we can fallback if caching fails
      original_google_url = buyer.profile_picture if buyer.profile_picture.present? && buyer.profile_picture.include?('googleusercontent.com')
      
      if original_google_url.present?
        Rails.logger.info "🔄 Attempting to cache profile picture for buyer #{buyer.id}: #{original_google_url}"
        cache_service = ProfilePictureCacheService.new
        cached_url = cache_service.cache_google_profile_picture(original_google_url, buyer.id)
        
        if cached_url.present?
          # Verify the file actually exists before updating
          filename = cached_url.gsub('/cached_profile_pictures/', '')
          file_path = Rails.root.join('public', 'cached_profile_pictures', filename)
          
          if File.exist?(file_path)
            buyer.update_column(:profile_picture, cached_url)
            Rails.logger.info "✅ Profile picture cached and updated: #{cached_url}"
          else
            Rails.logger.warn "⚠️ Cached URL returned but file doesn't exist, keeping original Google URL"
            # Keep the original Google URL if file doesn't exist
          end
        else
          Rails.logger.warn "⚠️ Failed to cache profile picture for buyer #{buyer.id}, keeping original Google URL"
          # Keep the original Google URL if caching fails
        end
      else
        Rails.logger.info "ℹ️ No Google profile picture to cache for buyer #{buyer.id}: #{buyer.profile_picture}"
      end
      
      # Generate JWT token for new user
      token = generate_jwt_token(buyer)
      
      # Send welcome WhatsApp message (non-blocking)
      begin
        WhatsAppNotificationService.send_welcome_message(buyer)
      rescue => e
        Rails.logger.error "Failed to send welcome WhatsApp message: #{e.message}"
        # Don't fail registration if WhatsApp message fails
      end
      
      # Return success response
      { 
        success: true, 
        user: format_user_response(buyer), 
        token: token,
        new_user: true
      }
    else
      Rails.logger.error "Buyer creation failed: #{buyer.errors.full_messages.join(', ')}"
      
      # Log detailed validation errors for debugging
      Rails.logger.info "Detailed validation errors:"
      buyer.errors.each do |field, messages|
        Rails.logger.info "  #{field}: #{messages.join(', ')}"
      end
      
      # Determine missing fields from validation errors
      missing_fields = determine_missing_fields(buyer.errors, user_info)
      
      # Return proper hash format with error information
      {
        success: false,
        error: buyer.errors.full_messages.join(', '),
        missing_fields: missing_fields.any? ? missing_fields : nil,
        user_data: missing_fields.any? ? format_user_data_for_modal(user_info, location_info) : nil
      }
    end
  end

  # Generate JWT token for user
  def generate_jwt_token(user)
    Rails.logger.info "Generating JWT token for #{user.class.name}: #{user.email}"
    
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
    
    Rails.logger.info "JWT token generated successfully with remember_me (30 days)"
    
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

  # Fix city name based on county information
  def fix_city_based_on_county(city, location_info)
    return city unless city.present?
    
    # Get county information from location data
    county_id = location_info.dig('ip_location', 'county_id') || 
                location_info.dig('geocoded_location', 'county_id')
    
    return city unless county_id.present?
    
    begin
      county = County.find_by(id: county_id)
      return city unless county.present?
      
      # If we detected a county but the city doesn't match, use the county's capital
      county_capital = county.capital
      
      # Only override if the detected city doesn't make sense for the county
      if should_override_city(city, county)
        Rails.logger.info "🗺️ Overriding city '#{city}' with county capital '#{county_capital}' for #{county.name}"
        return county_capital
      end
      
      city
    rescue => e
      Rails.logger.error "Error fixing city based on county: #{e.message}"
      city
    end
  end

  # Determine if we should override the detected city
  def should_override_city(detected_city, county)
    detected_city_normalized = detected_city.downcase.strip
    county_name_normalized = county.name.downcase
    
    # Override if detected city is a major city that doesn't belong to this county
    major_city_mismatches = {
      'nairobi' => ['kiambu', 'machakos', 'kajiado'], # Nairobi is often detected for nearby counties
      'mombasa' => ['kilifi', 'kwale'], # Mombasa is often detected for coastal counties
      'kisumu' => ['siaya', 'vihiga', 'kakamega'] # Kisumu is often detected for western counties
    }
    
    # Check if detected city is a major city that doesn't belong to this county
    major_city_mismatches.each do |major_city, excluded_counties|
      if detected_city_normalized == major_city && excluded_counties.include?(county_name_normalized)
        return true
      end
    end
    
    # Override if detected city is clearly wrong (e.g., Nairobi detected for Kiambu)
    if detected_city_normalized == 'nairobi' && county_name_normalized == 'kiambu'
      return true
    end
    
    # Override if detected city is a major city but county is not the major city's county
    if detected_city_normalized == 'nairobi' && county_name_normalized != 'nairobi'
      return true
    end
    
    false
  end

  # Enhance location data with county/sub-county mapping
  def enhance_location_with_county_mapping(location_data)
    return location_data unless location_data.present?
    
    begin
      city = location_data['city']
      region = location_data['region_name']
      country = location_data['country']
      
      # Only map if it's Kenya
      if country&.downcase&.include?('kenya')
        county_mapping = map_to_kenyan_county(city, region, country)
        if county_mapping
          location_data['county_id'] = county_mapping[:county_id]
          location_data['sub_county_id'] = county_mapping[:sub_county_id]
          Rails.logger.info "🗺️ Enhanced location with county mapping: County ID #{county_mapping[:county_id]}, Sub-County ID #{county_mapping[:sub_county_id]}"
        end
      end
      
      location_data
    rescue => e
      Rails.logger.error "Error enhancing location with county mapping: #{e.message}"
      location_data
    end
  end

  # Map location to Kenyan county and sub-county
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
      'makueni' => 'Makueni',
      'mandera' => 'Mandera',
      'marsabit' => 'Marsabit',
      'murang\'a' => 'Murang\'a',
      'muranga' => 'Murang\'a',
      'nyamira' => 'Nyamira',
      'nyandarua' => 'Nyandarua',
      'samburu' => 'Samburu',
      'siaya' => 'Siaya',
      'taita taveta' => 'Taita Taveta',
      'tana river' => 'Tana River',
      'tharaka nithi' => 'Tharaka Nithi',
      'trans nzoia' => 'Trans Nzoia',
      'turkana' => 'Turkana',
      'uasin gishu' => 'Uasin Gishu',
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
        # Try to find the most appropriate sub-county based on city name
        sub_county = find_best_sub_county(county, city, region)
        
        Rails.logger.info "🗺️ Found county: #{county.name} (ID: #{county.id})"
        Rails.logger.info "🗺️ Using sub-county: #{sub_county&.name} (ID: #{sub_county&.id})"
        
        return {
          county_id: county.id,
          sub_county_id: sub_county&.id
        }
      end
    end
    
    Rails.logger.info "🗺️ No county mapping found for: #{city}, #{region}"
    nil
  end

  # Find the best sub-county based on city/region name
  def find_best_sub_county(county, city, region)
    return county.sub_counties.first unless city.present?
    
    city_normalized = city.downcase.strip
    region_normalized = region&.downcase&.strip
    
    # Try to find sub-county by exact name match
    sub_county = county.sub_counties.find { |sc| sc.name.downcase == city_normalized }
    return sub_county if sub_county
    
    # Try to find sub-county by partial name match
    sub_county = county.sub_counties.find { |sc| 
      sc.name.downcase.include?(city_normalized) || city_normalized.include?(sc.name.downcase)
    }
    return sub_county if sub_county
    
    # Try to find sub-county by region match
    if region_normalized
      sub_county = county.sub_counties.find { |sc| 
        sc.name.downcase.include?(region_normalized) || region_normalized.include?(sc.name.downcase)
      }
      return sub_county if sub_county
    end
    
    # Fallback to first sub-county
    county.sub_counties.first
  end

  # Method 2: Enhanced IP-based geolocation with multiple services
  def get_location_from_ip(user_ip = nil)
    begin
      Rails.logger.info "Getting location from IP address using multiple services"
      
      # Use user's IP if provided, otherwise fallback to server IP
      ip_to_check = user_ip || request&.remote_ip
      Rails.logger.info "Using IP: #{ip_to_check}"
      
      # Skip localhost IPs
      return nil if ip_to_check == '127.0.0.1' || ip_to_check == '::1'
      
      # Try multiple geolocation services for better accuracy
      location_data = try_multiple_geolocation_services(ip_to_check)
      
      if location_data
        Rails.logger.info "Location data retrieved: #{location_data['city']}, #{location_data['country']}"
        location_data
      else
        Rails.logger.error "Failed to get location from any service"
        nil
      end
    rescue => e
      Rails.logger.error "IP geolocation error: #{e.message}"
      nil
    end
  end

  # Try multiple geolocation services for better accuracy
  def try_multiple_geolocation_services(ip)
    services = [
      { name: 'ip-api.com', method: :get_location_from_ip_api },
      { name: 'ipinfo.io', method: :get_location_from_ipinfo },
      { name: 'ipapi.co', method: :get_location_from_ipapi }
    ]
    
    results = []
    
    services.each do |service|
      begin
        Rails.logger.info "Trying #{service[:name]} for IP: #{ip}"
        result = send(service[:method], ip)
        if result
          results << result.merge('service' => service[:name])
          Rails.logger.info "✅ #{service[:name]} success: #{result['city']}, #{result['country']}"
        else
          Rails.logger.warn "❌ #{service[:name]} failed"
        end
      rescue => e
        Rails.logger.error "❌ #{service[:name]} error: #{e.message}"
      end
    end
    
    # Return the best result based on confidence and accuracy
    select_best_location_result(results)
  end

  # Get location from ip-api.com
  def get_location_from_ip_api(ip)
    api_url = "http://ip-api.com/json/#{ip}"
    response = HTTParty.get(api_url, timeout: 5)
    
    if response.success?
      data = JSON.parse(response.body)
      return nil if data['status'] == 'fail'
      
      {
        'country' => data['country'],
        'country_code' => data['countryCode'],
        'region' => data['region'],
        'region_name' => data['regionName'],
        'city' => data['city'],
        'zip' => data['zip'],
        'latitude' => data['lat'],
        'longitude' => data['lon'],
        'timezone' => data['timezone'],
        'isp' => data['isp'],
        'ip' => data['query'],
        'confidence' => 0.8 # High confidence for ip-api.com
      }
    end
  rescue => e
    Rails.logger.error "ip-api.com error: #{e.message}"
    nil
  end

  # Get location from ipinfo.io
  def get_location_from_ipinfo(ip)
    api_url = "https://ipinfo.io/#{ip}/json"
    response = HTTParty.get(api_url, timeout: 5)
    
    if response.success?
      data = JSON.parse(response.body)
      return nil if data['error']
      
      # Parse region (format: "Nairobi, Kenya" or "Nairobi County, Kenya")
      region_parts = data['region']&.split(',') || []
      region_name = region_parts.first&.strip
      
      {
        'country' => data['country'],
        'country_code' => data['country'],
        'region' => region_name,
        'region_name' => region_name,
        'city' => data['city'],
        'zip' => data['postal'],
        'latitude' => data['loc']&.split(',')&.first,
        'longitude' => data['loc']&.split(',')&.last,
        'timezone' => data['timezone'],
        'isp' => data['org'],
        'ip' => data['ip'],
        'confidence' => 0.9 # Very high confidence for ipinfo.io
      }
    end
  rescue => e
    Rails.logger.error "ipinfo.io error: #{e.message}"
    nil
  end

  # Get location from ipapi.co
  def get_location_from_ipapi(ip)
    api_url = "https://ipapi.co/#{ip}/json/"
    response = HTTParty.get(api_url, timeout: 5)
    
    if response.success?
      data = JSON.parse(response.body)
      return nil if data['error']
      
      {
        'country' => data['country_name'],
        'country_code' => data['country_code'],
        'region' => data['region_code'],
        'region_name' => data['region'],
        'city' => data['city'],
        'zip' => data['postal'],
        'latitude' => data['latitude'],
        'longitude' => data['longitude'],
        'timezone' => data['timezone'],
        'isp' => data['org'],
        'ip' => data['ip'],
        'confidence' => 0.85 # High confidence for ipapi.co
      }
    end
  rescue => e
    Rails.logger.error "ipapi.co error: #{e.message}"
    nil
  end

  # Select the best location result from multiple services
  def select_best_location_result(results)
    return nil if results.empty?
    
    # Sort by confidence score
    best_result = results.max_by { |r| r['confidence'] }
    
    # If we have multiple results, try to find consensus
    if results.length > 1
      consensus_result = find_location_consensus(results)
      best_result = consensus_result if consensus_result
    end
    
    # Remove service field before returning
    best_result.delete('service')
    best_result.delete('confidence')
    
    Rails.logger.info "Selected best location: #{best_result['city']}, #{best_result['country']} (confidence: #{best_result['confidence'] || 'unknown'})"
    best_result
  end

  # Find consensus among multiple location results
  def find_location_consensus(results)
    # Group by country first
    country_groups = results.group_by { |r| r['country'] }
    
    # If all results agree on country, look for city consensus
    if country_groups.length == 1
      country = country_groups.keys.first
      city_groups = results.group_by { |r| r['city'] }
      
      # If we have city consensus, use it
      if city_groups.length == 1
        Rails.logger.info "Consensus found: #{city_groups.keys.first}, #{country}"
        return results.first
      end
      
      # If no city consensus, prefer results that don't default to major cities
      non_major_city_results = results.reject do |r|
        major_cities = ['nairobi', 'mombasa', 'kisumu']
        major_cities.include?(r['city']&.downcase)
      end
      
      if non_major_city_results.any?
        Rails.logger.info "Preferring non-major city result: #{non_major_city_results.first['city']}"
        return non_major_city_results.first
      end
    end
    
    # Return the highest confidence result
    results.max_by { |r| r['confidence'] }
  end

  # Method 3: Google Maps Geocoding API
  def get_location_from_geocoding(location_info)
    begin
      Rails.logger.info "Getting location from Google Maps Geocoding API"
      
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
          Rails.logger.info "Geocoding address: #{address_string}"
          
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
              
              Rails.logger.info "Geocoded location: #{geocoded_location['formatted_address']}"
              geocoded_location
            else
              Rails.logger.error "Geocoding failed: #{geocoding_data['status']}"
              nil
            end
          else
            Rails.logger.error "Geocoding API request failed: #{response.code}"
            nil
          end
        else
          Rails.logger.error "No address data available for geocoding"
          nil
        end
      else
        Rails.logger.error "Google Maps API key not configured"
        nil
      end
    rescue => e
      Rails.logger.error "Geocoding error: #{e.message}"
      nil
    end
  end

  def exchange_code_for_token
    begin
      Rails.logger.info "Exchanging code for token"

      # For GSI popup authentication, Google uses 'postmessage' for both authorization and token exchange
      # When redirect_uri is 'postmessage', we must use 'postmessage' for token exchange as well
      # This is a special case for Google Sign-In (GSI) popup mode
      redirect_uri = @redirect_uri == 'postmessage' ? 'postmessage' : @redirect_uri

      Rails.logger.info "Exchanging code for token with redirect_uri: #{redirect_uri}"
      Rails.logger.info "Using client_id: #{ENV['GOOGLE_OAUTH_CLIENT_ID']}"
      Rails.logger.info "Original redirect_uri from request: #{@redirect_uri}"

      # Validate required environment variables
      unless ENV['GOOGLE_OAUTH_CLIENT_ID'].present? && ENV['GOOGLE_OAUTH_CLIENT_SECRET'].present?
        Rails.logger.error "Missing Google OAuth credentials"
        return nil
      end

      # For GSI popup mode, 'postmessage' is valid for token exchange
      # But it must be configured in Google Cloud Console as an authorized redirect URI
      if redirect_uri.blank?
        Rails.logger.error "❌ Invalid redirect URI for token exchange: blank"
        return nil
      end
      
      response = HTTParty.post(GOOGLE_TOKEN_URL, {
        body: {
          client_id: ENV['GOOGLE_OAUTH_CLIENT_ID'],
          client_secret: ENV['GOOGLE_OAUTH_CLIENT_SECRET'],
          code: @auth_code,
          grant_type: 'authorization_code',
          redirect_uri: redirect_uri
        },
        headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
      })
      
      Rails.logger.info "Google token response status: #{response.code}"
      Rails.logger.info "Google token response body: #{response.body}"
      
      unless response.success?
        Rails.logger.error "Failed to exchange code for token. Status: #{response.code}, Body: #{response.body}"
        
        # Parse error response for better debugging
        begin
          error_data = JSON.parse(response.body)
          if error_data['error'] == 'redirect_uri_mismatch'
            Rails.logger.error "=" * 80
            Rails.logger.error "❌ REDIRECT URI MISMATCH ERROR"
            Rails.logger.error "=" * 80
            Rails.logger.error "   The redirect_uri '#{redirect_uri}' is not configured in Google Cloud Console"
            Rails.logger.error "   For GSI popup authentication, you need to:"
            Rails.logger.error "   1. Go to Google Cloud Console → APIs & Services → Credentials"
            Rails.logger.error "   2. Edit your OAuth 2.0 Client ID"
            Rails.logger.error "   3. Add 'postmessage' to 'Authorized redirect URIs'"
            Rails.logger.error "   4. Save and wait a few minutes for changes to propagate"
            Rails.logger.error "=" * 80
          end
        rescue => e
          # Ignore JSON parsing errors
        end
        
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
      Rails.logger.info "Fetching comprehensive user info from Google"
      
      # Get basic profile info
      Rails.logger.info "Getting basic user info"
      basic_info = get_basic_user_info(access_token)
      return nil unless basic_info
      
      Rails.logger.info "Basic user info obtained: #{basic_info['email']}"
      
      # Get detailed info from People API
      Rails.logger.info "Getting detailed user info from People API"
      detailed_info = get_detailed_user_info(access_token)
      
      Rails.logger.info "Detailed user info obtained: #{detailed_info ? 'Yes' : 'No'}"
      
      # Merge the information (detailed_info takes precedence)
      comprehensive_info = basic_info.merge(detailed_info || {})
      
      # Check for phone number data
      phone_data_available = comprehensive_info['phone_number'].present? || comprehensive_info['phone_numbers'].present?
      Rails.logger.info "Phone data available: #{phone_data_available}"
      
      Rails.logger.info "Successfully obtained comprehensive user info: #{comprehensive_info['email']}"
      Rails.logger.info "Available data: #{comprehensive_info.keys.join(', ')}"
      
      comprehensive_info
    rescue => e
      Rails.logger.error "❌ Error getting comprehensive user info: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.join("\n")}"
      nil
    end
  end

  def get_basic_user_info(access_token)
    begin
      Rails.logger.info "Fetching basic user info from Google"
      
      response = HTTParty.get(GOOGLE_USER_INFO_URL, {
        headers: { 'Authorization' => "Bearer #{access_token}" }
      })
      
      Rails.logger.info "Google user info response status: #{response.code}"
      Rails.logger.info "Google user info response body: #{response.body}"
      
      unless response.success?
        Rails.logger.error "Failed to get basic user info. Status: #{response.code}, Body: #{response.body}"
        return nil
      end
      
      user_info = JSON.parse(response.body)
      Rails.logger.info "Basic user info obtained for: #{user_info['email']}"
      user_info
    rescue => e
      Rails.logger.error "Error getting basic user info: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      nil
    end
  end

  def get_detailed_user_info(access_token)
    begin
      Rails.logger.info "Fetching detailed user info from Google People API"
      
      # Request user data from People API (excluding location fields to avoid consent screens)
      # Only request essential fields: names, photos, phone numbers, basic profile info
      person_fields = [
        'names',           # Full name, given name, family name
        'photos',          # Profile pictures
        'phoneNumbers',   # Phone numbers
        'birthdays',      # Birthday information
        'genders',        # Gender information
        'ageRanges',      # Age range
        'locales',        # Language preferences
        'organizations',  # Work information
        'occupations',    # Job titles
        'biographies'     # About/bio information
        # Removed 'addresses', 'residences', 'locations' - not needed and cause consent screens
      ].join(',')
      
      response = HTTParty.get(GOOGLE_PEOPLE_API_URL, {
        headers: { 'Authorization' => "Bearer #{access_token}" },
        query: { personFields: person_fields }
      })
      
      Rails.logger.info "Google People API response status: #{response.code}"
      Rails.logger.info "Google People API response body: #{response.body}"
      
      unless response.success?
        Rails.logger.warn "Failed to get detailed user info from People API. Status: #{response.code}, Body: #{response.body}"
        Rails.logger.warn "This might be because People API is not enabled in Google Cloud Console"
        Rails.logger.warn "Or the user has not granted permission for these scopes"
        return {}
      end
      
      detailed_info = JSON.parse(response.body)
      Rails.logger.info "Successfully obtained detailed user info from People API"
      Rails.logger.info "People API data keys: #{detailed_info.keys.join(', ')}"
      
      # Log what data is actually available
      Rails.logger.info "Detailed People API data analysis:"
      detailed_info.each do |key, value|
        if value.is_a?(Array)
          Rails.logger.info "  #{key}: #{value.length} items"
        else
          Rails.logger.info "  #{key}: #{value.class} - #{value.inspect[0..100]}..."
        end
      end
      
      # Address fields not requested - removed to avoid consent screens
      # Location data will come from IP geolocation or frontend instead
      Rails.logger.info "Address/location fields not requested from People API (intentionally excluded to avoid consent screens)"
      
      # Log specific data that should be available
      if detailed_info['phoneNumbers']&.any?
        Rails.logger.info "Phone numbers found: #{detailed_info['phoneNumbers'].length}"
      else
        Rails.logger.info "No phone numbers found in People API response"
      end
      
      if detailed_info['genders']&.any?
        Rails.logger.info "Gender found: #{detailed_info['genders'].first['value']}"
      else
        Rails.logger.info "No gender found in People API response"
      end
      
      # Extract and format the detailed information
      extracted_info = extract_detailed_info(detailed_info)
      # Address extraction disabled - location data comes from IP geolocation or frontend
      extracted_info
    rescue => e
      Rails.logger.warn "Error getting detailed user info from People API: #{e.message}"
      Rails.logger.warn "Backtrace: #{e.backtrace.join("\n")}"
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
    
    # Extract phone numbers - try all available phone numbers
    if people_data['phoneNumbers']&.any?
      # Try to find mobile phone first, then any phone
      mobile_phone = people_data['phoneNumbers'].find { |p| p['type']&.downcase == 'mobile' || p['type']&.downcase == 'cell' }
      phone_info = mobile_phone || people_data['phoneNumbers'].first
      
      if phone_info && phone_info['value'].present?
        extracted['phone_number'] = phone_info['value']
        extracted['phone_type'] = phone_info['type']
        # Also store in phone_numbers array format for compatibility
        extracted['phone_numbers'] = people_data['phoneNumbers'].map { |p| { 'value' => p['value'], 'type' => p['type'] } }
        Rails.logger.info "📞 Extracted phone number from People API: #{phone_info['value']} (type: #{phone_info['type']})"
      end
    end
    
    # Extract addresses (removed from API request to avoid consent screens)
    # Address extraction disabled - location data should come from IP geolocation or frontend
    # if people_data['addresses']&.any?
    #   address_info = people_data['addresses'].first
    #   extracted['address'] = {
    #     'formatted' => address_info['formattedValue'],
    #     'street' => address_info['streetAddress'],
    #     'city' => address_info['city'],
    #     'region' => address_info['region'],
    #     'postal_code' => address_info['postalCode'],
    #     'country' => address_info['country']
    #   }
    # end
    
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
    
    Rails.logger.info "Extracted detailed info: #{extracted.keys.join(', ')}"
    extracted
  end

  def find_or_create_user(user_info)
    email = user_info['email']
    provider = 'google'
    uid = user_info['id']
    
    # Log all available Google user data for debugging
    Rails.logger.info "Complete Google user info structure:"
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
    Rails.logger.info "Updating existing user: #{user.email} (#{user.class.name})"

    # Only link if not already linked to this provider
    unless user.provider == provider && user.uid == uid
      update_attributes = {
        provider: provider,
        uid: uid,
        oauth_token: user_info['access_token'],
        oauth_expires_at: Time.current + 1.hour # Google tokens typically last 1 hour
      }
      
      # Smart profile picture update logic
      if user.respond_to?(:profile_picture)
        current_picture = user.profile_picture

        # Determine if current picture should be updated
        should_update_picture = false
        update_reason = ""

        if current_picture.blank?
          should_update_picture = true
          update_reason = "no current picture"
        elsif is_google_or_cloudinary_url?(current_picture)
          should_update_picture = true
          update_reason = "current picture is from Google/Cloudinary (safe to update)"
        else
          # Current picture appears to be user-uploaded - be conservative
          should_update_picture = false
          update_reason = "current picture appears user-uploaded"
        end

        if should_update_picture
          # Try to get fresh profile picture from Google
          fresh_picture = nil

          fresh_picture = user_info['picture'] || user_info['photo_url'] || user_info['image']
          if fresh_picture.present?
            fresh_picture = fix_google_profile_picture_url(fresh_picture, user.id)
          end

          if fresh_picture.present? && current_picture != fresh_picture
            update_attributes[:profile_picture] = fresh_picture
            Rails.logger.info "Updated profile picture for #{user.email}: #{update_reason}"
          end
        end
      end
      
      # Update fullname if user doesn't have one and Google provides one
      if user.respond_to?(:fullname) && user.fullname.blank? && (user_info['display_name'].present? || user_info['name'].present?)
        new_fullname = user_info['display_name'] || user_info['name']
        update_attributes[:fullname] = new_fullname
        Rails.logger.info "✅ Updating fullname for existing user: #{user.email} -> #{new_fullname}"
      end

      # Smart phone number update logic
      if user.respond_to?(:phone_number)
        current_phone = user.phone_number
        extracted_phone = extract_phone_number(user_info)

        if extracted_phone.present?
          # Clean and validate the phone number
          cleaned_phone = extracted_phone.gsub(/\D/, '')
          if cleaned_phone.start_with?('+254')
            cleaned_phone = cleaned_phone[4..-1]
            cleaned_phone = "0#{cleaned_phone}" if cleaned_phone.length == 9 && cleaned_phone.start_with?('7')
          elsif cleaned_phone.length == 9 && cleaned_phone.start_with?('7')
            cleaned_phone = "0#{cleaned_phone}"
          end

          # Determine if we should update the phone number
          should_update_phone = false
          update_reason = ""

          if current_phone.blank?
            should_update_phone = true
            update_reason = "no current phone number"
          elsif current_phone != cleaned_phone
            # Phone numbers are different - check if the new one looks more complete/valid
            current_digits = current_phone.gsub(/\D/, '')
            new_digits = cleaned_phone.gsub(/\D/, '')

            # Prefer phone numbers with country codes or that look more complete
            if new_digits.length > current_digits.length ||
               (new_digits.start_with?('0') && !current_digits.start_with?('0')) ||
               (new_digits.length == 10 && current_digits.length != 10)
              should_update_phone = true
              update_reason = "new phone number appears more complete (#{new_digits.length} vs #{current_digits.length} digits)"
            else
              Rails.logger.info "ℹ️ Phone numbers differ but keeping current (similar validity)"
              should_update_phone = false
              update_reason = "phone numbers differ but current seems equally valid"
            end
          else
            should_update_phone = false
            update_reason = "phone numbers are identical"
          end

          if should_update_phone
            update_attributes[:phone_number] = cleaned_phone
            Rails.logger.info "Updated phone number for #{user.email}: #{update_reason}"
          end
        else
          Rails.logger.info "ℹ️ No phone number available from Google for existing user: #{user.email}"
        end
      end
      
      # Update location if user doesn't have one and Google provides one
      if user.respond_to?(:location) && user.location.blank? && user_info['address'].present?
        update_attributes[:location] = user_info['address']
        Rails.logger.info "Updating location for existing user: #{user.email}"
      elsif user.respond_to?(:location) && user.location.present?
        Rails.logger.info "User already has location, keeping existing: #{user.email}"
      end
      
      # Update city if user doesn't have one and Google provides one
      if user.respond_to?(:city) && user.city.blank? && user_info['city'].present?
        update_attributes[:city] = user_info['city']
        Rails.logger.info "Updating city for existing user: #{user.email}"
      elsif user.respond_to?(:city) && user.city.present?
        Rails.logger.info "User already has city, keeping existing: #{user.email}"
      end
      
      # Update zipcode if user doesn't have one and Google provides one
      if user.respond_to?(:zipcode) && user.zipcode.blank? && user_info['zipcode'].present?
        update_attributes[:zipcode] = user_info['zipcode']
        Rails.logger.info "Updating zipcode for existing user: #{user.email}"
      elsif user.respond_to?(:zipcode) && user.zipcode.present?
        Rails.logger.info "User already has zipcode, keeping existing: #{user.email}"
      end
      
      # Update gender if user doesn't have one and Google provides one
      if user.respond_to?(:gender) && user.gender.blank? && user_info['gender'].present?
        update_attributes[:gender] = user_info['gender']
        Rails.logger.info "Updating gender for existing user: #{user.email}"
      elsif user.respond_to?(:gender) && user.gender.present?
        Rails.logger.info "User already has gender, keeping existing: #{user.email}"
      end
      
      # Update age group if user doesn't have one and Google provides birthday
      if user.respond_to?(:age_group_id) && user.age_group_id.blank? && (user_info['birthday'].present? || user_info['birth_date'].present?)
        birthday = user_info['birthday'] || user_info['birth_date']
        age_group_id = calculate_age_group_from_birthday(birthday)
        if age_group_id.present?
          update_attributes[:age_group_id] = age_group_id
          Rails.logger.info "Updating age group for existing user: #{user.email}"
        end
      elsif user.respond_to?(:age_group_id) && user.age_group_id.present?
        Rails.logger.info "User already has age group, keeping existing: #{user.email}"
      end
      
      Rails.logger.info "Updating existing user with attributes: #{update_attributes.keys.join(', ')}"
      user.update!(update_attributes)
      
      # Cache the profile picture after update to avoid rate limiting
      if user.profile_picture.present? && user.profile_picture.include?('googleusercontent.com')
        cache_service = ProfilePictureCacheService.new
        cached_url = cache_service.cache_google_profile_picture(user.profile_picture, user.id)
        
        if cached_url.present?
          user.update_column(:profile_picture, cached_url)
          Rails.logger.info "✅ Profile picture cached and updated for existing user: #{cached_url}"
        end
      end
    end
  end

  def create_new_oauth_user(user_info, provider, uid)
    # Create as buyer by default for Google OAuth users
    phone_number = extract_phone_number(user_info)
    
    # If no phone number from Google, leave blank for user to complete
    # We'll handle this in the frontend with a completion modal
    
    # Extract comprehensive user information
    fullname = extract_best_name(user_info)
    
    # Debug: Log all available user info to see what Google is providing
    Rails.logger.info "🔍 Complete Google user info received:"
    user_info.each do |key, value|
      Rails.logger.info "   #{key}: #{value.inspect}"
    end
    
    # Try multiple sources for profile picture
    profile_picture = nil
    if user_info['picture'].present?
      profile_picture = fix_google_profile_picture_url(user_info['picture'])
    elsif user_info['photo_url'].present?
      profile_picture = fix_google_profile_picture_url(user_info['photo_url'])
    elsif user_info['image'].present?
      profile_picture = fix_google_profile_picture_url(user_info['image'])
    end
    Rails.logger.info "Full name from Google: #{fullname || 'MISSING - will be required in frontend'}"
    
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
    
    Rails.logger.info "Creating new OAuth user with comprehensive attributes"
    Rails.logger.info "User data: #{user_attributes.except(:oauth_token, :oauth_expires_at).inspect}"
    Rails.logger.info "Phone number being stored: #{phone_number || 'Not available'}"
    Rails.logger.info "Gender being stored: #{gender || 'Not available'}"
    Rails.logger.info "Location being stored: #{location_info[:location] || 'Not available'}"
    Rails.logger.info "City being stored: #{location_info[:city] || 'Not available'}"
    Rails.logger.info "Zipcode being stored: #{location_info[:zipcode] || 'Not available'}"
    
    # For OAuth users, we'll allow incomplete data and let user complete it later
    # Set defaults for required fields that are missing
    age_group_id = age_group_id.present? ? age_group_id : AgeGroup.first&.id || 1
    gender = gender.present? ? gender : 'Male'
    
    # Update attributes with defaults
    user_attributes[:age_group_id] = age_group_id
    user_attributes[:gender] = gender
    
    user = Buyer.create!(user_attributes)
    
    Rails.logger.info "Successfully created OAuth user: #{user.email}"
    Rails.logger.info "Profile picture: #{user.profile_picture}"
    Rails.logger.info "Location: #{user.location}"
    Rails.logger.info "City: #{user.city}"
    
    user
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create OAuth user: #{e.message}"
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

  # Generate unique enterprise name to avoid duplicates
  def generate_unique_enterprise_name(base_name)
    return 'Business' if base_name.blank?
    
    # Clean the base name
    clean_name = base_name.strip.gsub(/[^a-zA-Z0-9\s]/, '')
    return 'Business' if clean_name.blank?
    
    enterprise_name = clean_name
    counter = 1
    
    while Seller.exists?(enterprise_name: enterprise_name)
      enterprise_name = "#{clean_name} #{counter}"
      counter += 1
    end
    
    enterprise_name
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
    # Try multiple sources for phone number
    phone_number = nil
    
    # First, try direct phone_number field (from People API)
    if user_info['phone_number'].present?
      phone_number = user_info['phone_number']
    # Then try phone_numbers array (from People API or other sources)
    elsif user_info['phone_numbers'].present?
      if user_info['phone_numbers'].is_a?(Array)
        # Find mobile/cell phone first, then any phone
        mobile_phone = user_info['phone_numbers'].find { |p| 
          (p.is_a?(Hash) && (p['type']&.downcase == 'mobile' || p['type']&.downcase == 'cell')) ||
          (p.is_a?(String) && p.match?(/mobile|cell/i))
        }
        phone_info = mobile_phone || user_info['phone_numbers'].first
        
        if phone_info.is_a?(Hash)
          phone_number = phone_info['value'] || phone_info[:value]
        elsif phone_info.is_a?(String)
          phone_number = phone_info
        end
      end
    # Try phone field as fallback
    elsif user_info['phone'].present?
      phone_number = user_info['phone']
    end
    
    if phone_number.present?
      # Clean and format the phone number
      cleaned_phone = phone_number.to_s.gsub(/[^\d+]/, '')
      
      Rails.logger.info "🔍 Extracted phone number: #{phone_number} -> cleaned: #{cleaned_phone}"
      
      # Validate phone number format (accept various formats)
      if cleaned_phone.length >= 7 && cleaned_phone.length <= 15
        Rails.logger.info "✅ Phone number format accepted: #{cleaned_phone}"
        return cleaned_phone
      else
        Rails.logger.warn "❌ Invalid phone number format: #{cleaned_phone} (length: #{cleaned_phone.length})"
        return nil
      end
    else
      Rails.logger.warn "No phone number found in Google user info"
      return nil
    end
  end

  def extract_location_info(user_info)
    location_info = { location: nil, city: nil, zipcode: nil }
    
    # First, try to use location data from frontend if available
    if @location_data.present? && @location_data['data'].present?
      Rails.logger.info "🌍 Using location data from frontend: #{@location_data.inspect}"
      
      # Try browser location first
      if @location_data['data']['browser_location'].present?
        browser_loc = @location_data['data']['browser_location']
        location_info[:city] = browser_loc['city'] if browser_loc['city'].present?
        location_info[:location] = "#{browser_loc['city']}, #{browser_loc['region'] || 'Kenya'}" if browser_loc['city'].present?
      end
      
      # Try address from coordinates
      if @location_data['data']['address_from_coordinates'].present?
        addr = @location_data['data']['address_from_coordinates']
        location_info[:city] = addr['city'] if addr['city'].present?
        location_info[:location] = addr['formatted_address'] if addr['formatted_address'].present?
      end
      
      # Try IP location as fallback
      if @location_data['data']['ip_location'].present?
        ip_loc = @location_data['data']['ip_location']
        location_info[:city] = ip_loc['city'] if ip_loc['city'].present? && location_info[:city].blank?
        location_info[:location] = "#{ip_loc['city']}, #{ip_loc['regionName'] || 'Kenya'}" if ip_loc['city'].present? && location_info[:location].blank?
      end
    end
    
    # Fallback to Google user info if frontend location data is not available
    if location_info[:location].blank?
      # Extract from address information
      if user_info['address'].present?
        address = user_info['address']
        location_info[:location] = address['formatted'] || address['street']
        location_info[:city] = address['city']
        location_info[:zipcode] = address['postal_code']
      end
      
      # Extract from addresses array if present
      if user_info['addresses'].present? && user_info['addresses'].is_a?(Array) && user_info['addresses'].any?
        address = user_info['addresses'].first
        location_info[:location] = address['formattedValue'] || address['streetAddress'] || location_info[:location]
        location_info[:city] = address['city'] || location_info[:city]
        location_info[:zipcode] = address['postalCode'] || location_info[:zipcode]
      end
      
      # Fallback to basic location if available
      if location_info[:location].blank? && user_info['locale'].present?
        location_info[:location] = user_info['locale']
      end
    end
    
    # Extract from residences if available
    if user_info['residences'].present? && user_info['residences'].is_a?(Array) && user_info['residences'].any?
      residence = user_info['residences'].first
      location_info[:location] = residence['value'] || location_info[:location]
    end
    
    Rails.logger.info "🔍 Extracted location info: #{location_info.inspect}"
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

  # Fix Google profile picture URL and cache it to avoid rate limiting
  def fix_google_profile_picture_url(original_url, user_id = nil)
    return nil if original_url.blank?
    
    Rails.logger.info "🔧 Original profile picture URL: #{original_url}"
    
    # If we have a user_id, try to cache the image to avoid rate limiting
    if user_id.present?
      cache_service = ProfilePictureCacheService.new
      cached_url = cache_service.get_or_cache_profile_picture(original_url, user_id)
      
      if cached_url.present?
        Rails.logger.info "✅ Using cached profile picture: #{cached_url}"
        return cached_url
      end
    end
    
    # Fallback to fixing the original URL if caching fails
    fixed_url = original_url.dup
    
    # Remove size parameters that might cause access issues
    fixed_url = fixed_url.gsub(/=s\d+/, '=s400') # Set to a reasonable size (400px)
    fixed_url = fixed_url.gsub(/=w\d+-h\d+/, '=s400') # Remove width/height restrictions
    fixed_url = fixed_url.gsub(/=c\d+/, '=s400') # Remove crop restrictions
    
    # Ensure the URL is publicly accessible
    if fixed_url.include?('googleusercontent.com')
      # For Google profile pictures, ensure we have the right format
      fixed_url = fixed_url.gsub(/=s\d+/, '=s400') if fixed_url.include?('=s')
    end
    
    Rails.logger.info "🔧 Fixed profile picture URL: #{fixed_url}"
    fixed_url
  rescue => e
    Rails.logger.error "❌ Error fixing profile picture URL: #{e.message}"
    original_url # Return original URL if fixing fails
  end

  # All new sellers get premium tier for 6 months
  def should_get_premium?
    true
  end

  # Check if URL is from Google or Cloudinary (safe to auto-update)
  def is_google_or_cloudinary_url?(url)
    return false if url.blank?

    url = url.downcase

    # Check for Google domains
    google_domains = [
      'googleusercontent.com',
      'google.com',
      'gstatic.com',
      'ggpht.com'
    ]

    # Check for Cloudinary domains
    cloudinary_domains = [
      'cloudinary.com',
      'res.cloudinary.com'
    ]

    # Check for our cached profile pictures path
    is_cached_local = url.include?('/cached_profile_pictures/')

    # Check if URL contains Google or Cloudinary domains
    contains_google = google_domains.any? { |domain| url.include?(domain) }
    contains_cloudinary = cloudinary_domains.any? { |domain| url.include?(domain) }

    contains_google || contains_cloudinary || is_cached_local
  end

end
