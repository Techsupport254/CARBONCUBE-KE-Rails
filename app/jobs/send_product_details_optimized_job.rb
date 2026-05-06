class SendProductDetailsOptimizedJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "=== PRODUCT DETAILS OPTIMIZED JOB START ==="
    
    # Get all sellers with phone numbers
    all_sellers = Seller.where.not(phone_number: [nil, ''])
    template_name = 'product_details'
    
    # Exclude sellers who already received this template
    processed_seller_ids = WhatsappMessageLog.for_template(template_name).sent_successfully.pluck(:seller_id)
    sellers_to_process = all_sellers.where.not(id: processed_seller_ids)
    
    Rails.logger.info "Total sellers with phones: #{all_sellers.count}"
    Rails.logger.info "Already sent: #{processed_seller_ids.size}"
    Rails.logger.info "Remaining to send: #{sellers_to_process.count}"
    
    if sellers_to_process.none?
      Rails.logger.info "All sellers have already received the product_details template"
      Rails.logger.info "=== PRODUCT DETAILS OPTIMIZED JOB COMPLETED ==="
      return
    end
    
    success_count = 0
    failure_count = 0
    
    sellers_to_process.find_each do |seller|
      begin
        Rails.logger.info "Processing seller: #{seller.fullname || seller.enterprise_name || 'Unnamed'} (#{seller.email})"
        
        # Check if already sent (double-check)
        if WhatsappMessageLog.already_sent?(seller, template_name)
          Rails.logger.info "Seller already received template - skipping"
          next
        end
        
        # Send WhatsApp template message
        if seller.phone_number.present?
          Rails.logger.info "Sending WhatsApp template to #{seller.phone_number}..."
          
          whatsapp_result = WhatsAppCloudService.send_template(
            seller.phone_number,
            template_name,
            'sw'  # Swahili language code
          )

          if whatsapp_result.is_a?(Hash) && whatsapp_result[:success]
            # Log successful send
            WhatsappMessageLog.mark_as_sent(
              seller, 
              template_name, 
              seller.phone_number, 
              whatsapp_result[:message_id]
            )
            
            Rails.logger.info "✅ WhatsApp template sent to #{seller.phone_number}"
            success_count += 1
          else
            error_msg = whatsapp_result.is_a?(Hash) ? whatsapp_result[:error] : 'Unknown error'
            Rails.logger.warn "⚠️ Failed to send WhatsApp template to #{seller.phone_number}: #{error_msg}"
            
            # Log failed attempt
            WhatsappMessageLog.create(
              seller: seller,
              phone_number: seller.phone_number,
              template_name: template_name,
              sent_successfully: false,
              error_message: error_msg
            )
            
            failure_count += 1
          end
        else
          Rails.logger.warn "⚠️ Seller #{seller.id} has no phone number - skipping WhatsApp"
          failure_count += 1
        end
        
        # Reduced delay for faster processing (0.1 seconds = 600 messages/minute)
        sleep(0.1)
        
      rescue => e
        Rails.logger.error "Failed to process seller #{seller.email}: #{e.message}"
        failure_count += 1
        
        # Log error
        WhatsappMessageLog.create(
          seller: seller,
          phone_number: seller.phone_number,
          template_name: template_name,
          sent_successfully: false,
          error_message: e.message
        )
      end
    end
    
    Rails.logger.info "=== PRODUCT DETAILS OPTIMIZED JOB SUMMARY ==="
    Rails.logger.info "Total Sellers Processed: #{sellers_to_process.count}"
    Rails.logger.info "✅ Successful: #{success_count}"
    Rails.logger.info "❌ Failed: #{failure_count}"
    Rails.logger.info "Rate: ~600 messages per minute (0.1s delay)"
    Rails.logger.info "=== PRODUCT DETAILS OPTIMIZED JOB COMPLETED ==="
  end
end
