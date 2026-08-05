# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

# Script to send the approved WhatsApp template 'marketing_campaign'
# Uses the exact video uploaded during template creation on Meta.
# Supports both Sellers and Buyers.
#
# Usage:
#   Test single email (Seller or Buyer):
#     bundle exec rails runner scripts/send_marketing_campaign.rb user@gmail.com
#   Send to all Buyers in database:
#     bundle exec rails runner scripts/send_marketing_campaign.rb --buyers
#   Send to all Sellers in database:
#     bundle exec rails runner scripts/send_marketing_campaign.rb --sellers
#   Send to matched sellers JSON:
#     bundle exec rails runner scripts/send_marketing_campaign.rb --matched-sellers

target = ARGV[0] || 'optisoftkenya@gmail.com'

phone_number_id = ENV['WHATSAPP_CLOUD_PHONE_NUMBER_ID']
access_token = ENV['WHATSAPP_CLOUD_ACCESS_TOKEN']
waba_id = ENV['WHATSAPP_CLOUD_WABA_ID']

if phone_number_id.blank? || access_token.blank? || waba_id.blank?
  puts "❌ Error: Missing WHATSAPP_CLOUD_PHONE_NUMBER_ID, WHATSAPP_CLOUD_ACCESS_TOKEN, or WHATSAPP_CLOUD_WABA_ID in environment."
  exit 1
end

def get_or_upload_template_video(waba_id, phone_number_id, access_token)
  puts "🔍 Fetching exact video uploaded during template creation from Meta..."
  
  uri = URI("https://graph.facebook.com/v20.0/#{waba_id}/message_templates?name=marketing_campaign")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  req = Net::HTTP::Get.new(uri)
  req['Authorization'] = "Bearer #{access_token}"

  res = http.request(req)
  data = JSON.parse(res.body) rescue {}
  header_handle = data.dig('data', 0, 'components', 0, 'example', 'header_handle', 0)

  if header_handle.blank?
    puts "⚠️ Warning: Could not find header_handle in template definition."
    return nil
  end

  tmp_file = '/tmp/actual_meta_template_video.mp4'
  puts "📥 Downloading template video file (5.1 MB)..."
  system("curl -s -L -o '#{tmp_file}' '#{header_handle}'")

  unless File.exist?(tmp_file) && File.size(tmp_file) > 0
    puts "❌ Failed to download template video file."
    return nil
  end

  puts "📤 Uploading actual video file to Meta WhatsApp Media API..."
  cmd = "curl -s -X POST 'https://graph.facebook.com/v20.0/#{phone_number_id}/media' " \
        "-H 'Authorization: Bearer #{access_token}' " \
        "-F 'file=@#{tmp_file};type=video/mp4' " \
        "-F 'type=video/mp4' " \
        "-F 'messaging_product=whatsapp'"

  upload_res = `#{cmd}`
  media_id = JSON.parse(upload_res)['id'] rescue nil

  if media_id
    puts "✅ Successfully generated Media ID for your uploaded video: #{media_id}"
    media_id
  else
    puts "❌ Media upload failed: #{upload_res}"
    nil
  end
end

$template_media_id = get_or_upload_template_video(waba_id, phone_number_id, access_token)

if $template_media_id.nil?
  puts "❌ Aborting: Could not obtain Media ID for template video."
  exit 1
end

def send_whatsapp_marketing_campaign(phone, name_param, secondary_param, media_id, phone_number_id, access_token)
  clean_phone = phone.to_s.gsub(/\D/, '')
  clean_phone = "254#{clean_phone[1..-1]}" if clean_phone.start_with?('0')

  uri = URI("https://graph.facebook.com/v20.0/#{phone_number_id}/messages")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  payload = {
    messaging_product: 'whatsapp',
    recipient_type: 'individual',
    to: clean_phone,
    type: 'template',
    template: {
      name: 'marketing_campaign',
      language: { code: 'en' },
      components: [
        {
          type: 'header',
          parameters: [
            {
              type: 'video',
              video: { id: media_id }
            }
          ]
        },
        {
          type: 'body',
          parameters: [
            {
              type: 'text',
              parameter_name: 'seller_name',
              text: name_param
            },
            {
              type: 'text',
              parameter_name: 'enterprise_name',
              text: secondary_param
            }
          ]
        }
      ]
    }
  }

  req = Net::HTTP::Post.new(uri.path)
  req['Authorization'] = "Bearer #{access_token}"
  req['Content-Type'] = 'application/json'
  req.body = payload.to_json

  begin
    response = http.request(req)
    result = JSON.parse(response.body)

    if response.code.to_i == 200
      msg_id = result.dig('messages', 0, 'id')
      puts "  ✅ Success -> Sent to #{name_param} (#{clean_phone}) | Msg ID: #{msg_id}"
      { success: true, message_id: msg_id }
    else
      err_msg = result.dig('error', 'message') || 'Unknown error'
      puts "  ❌ Error for #{name_param} (#{clean_phone}): #{err_msg}"
      { success: false, error: err_msg }
    end
  rescue StandardError => e
    puts "  ❌ Exception sending to #{clean_phone}: #{e.message}"
    { success: false, error: e.message }
  end
