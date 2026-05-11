class SendProductDetailsWhatSappJob < ApplicationJob
  queue_as :default

  def perform(seller_email)
    Rails.logger.info "=== PRODUCT DETAILS WHATSAPP JOB START ==="
    Rails.logger.info "Target Email: #{seller_email}"
    
    # TEST MODE: Only send to optisoftkenya@gmail.com
    unless seller_email == 'optisoftkenya@gmail.com'
      Rails.logger.warn "TEST MODE: Skipping seller #{seller_email} - only optisoftkenya@gmail.com allowed"
      Rails.logger.info "=== PRODUCT DETAILS WHATSAPP JOB SKIPPED ==="
      return
    end

    # Find the seller by email
    seller = Seller.find_by(email: seller_email)
    
    if seller.nil?
      Rails.logger.error "SendProductDetailsWhatsAppJob: Seller with email #{seller_email} not found"
      Rails.logger.error "=== PRODUCT DETAILS WHATSAPP JOB FAILED ==="
      return
    end

    Rails.logger.info "Seller found: #{seller.fullname || seller.enterprise_name || 'Unnamed'}"
    Rails.logger.info "Seller Email: #{seller.email}"
    Rails.logger.info "Seller Phone: #{seller.phone_number}"

    begin
      sent_channels = []

      # Send WhatsApp template message
      if seller.phone_number.present?
        Rails.logger.info "Attempting to send WhatsApp template message..."
        
        # Send the product_details template (Swahili language)
        whatsapp_result = WhatsAppCloudService.send_template(
          seller.phone_number,
          'product_details',
          'sw'  # Swahili language code
        )

        if whatsapp_result.is_a?(Hash) && whatsapp_result[:success]
          sent_channels << "whatsapp"
          Rails.logger.info "✅ Successfully sent WhatsApp template to #{seller.phone_number}"
        else
          error_msg = whatsapp_result.is_a?(Hash) ? whatsapp_result[:error] : 'Unknown error'
          Rails.logger.warn "⚠️ Failed to send WhatsApp template to #{seller.phone_number}: #{error_msg}"
        end
      else
        Rails.logger.warn "⚠️ Seller #{seller.id} has no phone number - skipping WhatsApp message"
      end

      # Send in-app message
      send_in_app_product_details_message(seller)

      if sent_channels.any?
        Rails.logger.info "📱 Communication sent via: #{sent_channels.join(', ')} for: #{seller.email}"
        Rails.logger.info "=== PRODUCT DETAILS WHATSAPP JOB COMPLETED ==="
      else
        Rails.logger.warn "No communication channels were successfully used for seller #{seller.id}"
      end

    rescue => e
      Rails.logger.error "SendProductDetailsWhatsAppJob: Failed to send message to seller #{seller_email}: #{e.message}"
      Rails.logger.error "Error Class: #{e.class}"
      Rails.logger.error "Error Backtrace:"
      e.backtrace.first(10).each { |line| Rails.logger.error "  #{line}" }
      Rails.logger.error "=== PRODUCT DETAILS WHATSAPP JOB FAILED ==="
      raise e
    end
  end

  private

  def send_in_app_product_details_message(seller)
    full_name = seller.fullname.presence || seller.enterprise_name.presence || "Muuzaji Mpendwa"
    
    markdown_content = <<~MARKDOWN
      **Maelezo Mazuri ya Bidhaa**

      Habari **#{full_name}**,

      Maelezo mazuri ya bidhaa husaidia wateja kuelewa unachouza. Hakikisha jina la bidhaa, bei, na maelezo vinaeleweka na ni sahihi. Taarifa ikiwa rahisi na kamili, wateja wana uwezekano mkubwa wa kuamini duka lako na kununua kwako.

      Ingia kwenye akaunti yako leo na uhakikishe kuwa bidhaa zako zina maelezo kamili.

      **Viungo vya Haraka:**
      • [Angia Matangisho Yako](https://carboncube-ke.com/seller/ads?utm_source=in_app&utm_medium=messaging&utm_campaign=product_descriptions&utm_content=ads_management)
      • [Dashboard Yako](https://carboncube-ke.com/seller/dashboard?utm_source=in_app&utm_medium=messaging&utm_campaign=product_descriptions&utm_content=main_dashboard)

      Asante kwa kuwa muuzaji wetu.

      Kwa njema,
      **Carbon Cube Kenya**
    MARKDOWN

    # Find system admin for sending messages
    system_admin = Rails.cache.fetch("system_admin_user", expires_in: 1.hour) do
      Admin.find_by(email: 'support@carboncube-ke.com') || 
             Admin.find_by(username: 'admin') || 
             Admin.first
    end

    unless system_admin
      Rails.logger.error "Cannot send in-app message: No Admin user found in database"
      return
    end

    # Create conversation
    conversation = Conversation.find_or_create_by!(
      admin_id: system_admin.id,
      seller_id: seller.id,
      ad_id: nil,
      buyer_id: nil,
      inquirer_seller_id: nil
    )

    # Create the message
    message = conversation.messages.create!(
      content: markdown_content,
      sender: system_admin
    )
    
    # Update unread counts
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
