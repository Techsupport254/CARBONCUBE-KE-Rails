class SendShopIdentityWhatsAppJob < ApplicationJob
  queue_as :default

  def perform(seller_email)
    unless seller_email == 'optisoftkenya@gmail.com'
      Rails.logger.warn "TEST MODE: Skipping seller #{seller_email} - only optisoftkenya@gmail.com allowed"
      return
    end

    seller = Seller.find_by(email: seller_email)
    
    if seller.nil?
      Rails.logger.error "SendShopIdentityWhatsAppJob: Seller with email #{seller_email} not found"
      return
    end

    begin
      sent_channels = []

      if seller.phone_number.present?
        whatsapp_result = WhatsAppCloudService.send_template(
          seller.phone_number,
          'shop_identity_v4',
          'sw'
        )

        if whatsapp_result.is_a?(Hash) && whatsapp_result[:success]
          sent_channels << "whatsapp"
        else
          error_msg = whatsapp_result.is_a?(Hash) ? whatsapp_result[:error] : 'Unknown error'
          Rails.logger.warn "Failed to send WhatsApp template to #{seller.phone_number}: #{error_msg}"
        end
      else
        Rails.logger.warn "Seller #{seller.id} has no phone number - skipping WhatsApp message"
      end

      send_in_app_shop_identity_message(seller)

      if sent_channels.empty?
        Rails.logger.warn "No communication channels were successfully used for seller #{seller.id}"
      end

    rescue => e
      Rails.logger.error "SendShopIdentityWhatsAppJob: Failed to send message to seller #{seller_email}: #{e.message}"
      raise e
    end
  end

  private

  def send_in_app_shop_identity_message(seller)
    full_name = seller.fullname.presence || seller.enterprise_name.presence || "Muuzaji Mpendwa"
    
    markdown_content = <<~MARKDOWN
      **Jina la Duka na Mahali Lilipo**

      Habari **#{full_name}**,

      Ni muhimu kuhakikisha kuwa jina la duka na mahali lilipo ni sahihi na vinaonekana wazi. Hii husaidia wateja kukufikia kwa urahisi na huongeza uaminifu katika biashara yako.

      Tafadhali ingia kwenye dashboard yako leo na uhakikishe kuwa taarifa hizi ziko sawa.

      **Viungo vya Haraka:**
      • [Badilisha Profaili Yako](https://carboncube-ke.com/seller/profile?utm_source=in_app&utm_medium=messaging&utm_campaign=shop_identity&utm_content=edit_profile)
      • [Dashboard Yako](https://carboncube-ke.com/seller/dashboard?utm_source=in_app&utm_medium=messaging&utm_campaign=shop_identity&utm_content=main_dashboard)

      Asante kwa kuwa muuzaji wetu.

      Kwa heshima,
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
    
  rescue => e
    Rails.logger.error "Failed to send in-app message to seller #{seller.id}: #{e.message}"
  end
end
