class SendShareShopFeatureOptimizedJob < ApplicationJob
  queue_as :default

  def perform(test_mode = true)
    Rails.logger.info "=== SHARE SHOP FEATURE OPTIMIZED JOB START ==="
    Rails.logger.info "Test Mode: #{test_mode}"
    
    # Get all active sellers
    all_sellers = test_mode ? Seller.where(email: 'optisoftkenya@gmail.com') : Seller.where(deleted: [false, nil], blocked: [false, nil])
    email_type = 'share_shop_feature'
    
    # Exclude sellers who already have a log entry (sent or failed)
    processed_seller_ids = EmailCommunicationLog.for_type(email_type).pluck(:seller_id)
    sellers_to_process = all_sellers.where.not(id: processed_seller_ids)
    
    Rails.logger.info "Total active sellers: #{all_sellers.count}"
    Rails.logger.info "Already sent: #{processed_seller_ids.size}"
    Rails.logger.info "Remaining to send: #{sellers_to_process.count}"
    
    if sellers_to_process.none?
      Rails.logger.info "All sellers have already received the #{email_type} communication"
      Rails.logger.info "=== SHARE SHOP FEATURE OPTIMIZED JOB COMPLETED ==="
      return
    end
    
    success_count = 0
    failure_count = 0
    
    # Process sellers in batches to avoid memory issues and handle rate limiting
    sellers_to_process.find_each(batch_size: 50) do |seller|
      begin
        Rails.logger.info "Processing seller: #{seller.fullname || seller.enterprise_name || 'Unnamed'} (#{seller.email})"
        
        # Double-check if already sent (useful if multiple jobs run or for race conditions)
        if EmailCommunicationLog.already_sent?(seller, email_type)
          Rails.logger.info "Seller already received communication - skipping"
          next
        end
        
        # Trigger the communication (Email + In-App)
        # Note: We use perform_now here because we want to track the result in this loop
        # and we are already in a background job.
        SendSellerCommunicationJob.perform_now(
          seller.id, 
          email_type, 
          { email: true, whatsapp: false }
        )
        
        # Log successful send
        EmailCommunicationLog.mark_as_sent(seller, email_type)
        
        Rails.logger.info "✅ Share Shop feature communication sent to #{seller.email}"
        success_count += 1
        
        # Small delay to respect SMTP rate limits and avoid overwhelming the server
        # 0.5 seconds = 120 emails/minute
        sleep(0.5)
        
      rescue => e
        Rails.logger.error "Failed to process seller #{seller.email}: #{e.message}"
        failure_count += 1
        
        # Log failed attempt
        EmailCommunicationLog.create(
          seller: seller,
          email_type: email_type,
          sent_successfully: false,
          error_message: e.message
        )
      end
    end
    
    Rails.logger.info "=== SHARE SHOP FEATURE OPTIMIZED JOB SUMMARY ==="
    Rails.logger.info "Total Sellers Processed: #{sellers_to_process.count}"
    Rails.logger.info "✅ Successful: #{success_count}"
    Rails.logger.info "❌ Failed: #{failure_count}"
    Rails.logger.info "=== SHARE SHOP FEATURE OPTIMIZED JOB COMPLETED ==="
  end
end
