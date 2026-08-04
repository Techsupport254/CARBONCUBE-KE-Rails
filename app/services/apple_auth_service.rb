require 'jwt'
require 'net/http'
require 'json'

class AppleAuthService
  APPLE_JWKS_URL = 'https://appleid.apple.com/auth/keys'.freeze
  APPLE_ISSUER = 'https://appleid.apple.com'.freeze

  def initialize(identity_token, full_name = nil, role = 'buyer', authorization_code = nil)
    @identity_token = identity_token
    @full_name = full_name
    @role = role.to_s.downcase.strip
    @authorization_code = authorization_code
  end

  def authenticate
    payload = verify_identity_token(@identity_token)
    return { success: false, error: 'Invalid Apple identity token' } unless payload.is_a?(Hash)

    email = payload['email']
    apple_uid = payload['sub']
    return { success: false, error: 'Missing Apple user identifier' } if apple_uid.blank?

    user = find_existing_user(email, apple_uid)

    if user
      if user.respond_to?(:deleted?) && user.deleted?
        return { success: false, error: 'Your account has been deleted. Please check your email for a reactivation link or request a new one.' }
      end

      if user.respond_to?(:blocked?) && user.blocked?
        return { success: false, error: 'Your account has been blocked. Please contact support.' }
      end

      # Update name on first sign-in if Apple provided it and we don't have one
      if @full_name.present? && user.respond_to?(:fullname) && user.fullname.blank?
        user.update(fullname: @full_name)
      end
    else
      user = create_apple_user(email, apple_uid, @full_name)
      return { success: false, error: user.errors.full_messages.join(', ') } unless user.persisted?
    end

    store_refresh_token(user)

    token = generate_jwt_token(user)
    user_response = format_user_response(user)

    {
      success: true,
      user: user_response,
      token: token
    }
  rescue => e
    Rails.logger.error "[AppleAuthService] #{e.class}: #{e.message}"
    { success: false, error: 'Apple authentication failed. Please try again.' }
  end

  private

  def verify_identity_token(token)
    return nil if token.blank?

    jwks = fetch_apple_jwks
    return nil if jwks.blank?

    payload, _header = JWT.decode(
      token,
      nil,
      true,
      {
        algorithm: 'RS256',
        jwks: jwks,
        verify_expiration: true,
        verify_not_before: true
      }
    )

    return nil unless payload['iss'] == APPLE_ISSUER

    # Verify the audience (bundle ID) when configured
    if (expected_aud = ENV['APPLE_BUNDLE_ID']).present?
      return nil unless payload['aud'] == expected_aud
    end

    payload
  rescue JWT::DecodeError => e
    Rails.logger.warn "[AppleAuthService] JWT decode error: #{e.message}"
    nil
  end

  def fetch_apple_jwks
    uri = URI(APPLE_JWKS_URL)
    response = Net::HTTP.get_response(uri)
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue => e
    Rails.logger.error "[AppleAuthService] Failed to fetch Apple JWKS: #{e.message}"
    nil
  end

  def find_existing_user(email, apple_uid)
    user = Buyer.where(provider: 'apple', uid: apple_uid).first
    user ||= Seller.where(provider: 'apple', uid: apple_uid).first
    user ||= Buyer.find_by(email: email) if email.present?
    user ||= Seller.find_by(email: email) if email.present?
    user
  end

  def create_apple_user(email, apple_uid, full_name)
    name = full_name.presence || email.to_s.split('@').first.presence || 'Apple User'

    if @role == 'seller'
      Seller.new(
        fullname: name,
        email: email,
        provider: 'apple',
        uid: apple_uid,
        password: SecureRandom.hex(32)
      )
    else
      Buyer.new(
        fullname: name,
        email: email,
        provider: 'apple',
        uid: apple_uid,
        password: SecureRandom.hex(32)
      )
    end.tap(&:save)
  end

  def generate_jwt_token(user)
    role = determine_role(user)
    remember_me = true

    token_payload = if role == 'Seller'
                      { seller_id: user.id, email: user.email, role: role, remember_me: remember_me }
                    else
                      { user_id: user.id, email: user.email, role: role, remember_me: remember_me }
                    end

    JsonWebToken.encode(token_payload)
  end

  def determine_role(user)
    user.is_a?(Seller) ? 'Seller' : 'Buyer'
  end

  def store_refresh_token(user)
    return if @authorization_code.blank?

    refresh_token = exchange_authorization_code(@authorization_code)
    return if refresh_token.blank?

    user.update(oauth_refresh_token: refresh_token)
  rescue => e
    Rails.logger.warn "[AppleAuthService] Failed to store refresh token: #{e.message}"
  end

  def client_secret
    return nil unless apple_signing_key_available?

    now = Time.now.to_i
    payload = {
      iss: ENV['APPLE_TEAM_ID'],
      iat: now,
      exp: now + 86400,
      aud: 'https://appleid.apple.com',
      sub: ENV['APPLE_BUNDLE_ID']
    }

    key = OpenSSL::PKey::EC.new(ENV['APPLE_PRIVATE_KEY'].to_s.gsub('\\n', "\n"))
    JWT.encode(payload, key, 'ES256', { kid: ENV['APPLE_KEY_ID'] })
  rescue => e
    Rails.logger.error "[AppleAuthService] Failed to generate client secret: #{e.message}"
    nil
  end

  def apple_signing_key_available?
    ENV['APPLE_TEAM_ID'].present? && ENV['APPLE_BUNDLE_ID'].present? && ENV['APPLE_KEY_ID'].present? && ENV['APPLE_PRIVATE_KEY'].present?
  end

  def exchange_authorization_code(code)
    return nil unless apple_signing_key_available?

    secret = client_secret
    return nil if secret.blank?

    uri = URI('https://appleid.apple.com/auth/token')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request.set_form_data(
      'client_id' => ENV['APPLE_BUNDLE_ID'],
      'client_secret' => secret,
      'code' => code,
      'grant_type' => 'authorization_code'
    )

    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)['refresh_token']
  rescue => e
    Rails.logger.error "[AppleAuthService] Failed to exchange authorization code: #{e.message}"
    nil
  end

  def self.revoke_tokens_for(user)
    return unless user&.provider == 'apple'
    return if user.oauth_refresh_token.blank?

    secret = new(nil, nil, 'buyer').client_secret
    return if secret.blank?

    uri = URI('https://appleid.apple.com/auth/revoke')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request.set_form_data(
      'client_id' => ENV['APPLE_BUNDLE_ID'],
      'client_secret' => secret,
      'token' => user.oauth_refresh_token,
      'token_type_hint' => 'refresh_token'
    )

    response = http.request(request)
    Rails.logger.info "[AppleAuthService] Revoke response: #{response.code}"
  rescue => e
    Rails.logger.error "[AppleAuthService] Failed to revoke Apple tokens: #{e.message}"
  end

  def format_user_response(user)
    role = determine_role(user)

    response = {
      id: user.id,
      email: user.email,
      role: role.downcase
    }

    if user.respond_to?(:fullname) && user.fullname.present?
      response[:name] = user.fullname
    elsif user.respond_to?(:username) && user.username.present?
      response[:name] = user.username
    end

    if user.respond_to?(:username) && user.username.present?
      response[:username] = user.username
    end

    if user.respond_to?(:profile_picture) && user.profile_picture.present?
      response[:profile_picture] = user.profile_picture
    end

    if user.respond_to?(:enterprise_name) && user.enterprise_name.present?
      response[:enterprise_name] = user.enterprise_name
    end

    if user.respond_to?(:phone_number) && user.phone_number.present?
      response[:phone_number] = user.phone_number
    end

    if role == 'Seller'
      response[:location] = user.location if user.respond_to?(:location)
      response[:county_id] = user.county_id if user.respond_to?(:county_id)
      response[:sub_county_id] = user.sub_county_id if user.respond_to?(:sub_county_id)
      response[:description] = user.description if user.respond_to?(:description)
      response[:ads_count] = user.ads.count if user.respond_to?(:ads)
    end

    response
  end
end
