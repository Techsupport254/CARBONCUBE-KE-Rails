# app/services/oauth_account_linking_service.rb
class OauthAccountLinkingService
  def initialize(auth_hash, role = 'buyer')
    @auth_hash = auth_hash
    @role = role
    @provider = auth_hash[:provider]
    @uid = auth_hash[:uid]
    @email = auth_hash.dig(:info, :email)
    @name = auth_hash.dig(:info, :name)
    @picture = auth_hash.dig(:info, :image)
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
      profile_picture: @picture # Set profile picture from OAuth
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
      profile_picture: @picture # Set profile picture from OAuth
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
end
