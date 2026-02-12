
require 'net/http'
require 'uri'
require 'json'

# Load environment variables manually if needed or just use these for testing
ACCESS_TOKEN = 'EAAT7qAZBUmIsBQsCKIjhJY0tiQnGUoWaiZBHhxu1hskKb2drlxGNZAlYADPRcsGFYYLFMWS5rS8PIOrkwLBsjPK5ETm1KrvDZAYRGYqqVf9ckGrrXdS4r406VZAfOkEhrM6WoDWZCDeQB4ZCbZCXKgdpb1DgmkfDawJV0MBJ3EpTdC2QDVEtXAh7JsZBDQLOxKcomdwZDZD'
PHONE_NUMBER_ID = '982455534949016'
RECIPIENT_PHONE = '254716404137'

uri = URI("https://graph.facebook.com/v18.0/#{PHONE_NUMBER_ID}/messages")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE

request = Net::HTTP::Post.new(uri.path)
request['Authorization'] = "Bearer #{ACCESS_TOKEN}"
request['Content-Type'] = 'application/json'

payload = {
  messaging_product: 'whatsapp',
  to: RECIPIENT_PHONE,
  type: 'text',
  text: {
    body: 'Hello from Carbon Cube! This is a test message from the official WhatsApp Cloud API.'
  }
}

request.body = payload.to_json

response = http.request(request)

puts "Status: #{response.code}"
puts "Body: #{response.body}"
