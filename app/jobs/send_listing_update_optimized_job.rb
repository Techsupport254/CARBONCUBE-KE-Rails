class SendListingUpdateOptimizedJob < ApplicationJob
  queue_as :default

  def perform
    all_sellers = Seller.where(deleted: [false, nil], blocked: [false, nil]).where.not(phone_number: [nil, ''])
    template_name = 'seller_listing_update'
    language_code = 'en'
    
    processed_seller_ids = WhatsappMessageLog.for_template(template_name).sent_successfully.pluck(:seller_id)
    sellers_to_process = all_sellers.where.not(id: processed_seller_ids)
    
    if sellers_to_process.none?
      Rails.logger.info "All active sellers have already received the #{template_name} template"
      return
    end
    
    success_count = 0
    failure_count = 0
    
    sellers_to_process.find_each do |seller|
      begin
        if WhatsappMessageLog.already_sent?(seller, template_name)
          next
        end
        
        if seller.phone_number.present?
          whatsapp_result = WhatsAppCloudService.send_template(
            seller.phone_number,
            template_name,
            language_code
          )

          if whatsapp_result.is_a?(Hash) && whatsapp_result[:success]
            WhatsappMessageLog.mark_as_sent(
              seller, 
              template_name, 
              seller.phone_number, 
              whatsapp_result[:message_id]
            )
            success_count += 1
          else
            error_msg = whatsapp_result.is_a?(Hash) ? whatsapp_result[:error] : 'Unknown error'
            Rails.logger.warn "Failed to send WhatsApp template to #{seller.phone_number}: #{error_msg}"
            
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
          Rails.logger.warn "Seller #{seller.id} has no phone number - skipping WhatsApp"
          failure_count += 1
        end
        
        sleep(0.1)
        
      rescue => e
        Rails.logger.error "Failed to process seller #{seller.email}: #{e.message}"
        failure_count += 1
        
        WhatsappMessageLog.create(
          seller: seller,
          phone_number: seller.phone_number,
          template_name: template_name,
          sent_successfully: false,
          error_message: e.message
        )
      end
    end
    
    Rails.logger.info "Listing update job complete. Success: #{success_count}, Failed: #{failure_count}"
  end
end
