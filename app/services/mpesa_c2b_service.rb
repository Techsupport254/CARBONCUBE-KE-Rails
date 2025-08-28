require 'httparty'
require 'base64'

class MpesaC2bService
  # This class handles the M-Pesa C2B (Customer to Business) payment process.
  BASE_URL_API = Rails.env.production? ? "https://api.safaricom.co.ke" : "https://sandbox.safaricom.co.ke"

  def self.access_token
    credentials = Base64.strict_encode64("#{ENV['MPESA_CONSUMER_KEY']}:#{ENV['MPESA_CONSUMER_SECRET']}")
    
    response = HTTParty.get(
      "#{BASE_URL_API}/oauth/v2/generate?grant_type=client_credentials",
      headers: { "Authorization" => "Basic #{credentials}" }
    )

    if response.code == 200
      token = JSON.parse(response.body)["access_token"]
      Rails.logger.info("✅ M-Pesa Access Token Retrieved")
      token
    else
      Rails.logger.error("❌ Failed to retrieve access token: #{response.body}")
      nil
    end
  end
end
