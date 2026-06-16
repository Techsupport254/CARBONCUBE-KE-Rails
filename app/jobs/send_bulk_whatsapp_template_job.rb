class SendBulkWhatsappTemplateJob < ApplicationJob
  queue_as :default

  def perform(template_name, language_code = 'en', components = [])
    # Find all active sellers
    active_sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
    
    total_sellers = active_sellers.count
    Rails.logger.info "[SendBulkWhatsappTemplateJob] Found #{total_sellers} active sellers to send WhatsApp template: #{template_name}"
    
    return if total_sellers == 0

    sent_count = 0
    
    active_sellers.find_in_batches(batch_size: 100) do |seller_batch|
      seller_batch.each do |seller|
        # Queue individual template sending job
        SendWhatsappTemplateJob.perform_later(seller.id, template_name, language_code, components, 'seller')
        sent_count += 1
      end
      
      # Small delay to prevent overwhelming Sidekiq/Redis immediately
      sleep(1)
    end
    
    Rails.logger.info "[SendBulkWhatsappTemplateJob] Queued #{sent_count} jobs for template: #{template_name}"
  end
end
