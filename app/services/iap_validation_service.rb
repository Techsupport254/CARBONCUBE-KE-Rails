require 'net/http'
require 'json'
require 'base64'

class IapValidationService
  PRODUCTION_VERIFY_URL = 'https://buy.itunes.apple.com/verifyReceipt'.freeze
  SANDBOX_VERIFY_URL = 'https://sandbox.itunes.apple.com/verifyReceipt'.freeze
  PRODUCTION_SK2_URL = 'https://api.storekit.itunes.apple.com/inApps/v1'.freeze
  SANDBOX_SK2_URL = 'https://api.storekit-sandbox.itunes.apple.com/inApps/v1'.freeze

  def self.validate(platform, payload, product_id, seller_id = nil)
    return { success: false, error: 'Only iOS IAP is supported' } unless platform.to_s == 'ios'

    if storekit2_transaction?(payload)
      result = validate_storekit2_transaction(payload, product_id)
    else
      result = validate_legacy_receipt(payload, product_id)
    end

    return { success: false, error: result[:error] } unless result[:success]

    if seller_id.present?
      activation = activate_premium_tier(seller_id, product_id, result[:transaction_id])
      return { success: false, error: activation[:error] } unless activation[:success]
    end

    { success: true, transaction_id: result[:transaction_id] }
  end

  def self.storekit2_transaction?(payload)
    payload.to_s.length < 500
  end

  def self.validate_legacy_receipt(receipt, product_id)
    result = verify_apple_receipt(receipt)
    return result unless result[:success]

    in_app = result.dig(:response, 'receipt', 'in_app') || []
    matching = in_app.find { |tx| tx['product_id'] == product_id }
    return { success: false, error: 'Product not found in receipt' } if matching.blank?

    { success: true, transaction_id: matching['transaction_id'] }
  end

  def self.verify_apple_receipt(receipt, sandbox = false)
    url = sandbox ? SANDBOX_VERIFY_URL : PRODUCTION_VERIFY_URL
    body = {
      'receipt-data' => receipt,
      'exclude-old-transactions' => false
    }.to_json

    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    request.body = body

    response = http.request(request)
    parsed = JSON.parse(response.body)
    status = parsed['status']

    if status == 0
      { success: true, response: parsed }
    elsif status == 21_007 && !sandbox
      # Sandbox receipt sent to production; retry with sandbox
      verify_apple_receipt(receipt, true)
    else
      { success: false, error: "Apple receipt validation failed: #{status}" }
    end
  rescue => e
    Rails.logger.error "[IapValidationService] #{e.class}: #{e.message}"
    { success: false, error: 'IAP validation failed' }
  end

  def self.validate_storekit2_transaction(transaction_id, product_id)
    return { success: false, error: 'Missing StoreKit 2 configuration' } unless storekit2_configured?

    url = "#{storekit2_base_url}/transactions/#{transaction_id}"
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{storekit2_jwt}"

    response = http.request(request)
    return { success: false, error: "Apple StoreKit 2 API error: #{response.code}" } unless response.is_a?(Net::HTTPSuccess)

    parsed = JSON.parse(response.body)
    signed_transaction = parsed['signedTransactionInfo']
    return { success: false, error: 'Missing signed transaction info' } if signed_transaction.blank?

    transaction = decode_jws_payload(signed_transaction)
    return { success: false, error: 'Invalid transaction payload' } if transaction.blank?

    unless transaction['productId'] == product_id
      return { success: false, error: 'Product ID mismatch' }
    end

    unless transaction['transactionState'].to_s == '1'
      return { success: false, error: 'Transaction not in purchased state' }
    end

    { success: true, transaction_id: transaction['transactionId'] }
  rescue => e
    Rails.logger.error "[IapValidationService] StoreKit 2 error: #{e.class}: #{e.message}"
    { success: false, error: 'StoreKit 2 validation failed' }
  end

  def self.storekit2_configured?
    %w[APPLE_ISSUER_ID APPLE_IAP_KEY_ID APPLE_BUNDLE_ID APPLE_IAP_PRIVATE_KEY].all? { |k| ENV[k].present? }
  end

  def self.storekit2_base_url
    Rails.env.production? ? PRODUCTION_SK2_URL : SANDBOX_SK2_URL
  end

  def self.storekit2_jwt
    now = Time.now.to_i
    payload = {
      iss: ENV['APPLE_ISSUER_ID'],
      iat: now,
      exp: now + 1200,
      aud: 'appstoreconnect-v1',
      bid: ENV['APPLE_BUNDLE_ID']
    }

    key = OpenSSL::PKey::EC.new(ENV['APPLE_IAP_PRIVATE_KEY'].to_s.gsub('\\n', "\n"))
    JWT.encode(payload, key, 'ES256', { kid: ENV['APPLE_IAP_KEY_ID'], typ: 'JWT' })
  end

  def self.decode_jws_payload(jws)
    parts = jws.split('.')
    return nil if parts.length < 2

    payload = parts[1]
    padding = 4 - payload.length % 4
    payload += '=' * padding if padding < 4
    JSON.parse(Base64.urlsafe_decode64(payload))
  rescue
    nil
  end

  def self.activate_premium_tier(seller_id, product_id, apple_transaction_id)
    seller = Seller.find_by(id: seller_id)
    return { success: false, error: 'Seller not found' } if seller.blank?

    tier_info = parse_iap_product_id(product_id)
    return { success: false, error: 'Unsupported IAP product' } if tier_info.blank?

    tier = Tier.find_by('LOWER(name) = ?', tier_info[:name].downcase)
    return { success: false, error: 'Tier not found' } if tier.blank?

    pricing = TierPricing.find_by(tier: tier, duration_months: tier_info[:months])
    return { success: false, error: 'Pricing not found for this product' } if pricing.blank?

    ActiveRecord::Base.transaction do
      payment_transaction = PaymentTransaction.create!(
        seller: seller,
        tier: tier,
        tier_pricing: pricing,
        amount: pricing.price,
        phone_number: 'N/A',
        status: 'completed',
        transaction_type: 'iap',
        checkout_request_id: apple_transaction_id,
        merchant_request_id: apple_transaction_id,
        completed_at: Time.current
      )

      SellerTier.where(seller_id: seller.id).destroy_all
      SellerTier.create!(
        seller: seller,
        tier: tier,
        duration_months: pricing.duration_months,
        expires_at: pricing.duration_months.months.from_now,
        payment_transaction: payment_transaction
      )
    end

    { success: true }
  rescue => e
    Rails.logger.error "[IapValidationService] Activation error: #{e.class}: #{e.message}"
    { success: false, error: 'Failed to activate seller tier' }
  end

  def self.parse_iap_product_id(product_id)
    # Supports: carbon_premium_1month, carbon_premium_monthly, carbon_basic_3month, etc.
    match = product_id.to_s.match(/\Acarbon_(\w+?)_(\d+)month\z/i)
    return nil unless match

    { name: match[1].capitalize, months: match[2].to_i }
  end
end
