require 'net/http'
require 'uri'
require 'json'

class SendUserBuyingSafetyCampaignJob < ApplicationJob
  queue_as :broadcast

  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(user_id, user_type, dry_run = true, channels = { email: true, whatsapp: true })
    model_class = user_type == 'buyer' ? Buyer : Seller
    user = model_class.find_by(id: user_id)

    if user.nil?
      Rails.logger.error "[SendUserBuyingSafetyCampaignJob] #{user_type.capitalize} #{user_id} not found."
      return
    end

    email = user.email.to_s.strip.downcase
    phone = user.phone_number.to_s.strip

    if email.blank? && phone.blank?
      Rails.logger.warn "[SendUserBuyingSafetyCampaignJob] #{user_type.capitalize} #{user_id} has both blank email and phone number. Skipping."
      return
    end

    email_dedup_key = "campaign:buying_safety:sent_emails"
    phone_dedup_key = "campaign:buying_safety:sent_phones"

    if channels[:email] && email.present?
      already_sent_email = RedisConnection.with { |conn| conn.sismember(email_dedup_key, email) }

      unless already_sent_email
        unless dry_run
          send_email_via_nextjs(user, email, user_type)
          RedisConnection.with { |conn| conn.sadd(email_dedup_key, email) }
        end
      end
    end

    if channels[:whatsapp] && phone.present?
      already_sent_phone = RedisConnection.with { |conn| conn.sismember(phone_dedup_key, phone) }

      unless already_sent_phone
        unless dry_run
          send_whatsapp_template(user, phone, user_type)
          RedisConnection.with { |conn| conn.sadd(phone_dedup_key, phone) }
        end
      end
    end
  end

  private

  def send_email_via_nextjs(user, email, user_type)
    call_center_url = ENV['CALL_CENTER_API_URL'] || (Rails.env.production? ? 'http://victor-calls-ik6o0z:3000' : 'http://localhost:3000')
    uri = URI.parse("#{call_center_url}/api/send-safety")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.read_timeout = 30
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
    token = ENV['ADMIN_API_TOKEN'] || ENV['INTERNAL_API_KEY'] || 'carboncube-internal-campaign-key-2026-xyz'
    request['Authorization'] = "Bearer #{token}"
    
    avatar_url = user.respond_to?(:profile_picture) ? user.profile_picture.presence : nil
    shop_name = user_type == 'seller' && user.respond_to?(:enterprise_name) ? user.enterprise_name.presence : nil

    payload = {
      to: email,
      customerName: user.fullname || user.username || 'Customer',
      avatarUrl: avatar_url,
      shopName: shop_name,
      isSeller: user_type == 'seller'
    }

    request.body = payload.to_json

    response = http.request(request)

    unless response.code.to_i == 200
      raise "Next.js email API returned status code #{response.code}: #{response.body}"
    end
  end

  def send_whatsapp_template(user, phone, user_type)
    template_name = user_type == 'seller' ? 'buying_safety_sellers_v1' : 'buying_safety_buyers_v1'
    
    result = WhatsAppCloudService.send_template(phone, template_name, 'en_US')

    unless result[:success]
      raise "WhatsApp API failed: #{result[:error]}"
    end

    log_whatsapp_message_to_db(user, result[:message_id], template_name)
  end

  private

  def log_whatsapp_message_to_db(user, whatsapp_message_id, template_name)
    conversation = WhatsAppCloudService.find_or_create_incoming_conversation(user)
    return unless conversation

    system_admin = Admin.find_by(email: 'support@carboncube-ke.com') || 
                   Admin.find_by(username: 'admin') || 
                   Admin.first
                   
    return unless system_admin

    body_text = <<~TEXT
      Hello,

      For a safer buying experience on *Carbon Cube Kenya*, always _review product details carefully_, ask the seller any questions you may have, and _verify the product_ before making a purchase. 

      ⚠️ *Important:* Avoid making full payment before receiving or inspecting the product unless you trust the seller.

      *Shop smart and make informed decisions.*

      Regards,
      *Carbon Cube Kenya*
    TEXT

    if template_name == 'buying_safety_sellers_v1'
      body_text += "\n\n*Buttons:*\n"
      body_text += "1. *Your Dashboard*: https://carboncube-ke.com/seller/dashboard?utm_source=whatsapp&utm_medium=broadcast&utm_campaign=buying_safety&utm_content=seller_dashboard\n"
      body_text += "2. *Manage Your Ads*: https://carboncube-ke.com/seller/ads?utm_source=whatsapp&utm_medium=broadcast&utm_campaign=buying_safety&utm_content=seller_ads"
    else
      body_text += "\n\n*Buttons:*\n"
      body_text += "1. *Visit Website*: https://carboncube-ke.com/?utm_source=whatsapp&utm_medium=broadcast&utm_campaign=buying_safety&utm_content=home"
    end

    message = conversation.messages.build(
      content: body_text,
      sender: system_admin,
      whatsapp_message_id: whatsapp_message_id,
      status: Message::STATUS_SENT
    )

    if message.save
      Rails.logger.info "[SendUserBuyingSafetyCampaignJob] WhatsApp template logged to DB: message_id=#{message.id}"
    else
      Rails.logger.error "[SendUserBuyingSafetyCampaignJob] Failed to log WhatsApp template to DB: #{message.errors.full_messages.join(', ')}"
    end
  end
end
