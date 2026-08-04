require 'net/http'
require 'json'
require 'base64'

class IapValidationService
  PRODUCTION_VERIFY_URL = 'https://buy.itunes.apple.com/verifyReceipt'.freeze
  SANDBOX_VERIFY_URL = 'https://sandbox.itunes.apple.com/verifyReceipt'.freeze

  def self.validate(platform, receipt, product_id, seller_id = nil)
    return { success: false, error: 'Only iOS IAP is supported' } unless platform.to_s == 'ios'

    result = verify_apple_receipt(receipt)
    return { success: false, error: result[:error] } unless result[:success]

    in_app = result.dig(:response, 'receipt', 'in_app') || []
    matching = in_app.find { |tx| tx['product_id'] == product_id }
    return { success: false, error: 'Product not found in receipt' } if matching.blank?

    # TODO: create PaymentTransaction + SellerTier once products and pricing are configured

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
end
