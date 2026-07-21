require 'timeout'

class SendSellerCommunicationJob < ApplicationJob
  queue_as :default

  def perform(user_id, email_type = 'general_update', channels = { email: true, whatsapp: false }, custom_subject = nil, custom_message = nil, user_type = 'seller')
    if email_type == 'black_friday'
      Rails.logger.warn "SendSellerCommunicationJob: Black Friday emails are disabled."
      return
    end
    
    model_class = case user_type
    when 'buyer'
      Buyer
    when 'sellers', 'seller'
      Seller
    else
      Seller
    end
    
    user = model_class.includes(:ads, :reviews).find_by(id: user_id)

    if user.nil?
      Rails.logger.error "SendSellerCommunicationJob: #{user_type.capitalize} with ID #{user_id} not found"
      return
    end

    begin
      sent_channels = []

      if channels[:email] || channels['email']
        case email_type
        when 'general_update'
          if custom_subject.present? && custom_message.present?
            mail = SellerCommunicationsMailer.with(user: user, user_type: user_type, subject: custom_subject, message: custom_message).custom_communication
          else
            mail = SellerCommunicationsMailer.with(seller: user).general_update
          end
          Timeout.timeout(30) { mail.deliver_now }
        when 'black_friday'
          mail = SellerCommunicationsMailer.with(seller: user).black_friday_email
          mail.deliver_now
        when 'listing_reminder'
          mail = SellerCommunicationsMailer.with(seller: user).listing_reminder
          Timeout.timeout(30) { mail.deliver_now }
          send_in_app_listing_reminder(user) if user_type == 'seller'
        when 'share_shop_feature'
          mail = SellerCommunicationsMailer.with(seller: user).share_shop_feature
          Timeout.timeout(30) { mail.deliver_now }
          send_in_app_share_shop_feature(user) if user_type == 'seller'
        when 'accurate_listings'
          mail = SellerCommunicationsMailer.with(seller: user).accurate_listings
          Timeout.timeout(30) { mail.deliver_now }
          send_in_app_accurate_listings(user) if user_type == 'seller'
        else
          Rails.logger.error "SendSellerCommunicationJob: Unknown email type '#{email_type}'"
          return
        end

        sent_channels << "email"
      end

      if channels[:whatsapp] || channels['whatsapp']
        if user.phone_number.present?
          if custom_message.present?
            message_text = process_whatsapp_markdown(custom_message, user, user_type)
          else
            message_text = build_communication_message(user, user_type, email_type)
          end

          whatsapp_result = WhatsAppCloudService.send_message(user.phone_number, message_text)

          if whatsapp_result.is_a?(Hash) && whatsapp_result[:success]
            sent_channels << "whatsapp"
          else
            error_msg = whatsapp_result.is_a?(Hash) ? whatsapp_result[:error] : 'Unknown error'
            Rails.logger.warn "Failed to send WhatsApp message to #{user.phone_number}: #{error_msg}"
          end
        else
          Rails.logger.warn "#{user_type.capitalize} #{user.id} has no phone number - skipping WhatsApp message"
        end
      end

      if sent_channels.empty?
        Rails.logger.warn "No communication channels were successfully used for #{user_type} #{user.id}"
      end

    rescue => e
      Rails.logger.error "SendSellerCommunicationJob: Failed to send email to #{user_type} #{user_id}: #{e.message}"
      raise e
    end
  end

  private

  def process_whatsapp_markdown(message, user, user_type)
    formatted_message = message.dup

    formatted_message = formatted_message
      .gsub(/^### (.*)$/, '*\1*')
      .gsub(/^## (.*)$/, '*\1*')
      .gsub(/^# (.*)$/, '*\1*')
      .gsub(/\*\*(.*?)\*\*/, '*\1*')
      .gsub(/(?<!\*)\*([^*\n]+)\*(?!\*)/, '_\1_')
      .gsub(/~~(.*?)~~/, '~\1~')
      .gsub(/`([^`]+)`/, '```\1```')
      .gsub(/^> (.*)$/, '_\1_')
      .gsub(/^\* (.*)$/, '• \1')
      .gsub(/^\d+\. (.*)$/, '• \1')
      .gsub(/\n{3,}/, "\n\n")

    user_name = if user_type == 'seller'
      user.fullname.presence || user.enterprise_name.presence || 'Seller'
    else
      user.fullname.presence || user.username.presence || 'Buyer'
    end

    unless formatted_message =~ /^Hello/i || formatted_message =~ /^Hi/i
      formatted_message = "Hello *#{user_name}*,\n\n#{formatted_message}"
    end

    formatted_message
  end

  def build_communication_message(user, user_type, email_type)
    user_name = if user_type == 'seller'
      user.fullname.presence || user.enterprise_name.presence || 'Seller'
    else
      user.fullname.presence || user.username.presence || 'Buyer'
    end

    case email_type
    when 'general_update'
      <<~MESSAGE
        🔔 *Carbon Cube Kenya Update*

        Hi #{user_name},

        We wanted to share an important update with you.

        For more details, please check your email.

        ────────────────
        *Carbon Cube Kenya*
      MESSAGE
    when 'accurate_listings'
      <<~MESSAGE
        🔔 *Build Trust through Accurate Listings*

        Hi #{user_name},

        Trust begins with honest product information.

        To help buyers make informed decisions:
        • Use genuine product photos.
        • Provide accurate descriptions.
        • Display correct pricing.
        • Update listings whenever details change.

        Clear and accurate listings help build confidence in your business and create a better marketplace experience for everyone.

        ────────────────
        *Carbon Cube Kenya*
      MESSAGE
    else
      "Hello #{user_name}, you have an important update from Carbon Cube Kenya. Please check your email for details."
    end
  end

  def send_in_app_listing_reminder(user)
    full_name = user.fullname.presence || "Partner"
    
    markdown_content = <<~MARKDOWN
      **Listing Update Reminder**

      Greetings **#{full_name}**,

      We hope this finds you well.

      This is a quick reminder to review and keep your listings on **Carbon Cube Kenya** up to date.
      Regular updates help ensure your products remain visible and relevant to buyers browsing the platform.

      You can manage your listings at your convenience by visiting your [Dashboard](https://carboncube-ke.com/seller/ads?utm_source=listing_reminder&utm_medium=in_app&utm_campaign=listing_update).

      If you require any assistance, feel free to reach out.

      Thank you.

      Kind Regards,
      **Carbon Cube Team**
    MARKDOWN

    system_admin = Rails.cache.fetch("system_admin_user", expires_in: 1.hour) do
      Admin.find_by(email: 'support@carboncube-ke.com') || 
             Admin.find_by(username: 'admin') || 
             Admin.first
    end

    unless system_admin
      Rails.logger.error "Cannot send in-app message: No Admin user found in database"
      return
    end

    conversation = Conversation.find_or_create_by!(
      admin_id: system_admin.id,
      seller_id: user.id,
      ad_id: nil,
      buyer_id: nil,
      inquirer_seller_id: nil
    )

    message = conversation.messages.create!(
      content: markdown_content,
      sender: system_admin
    )
    
    begin
      UpdateUnreadCountsJob.perform_later(conversation.id, message.id)
    rescue => e
      Rails.logger.warn "Failed to enqueue unread count update: #{e.message}"
    end
  rescue => e
    Rails.logger.error "Failed to send in-app message to seller #{user.id}: #{e.message}"
  end

  def send_in_app_share_shop_feature(user)
    full_name = user.fullname.presence || "Partner"
    
    markdown_content = <<~MARKDOWN
      **"Share Shop" Feature Highlight**

      Greetings **#{full_name}**,

      We hope you are well.

      This is to highlight the **"Share Shop"** feature available on your Carbon Cube Kenya seller dashboard. The feature allows you to generate a direct link to your shop, making it easier to present your products in one place when needed.

      The link reflects your current listings as displayed on the platform and can be used across your preferred communication channels.

      You can access and manage this feature directly from your [Dashboard](https://carboncube-ke.com/seller/dashboard?utm_source=in_app&utm_medium=seller_communication&utm_campaign=share_shop_feature).

      For any questions or clarification, feel free to reach out.

      Best regards,
      **Carbon Cube Kenya Team**
    MARKDOWN

    system_admin = Rails.cache.fetch("system_admin_user", expires_in: 1.hour) do
      Admin.find_by(email: 'support@carboncube-ke.com') || 
             Admin.find_by(username: 'admin') || 
             Admin.first
    end

    unless system_admin
      Rails.logger.error "Cannot send in-app message: No Admin user found in database"
      return
    end

    conversation = Conversation.find_or_create_by!(
      admin_id: system_admin.id,
      seller_id: user.id,
      ad_id: nil,
      buyer_id: nil,
      inquirer_seller_id: nil
    )

    message = conversation.messages.create!(
      content: markdown_content,
      sender: system_admin
    )
    
    begin
      UpdateUnreadCountsJob.perform_later(conversation.id, message.id)
    rescue => e
      Rails.logger.warn "Failed to enqueue unread count update: #{e.message}"
    end
    
  rescue => e
    Rails.logger.error "Failed to send in-app Share Shop message to seller #{user.id}: #{e.message}"
  end

  def send_in_app_accurate_listings(user)
    full_name = user.fullname.presence || "Partner"
    
    markdown_content = <<~MARKDOWN
      **Build Trust through Accurate Listings**

      Greetings **#{full_name}**,

      Trust begins with honest product information.

      To help buyers make informed decisions:
      • Use genuine product photos.
      • Provide accurate descriptions.
      • Display correct pricing.
      • Update listings whenever details change.

      Clear and accurate listings help build confidence in your business and create a better marketplace experience for everyone.

      You can review and update your listings directly from your [Dashboard](https://carboncube-ke.com/seller/ads?utm_source=in_app&utm_medium=seller_communication&utm_campaign=accurate_listings).

      Best regards,
      **Carbon Cube Kenya Team**
    MARKDOWN

    system_admin = Rails.cache.fetch("system_admin_user", expires_in: 1.hour) do
      Admin.find_by(email: 'support@carboncube-ke.com') || 
             Admin.find_by(username: 'admin') || 
             Admin.first
    end

    unless system_admin
      Rails.logger.error "Cannot send in-app message: No Admin user found in database"
      return
    end

    conversation = Conversation.find_or_create_by!(
      admin_id: system_admin.id,
      seller_id: user.id,
      ad_id: nil,
      buyer_id: nil,
      inquirer_seller_id: nil
    )

    message = conversation.messages.create!(
      content: markdown_content,
      sender: system_admin
    )
    
    begin
      UpdateUnreadCountsJob.perform_later(conversation.id, message.id)
    rescue => e
      Rails.logger.warn "Failed to enqueue unread count update: #{e.message}"
    end
    
  rescue => e
    Rails.logger.error "Failed to send in-app Accurate Listings message to seller #{user.id}: #{e.message}"
  end
end
