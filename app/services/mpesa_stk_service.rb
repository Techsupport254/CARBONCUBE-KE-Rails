require 'httparty'
require 'base64'
require 'securerandom'

class MpesaStkService
  include HTTParty
  
  BASE_URL_API = ENV['MPESA_ENV'] == 'production' ? "https://api.safaricom.co.ke" : "https://sandbox.safaricom.co.ke"
  BUSINESS_SHORT_CODE = ENV['MPESA_ENV'] == 'production' ? ENV['MPESA_BUSINESS_SHORT_CODE'] : "174379"
  PASSKEY = ENV['MPESA_ENV'] == 'production' ? ENV['MPESA_PASSKEY'] : "bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919"
  CALLBACK_URL = ENV['MPESA_ENV'] == 'production' ? ENV['MPESA_CALLBACK_URL'] : "http://localhost:3001/payments/stk_callback"

  def self.access_token
    credentials = Base64.strict_encode64("#{ENV['MPESA_CONSUMER_KEY']}:#{ENV['MPESA_CONSUMER_SECRET']}")
    
    response = HTTParty.get(
      "#{BASE_URL_API}/oauth/v2/generate?grant_type=client_credentials",
      headers: { "Authorization" => "Basic #{credentials}" }
    )

    if response.code == 200
      token = JSON.parse(response.body)["access_token"]
      Rails.logger.info("M-Pesa Access Token Retrieved")
      token
    else
      Rails.logger.error("Failed to retrieve access token: #{response.body}")
      nil
    end
  end

  def self.initiate_stk_push(phone_number, amount, account_reference, transaction_desc)
    access_token = self.access_token
    return { success: false, error: "Failed to get access token" } unless access_token

    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    password = Base64.strict_encode64("#{BUSINESS_SHORT_CODE}#{PASSKEY}#{timestamp}")
    
    # Format phone number (remove + and ensure it starts with 254)
    formatted_phone = phone_number.gsub(/^\+/, '').gsub(/^0/, '254')
    
    payload = {
      BusinessShortCode: BUSINESS_SHORT_CODE,
      Password: password,
      Timestamp: timestamp,
      TransactionType: "CustomerPayBillOnline",
      Amount: amount.to_i,
      PartyA: formatted_phone,
      PartyB: BUSINESS_SHORT_CODE,
      PhoneNumber: formatted_phone,
      CallBackURL: CALLBACK_URL,
      AccountReference: account_reference,
      TransactionDesc: transaction_desc
    }

    Rails.logger.info("STK Push Payload: #{payload}")

    response = HTTParty.post(
      "#{BASE_URL_API}/mpesa/stkpush/v1/processrequest",
      headers: {
        "Authorization" => "Bearer #{access_token}",
        "Content-Type" => "application/json"
      },
      body: payload.to_json
    )

    Rails.logger.info("STK Push Response: #{response.body}")

    if response.code == 200
      response_data = JSON.parse(response.body)
      if response_data["ResponseCode"] == "0"
        {
          success: true,
          checkout_request_id: response_data["CheckoutRequestID"],
          merchant_request_id: response_data["MerchantRequestID"],
          response_code: response_data["ResponseCode"],
          response_description: response_data["ResponseDescription"],
          customer_message: response_data["CustomerMessage"]
        }
      else
        {
          success: false,
          error: response_data["ResponseDescription"] || "STK Push failed",
          response_code: response_data["ResponseCode"]
        }
      end
    else
      {
        success: false,
        error: "HTTP Error: #{response.code}",
        response_body: response.body
      }
    end
  rescue => e
    Rails.logger.error("STK Push Error: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end

  def self.query_stk_push_status(checkout_request_id)
    access_token = self.access_token
    return { success: false, error: "Failed to get access token" } unless access_token

    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    password = Base64.strict_encode64("#{BUSINESS_SHORT_CODE}#{PASSKEY}#{timestamp}")

    payload = {
      BusinessShortCode: BUSINESS_SHORT_CODE,
      Password: password,
      Timestamp: timestamp,
      CheckoutRequestID: checkout_request_id
    }

    response = HTTParty.post(
      "#{BASE_URL_API}/mpesa/stkpushquery/v1/query",
      headers: {
        "Authorization" => "Bearer #{access_token}",
        "Content-Type" => "application/json"
      },
      body: payload.to_json
    )

    if response.code == 200
      response_data = JSON.parse(response.body)
      {
        success: true,
        result_code: response_data["ResultCode"],
        result_desc: response_data["ResultDesc"],
        checkout_request_id: response_data["CheckoutRequestID"],
        merchant_request_id: response_data["MerchantRequestID"]
      }
    else
      {
        success: false,
        error: "HTTP Error: #{response.code}",
        response_body: response.body
      }
    end
  rescue => e
    Rails.logger.error("STK Query Error: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end
end
