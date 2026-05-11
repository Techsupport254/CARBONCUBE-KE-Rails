class SendProductDetailsToAllSellersJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "=== PRODUCT DETAILS TO ALL SELLERS JOB START ==="
    
    # Process all sellers with phone numbers
    sellers_to_process = Seller.where.not(phone_number: [nil, ''])
    
    Rails.logger.info "Processing all sellers with phone numbers"
    Rails.logger.info "Found #{sellers_to_process.count} seller(s) to process"
    
    if sellers_to_process.none?
      Rails.logger.warn "No sellers found to process"
      Rails.logger.info "=== PRODUCT DETAILS TO ALL SELLERS JOB COMPLETED ==="
      return
    end
    
    success_count = 0
    failure_count = 0
    
    sellers_to_process.find_each do |seller|
      begin
        Rails.logger.info "Processing seller: #{seller.fullname || seller.enterprise_name || 'Unnamed'} (#{seller.email})"
        
        # Send WhatsApp template message
        if seller.phone_number.present?
          Rails.logger.info "Sending WhatsApp template to #{seller.phone_number}..."
          
          whatsapp_result = WhatsAppCloudService.send_template(
            seller.phone_number,
            'product_details',
            'sw'  # Swahili language code
          )

          if whatsapp_result.is_a?(Hash) && whatsapp_result[:success]
            Rails.logger.info "✅ WhatsApp template sent to #{seller.phone_number}"
            success_count += 1
          else
            error_msg = whatsapp_result.is_a?(Hash) ? whatsapp_result[:error] : 'Unknown error'
            Rails.logger.warn "⚠️ Failed to send WhatsApp template to #{seller.phone_number}: #{error_msg}"
            failure_count += 1
          end
        else
          Rails.logger.warn "⚠️ Seller #{seller.id} has no phone number - skipping WhatsApp"
          failure_count += 1
        end
        
        # Send in-app message
        send_in_app_product_details_message(seller)
        
        # Small delay to avoid rate limiting
        sleep(0.5)
        
      rescue => e
        Rails.logger.error "Failed to process seller #{seller.email}: #{e.message}"
        failure_count += 1
      end
    end
    
    Rails.logger.info "=== PRODUCT DETAILS TO ALL SELLERS JOB SUMMARY ==="
    Rails.logger.info "Total Sellers Processed: #{sellers_to_process.count}"
    Rails.logger.info "✅ Successful: #{success_count}"
    Rails.logger.info "❌ Failed: #{failure_count}"
    Rails.logger.info "=== PRODUCT DETAILS TO ALL SELLERS JOB COMPLETED ==="
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
