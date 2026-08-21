class SendAccurateListingsWhatsappJob < ApplicationJob
  queue_as :default

  def perform(seller_email)
    seller = Seller.find_by(email: seller_email)

    if seller.nil?
      Rails.logger.error "SendAccurateListingsWhatsappJob: Seller with email #{seller_email} not found"
      return
    end

    begin
      sent_channels = []

      if seller.phone_number.present?
        whatsapp_result = WhatsAppCloudService.send_template(
          seller.phone_number,
          'accurate_listings',
          'en'
        )

        if whatsapp_result.is_a?(Hash) && whatsapp_result[:success]
          sent_channels << "whatsapp"
          WhatsappMessageLog.mark_as_sent(
            seller,
            'accurate_listings',
            seller.phone_number,
            whatsapp_result[:message_id]
          )
        else
          error_msg = whatsapp_result.is_a?(Hash) ? whatsapp_result[:error] : 'Unknown error'
          Rails.logger.warn "Failed to send WhatsApp template to #{seller.phone_number}: #{error_msg}"
        end
      else
        Rails.logger.warn "Seller #{seller.id} has no phone number - skipping WhatsApp message"
      end

      send_in_app_accurate_listings_message(seller)

      if sent_channels.empty?
        Rails.logger.warn "No communication channels were successfully used for seller #{seller.id}"
      end

    rescue => e
      Rails.logger.error "SendAccurateListingsWhatsappJob: Failed to send message to seller #{seller_email}: #{e.message}"
      raise e
    end
  end

  private

  def send_in_app_accurate_listings_message(seller)
    full_name = seller.fullname.presence || seller.enterprise_name.presence || "Dear Seller"
    
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

      You can review and update your listings directly from your [Dashboard](https://carboncube-ke.com/seller/ads?utm_source=in_app&utm_medium=messaging&utm_campaign=accurate_listings).

      Thank you for being our seller.

      Best regards,
      **Carbon Cube Kenya**
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
      seller_id: seller.id,
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
    
    Rails.logger.info "In-app message sent to seller #{seller.id} (Conv: #{conversation.id}, Msg: #{message.id})"
  rescue => e
    Rails.logger.error "Failed to send in-app message to seller #{seller.id}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end
end
