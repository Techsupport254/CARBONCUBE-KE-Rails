class SendShareShopFeatureOptimizedJob < ApplicationJob
  queue_as :default

  def perform(test_mode = true)
    all_sellers = test_mode ? Seller.where(email: 'optisoftkenya@gmail.com') : Seller.where(deleted: [false, nil], blocked: [false, nil])
    email_type = 'share_shop_feature'
    
    processed_seller_ids = EmailCommunicationLog.for_type(email_type).pluck(:seller_id)
    sellers_to_process = all_sellers.where.not(id: processed_seller_ids)
    
    if sellers_to_process.none?
      Rails.logger.info "All sellers have already received the #{email_type} communication"
      return
    end
    
    success_count = 0
    failure_count = 0
    
    sellers_to_process.find_each(batch_size: 50) do |seller|
      begin
        if EmailCommunicationLog.already_sent?(seller, email_type)
          next
        end
        
        SendSellerCommunicationJob.perform_now(
          seller.id, 
          email_type, 
          { email: true, whatsapp: false }
        )
        
        EmailCommunicationLog.mark_as_sent(seller, email_type)
        success_count += 1
        
        sleep(0.5)
        
      rescue => e
        Rails.logger.error "Failed to process seller #{seller.email}: #{e.message}"
        failure_count += 1
        
        EmailCommunicationLog.create(
          seller: seller,
          email_type: email_type,
          sent_successfully: false,
          error_message: e.message
        )
      end
    end
    
    Rails.logger.info "Share Shop feature job complete. Success: #{success_count}, Failed: #{failure_count}"
  end
end
