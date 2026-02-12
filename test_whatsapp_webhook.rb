
require 'openssl'
require 'json'
require 'net/http'
require 'uri'

app_secret = '066a0dca13e346f05c825fd061c5065e'
payload = {
  object: 'whatsapp_business_account',
  entry: [
    {
      id: '123456789',
      changes: [
        {
          value: {
            messaging_product: 'whatsapp',
            metadata: {
              display_phone_number: '123456789',
              phone_number_id: '982455534949016'
            },
            messages: [
              {
                from: '254716404137',
                id: 'wamid.HBgMMjU0NzE2NDA0MTM3FQIAERgSRUY2NEFBQjk0MjgwRTMzNEFGAA==',
                timestamp: '1623123456',
                text: {
                  body: 'Testing incoming message from WhatsApp Cloud API!'
                },
                type: 'text'
              }
            ]
          },
          field: 'messages'
        }
      ]
    }
  ]
}.to_json

signature = 'sha256=' + OpenSSL::HMAC.hexdigest('sha256', app_secret, payload)

uri = URI('http://localhost:3001/webhooks/whatsapp')
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Post.new(uri.path)
request['X-Hub-Signature-256'] = signature
request['Content-Type'] = 'application/json'
request.body = payload

response = http.request(request)
puts "Response Code: #{response.code}"
puts "Response Body: #{response.body}"
