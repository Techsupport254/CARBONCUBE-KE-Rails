namespace :admin do
  desc "Create the seller_listing_update WhatsApp template via Graph API"
  task create_listing_update_template: :environment do
    require 'net/http'
    require 'uri'
    require 'json'

    waba_id = ENV['WHATSAPP_CLOUD_WABA_ID']
    access_token = ENV['WHATSAPP_CLOUD_ACCESS_TOKEN']
    graph_url = 'https://graph.facebook.com/v22.0'

    if waba_id.blank? || access_token.blank?
      puts "❌ Error: WHATSAPP_CLOUD_WABA_ID or WHATSAPP_CLOUD_ACCESS_TOKEN is missing in .env"
      exit 1
    end

    uri = URI("#{graph_url}/#{waba_id}/message_templates")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?

    request = Net::HTTP::Post.new(uri.path)
    request['Authorization'] = "Bearer #{access_token}"
    request['Content-Type'] = 'application/json'

    # The WhatsApp markdown text
    body_text = "Hello *Dear Seller*,\n\nGood product descriptions help customers understand what you are selling. Ensure the *product name*, *price*, and *description* are clear and accurate. When information is simple and complete, customers are more likely to trust your store.\n\nThank you,\n*Carbon Cube Kenya*"

    payload = {
      name: 'seller_listing_update',
      language: 'en',
      category: 'MARKETING',
      components: [
        {
          type: 'BODY',
          text: body_text
        },
        {
          type: 'BUTTONS',
          buttons: [
            {
              type: 'URL',
              text: 'Manage Listings',
              url: 'https://carboncube-ke.com/seller/ads?utm_source=whatsapp&utm_medium=waba_template&utm_campaign=seller_listing_update&utm_term=product_description&utm_content=manage_ads_button'
            },
            {
              type: 'URL',
              text: 'Go to Dashboard',
              url: 'https://carboncube-ke.com/seller/dashboard?utm_source=whatsapp&utm_medium=waba_template&utm_campaign=seller_listing_update&utm_term=product_description&utm_content=dashboard_button'
            }
          ]
        }
      ]
    }

    request.body = payload.to_json

    puts "Sending request to Meta Graph API to create template 'seller_listing_update'..."
    
    begin
      response = http.request(request)
      result = JSON.parse(response.body)

      if response.code.to_i == 200 || response.code.to_i == 201
        puts "✅ Template successfully submitted for creation/approval!"
        puts "ID: #{result['id']}"
        puts "Status: #{result['status']}"
        puts "Category: #{result['category']}"
        
        if result['status'] == 'APPROVED'
          puts "The template is already approved and ready to send."
        else
          puts "The template status is '#{result['status']}'. It may need a few minutes for Meta to review and approve it."
        end
      else
        puts "❌ Failed to create template:"
        puts JSON.pretty_generate(result)
      end
    rescue StandardError => e
      puts "❌ Error connecting to Graph API: #{e.message}"
    end
  end
end
