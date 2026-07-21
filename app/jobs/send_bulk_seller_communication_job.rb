class SendBulkSellerCommunicationJob < ApplicationJob
  queue_as :broadcast

  retry_on StandardError, wait: 30.seconds, attempts: 2

  def perform(email_type = 'general_update', auto_confirm = false, channels = { email: true, whatsapp: false }, custom_subject = nil, custom_message = nil)
    active_sellers = Seller.where(
      deleted: [false, nil],
      blocked: [false, nil]
    )
    
    total_sellers = active_sellers.count
    
    if total_sellers == 0
      Rails.logger.info "No active sellers found. Job completed."
      return
    end

    unless auto_confirm
      Rails.logger.warn "[SendBulkSellerCommunicationJob] auto_confirm is false in a background job context. Proceeding without interactive confirmation."
    end
    
    sent_count = 0
    failed_count = 0
    failed_sellers = []
    
    active_sellers.find_in_batches(batch_size: 50) do |seller_batch|
      seller_batch.each do |seller|
        begin
          SendSellerCommunicationJob.perform_later(seller.id, email_type, channels, custom_subject, custom_message)
          sent_count += 1
        rescue => e
          failed_count += 1
          failed_sellers << {
            id: seller.id,
            email: seller.email,
            error: e.message
          }
          Rails.logger.error "Failed to queue email for seller #{seller.id}: #{e.message}"
        end
      end
      
      sleep(1) if seller_batch.size == 50
    end
    
    Rails.logger.info "Bulk job complete. Queued: #{sent_count}, Failed: #{failed_count}"
    
    {
      status: 'completed',
      total_sellers: total_sellers,
      queued_emails: sent_count,
      failed_emails: failed_count,
      failed_sellers: failed_sellers
    }
  end
end