end

def extract_params(user, is_buyer)
  fullname = user.respond_to?(:fullname) ? user.fullname : (user['fullname'] rescue nil)
  enterprise = user.respond_to?(:enterprise_name) ? user.enterprise_name : (user['enterprise_name'] rescue nil)
  username = user.respond_to?(:username) ? user.username : (user['username'] rescue nil)

  if is_buyer
    s_name = fullname.presence || username.presence || 'Valued Customer'
    e_name = username.presence || fullname.presence || 'Customer'
  else
    s_name = fullname.presence || enterprise.presence || 'Valued Seller'
    e_name = enterprise.presence || fullname.presence || 'Carbon Cube Store'
  end

  [s_name, e_name]
end

case target
when '--buyers'
  puts "🚀 Processing all Buyers from database..."
  buyers = Buyer.all
  target_buyers = buyers.select { |b| b.phone_number.present? || (b.respond_to?(:secondary_phone_number) && b.secondary_phone_number.present?) }
  puts "Found #{buyers.count} total buyers in DB | #{target_buyers.size} have phone numbers."

  target_buyers.each_with_index do |b, idx|
    phone = b.phone_number.presence || (b.respond_to?(:secondary_phone_number) ? b.secondary_phone_number : nil)
    next if phone.blank?

    s_name, e_name = extract_params(b, true)
    puts "[#{idx + 1}/#{target_buyers.size}] Processing Buyer: #{s_name} (#{phone})..."
    send_whatsapp_marketing_campaign(phone, s_name, e_name, $template_media_id, phone_number_id, access_token)
    sleep 0.15
  end

when '--sellers'
  puts "🚀 Processing all Sellers from database..."
  sellers = Seller.all
  target_sellers = sellers.select { |s| s.phone_number.present? || (s.respond_to?(:secondary_phone_number) && s.secondary_phone_number.present?) }
  puts "Found #{sellers.count} total sellers in DB | #{target_sellers.size} have phone numbers."

  target_sellers.each_with_index do |s, idx|
    phone = s.phone_number.presence || (s.respond_to?(:secondary_phone_number) ? s.secondary_phone_number : nil)
    next if phone.blank?

    s_name, e_name = extract_params(s, false)
    puts "[#{idx + 1}/#{target_sellers.size}] Processing Seller: #{s_name} (#{phone})..."
    send_whatsapp_marketing_campaign(phone, s_name, e_name, $template_media_id, phone_number_id, access_token)
    sleep 0.15
  end

when '--matched-sellers'
  puts "🚀 Processing matched sellers from JSON..."
  json_path = Rails.root.join('../matched_sellers.json')
  unless File.exist?(json_path)
    puts "❌ File not found: #{json_path}"
    exit 1
  end

  sellers = JSON.parse(File.read(json_path))
  sellers.each_with_index do |s, idx|
    phone = s['phone_number']
    next if phone.blank?

    s_name, e_name = extract_params(s, false)
    puts "[#{idx + 1}/#{sellers.size}] Processing Seller: #{s_name}..."
    send_whatsapp_marketing_campaign(phone, s_name, e_name, $template_media_id, phone_number_id, access_token)
    sleep 0.15
  end

else
  puts "🎯 Target mode for: #{target}"
  
  seller = Seller.find_by(email: target) || Seller.find_by(phone_number: target)
  buyer = seller ? nil : (Buyer.find_by(email: target) || Buyer.find_by(phone_number: target))

  user = seller || buyer
  is_buyer = buyer.present?

  unless user
    puts "❌ Could not find Seller or Buyer with email/phone: #{target}"
    exit 1
  end

  type_label = is_buyer ? 'Buyer' : 'Seller'
  phone = user.phone_number.presence || (user.respond_to?(:secondary_phone_number) ? user.secondary_phone_number : nil)
  s_name, e_name = extract_params(user, is_buyer)

  puts "Found #{type_label}: #{s_name} | Phone: #{phone} | Parameter 1 (Name): #{s_name} | Parameter 2: #{e_name}"
  send_whatsapp_marketing_campaign(phone, s_name, e_name, $template_media_id, phone_number_id, access_token)
end
