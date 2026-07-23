require 'net/http'
require 'uri'
require 'json'

class SendVerifyBeforeBuyingCampaignJob < ApplicationJob
  queue_as :broadcast

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(user_id, user_type, dry_run = true, channels = { email: true, whatsapp: true })
    model_class = user_type == 'buyer' ? Buyer : Seller
    user = model_class.find_by(id: user_id)

    if user.nil?
      Rails.logger.error "[SendVerifyBeforeBuyingCampaignJob] #{user_type.capitalize} #{user_id} not found."
      return
    end

    email = user.email.to_s.strip.downcase
    phone = user.phone_number.to_s.strip

    if email.blank? && phone.blank?
      Rails.logger.warn "[SendVerifyBeforeBuyingCampaignJob] #{user_type.capitalize} #{user_id} has both blank email and phone number. Skipping."
      return
    end

    email_dedup_key = "campaign:verify_before_buying:sent_emails"
    phone_dedup_key = "campaign:verify_before_buying:sent_phones"

    if channels[:whatsapp] && phone.present?
      already_sent_phone = RedisConnection.with { |conn| conn.sismember(phone_dedup_key, phone) }

      unless already_sent_phone
        unless dry_run
          send_whatsapp_template(user, phone, user_type)
          RedisConnection.with { |conn| conn.sadd(phone_dedup_key, phone) }
        end
      end
    end

    if channels[:in_app] && !dry_run
      send_in_app_message(user, user_type)
    end
  end

  private

  def send_whatsapp_template(user, phone, user_type)
    template_name = user_type == 'seller' ? 'verify_before_buying_sellers_v1' : 'verify_before_buying_buyers_v1'

    result = WhatsAppCloudService.send_template(phone, template_name, 'en_US')

    unless result[:success]
      raise "WhatsApp API failed: #{result[:error]}"
    end

    log_whatsapp_message_to_db(user, result[:message_id], template_name)
  end

  def log_whatsapp_message_to_db(user, whatsapp_message_id, template_name)
    conversation = WhatsAppCloudService.find_or_create_incoming_conversation(user)
    return unless conversation

    system_admin = Admin.find_by(email: 'support@carboncube-ke.com') ||
                   Admin.find_by(username: 'admin') ||
                   Admin.first

    return unless system_admin

    body_text = <<~TEXT
      **Verify Before You Buy**

      Hello,

      Before purchasing a product, ask the seller any questions you may have. _Confirm the product details, price, and condition_ to help you make an informed decision.

      ⚠️ **Important:** Avoid making full payment before receiving or inspecting the product unless you trust the seller.

      **Shop smart and make informed decisions.**

      Regards,
      **Carbon Cube Kenya**
    TEXT

    if template_name == 'verify_before_buying_sellers_v1'
      body_text += "\n\n**Quick Links:**\n"
      body_text += "• [Your Dashboard](https://carboncube-ke.com/seller/dashboard?utm_source=whatsapp&utm_medium=broadcast&utm_campaign=verify_before_buying&utm_content=seller_dashboard)\n"
      body_text += "• [Manage Your Ads](https://carboncube-ke.com/seller/ads?utm_source=whatsapp&utm_medium=broadcast&utm_campaign=verify_before_buying&utm_content=seller_ads)"
    else
      body_text += "\n\n**Quick Links:**\n"
      body_text += "• [Browse Products](https://carboncube-ke.com/?utm_source=whatsapp&utm_medium=broadcast&utm_campaign=verify_before_buying&utm_content=home)"
    end

    message = conversation.messages.build(
      content: body_text,
      sender: system_admin,
      whatsapp_message_id: whatsapp_message_id,
      status: Message::STATUS_SENT
    )

    if message.save
      Rails.logger.info "[SendVerifyBeforeBuyingCampaignJob] WhatsApp template logged to DB: message_id=#{message.id}"
    else
      Rails.logger.error "[SendVerifyBeforeBuyingCampaignJob] Failed to log WhatsApp template to DB: #{message.errors.full_messages.join(', ')}"
    end
  end

  def send_in_app_message(user, user_type)
    full_name = user.fullname.presence || user.enterprise_name.presence || (user_type == 'seller' ? 'Dear Seller' : 'Hello')

    if user_type == 'seller'
      markdown_content = <<~MARKDOWN
        **Verify Before You Buy**

        Hello **#{full_name}**,

        Before purchasing a product, ask the seller any questions you may have. _Confirm the product details, price, and condition_ to help you make an informed decision.

        ⚠️ **Important:** Avoid making full payment before receiving or inspecting the product unless you trust the seller.

        **Shop smart and make informed decisions.**

        **Quick Links:**
        • [Your Dashboard](https://carboncube-ke.com/seller/dashboard?utm_source=in_app&utm_medium=messaging&utm_campaign=verify_before_buying&utm_content=seller_dashboard)
        • [Manage Your Ads](https://carboncube-ke.com/seller/ads?utm_source=in_app&utm_medium=messaging&utm_campaign=verify_before_buying&utm_content=seller_ads)

        Regards,
        **Carbon Cube Kenya**
      MARKDOWN
    else
      markdown_content = <<~MARKDOWN
        **Verify Before You Buy**

        Hello **#{full_name}**,

        Before purchasing a product, ask the seller any questions you may have. _Confirm the product details, price, and condition_ to help you make an informed decision.

        ⚠️ **Important:** Avoid making full payment before receiving or inspecting the product unless you trust the seller.

        **Shop smart and make informed decisions.**

        **Quick Links:**
        • [Browse Products](https://carboncube-ke.com/?utm_source=in_app&utm_medium=messaging&utm_campaign=verify_before_buying&utm_content=home)

        Regards,
        **Carbon Cube Kenya**
      MARKDOWN
    end

    system_admin = Rails.cache.fetch("system_admin_user", expires_in: 1.hour) do
      Admin.find_by(email: 'support@carboncube-ke.com') ||
        Admin.find_by(username: 'admin') ||
        Admin.first
    end

    unless system_admin
      Rails.logger.error "[SendVerifyBeforeBuyingCampaignJob] Cannot send in-app message: No Admin user found in database"
      return
    end

    conversation = Conversation.find_or_create_conversation!(
      admin_id: system_admin.id,
      seller_id: user_type == 'seller' ? user.id : nil,
      buyer_id: user_type == 'buyer' ? user.id : nil,
      ad_id: nil,
      inquirer_seller_id: nil
    )

    message = conversation.messages.create!(
      content: markdown_content,
      sender: system_admin
    )

    begin
      UpdateUnreadCountsJob.perform_later(conversation.id, message.id)
    rescue => e
      Rails.logger.warn "[SendVerifyBeforeBuyingCampaignJob] Failed to enqueue unread count update: #{e.message}"
    end

    # Explicitly send email notification since the after_create callback
    # skips email when conversation.is_whatsapp? is true (WhatsApp broadcast
    # conversations are marked is_whatsapp: true by find_or_create_incoming_conversation)
    if user.email.present?
      begin
        MessageNotificationMailer.new_message_notification(message, user).deliver_now
        Rails.logger.info "[SendVerifyBeforeBuyingCampaignJob] Email notification sent to #{user.email}"
      rescue => e
        Rails.logger.error "[SendVerifyBeforeBuyingCampaignJob] Failed to send email notification: #{e.message}"
      end
    end

    Rails.logger.info "[SendVerifyBeforeBuyingCampaignJob] In-app message sent to #{user_type} #{user.id} (Conv: #{conversation.id}, Msg: #{message.id})"
  rescue => e
    Rails.logger.error "[SendVerifyBeforeBuyingCampaignJob] Failed to send in-app message to #{user_type} #{user.id}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end
end
