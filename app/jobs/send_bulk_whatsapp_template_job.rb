class SendBulkWhatsappTemplateJob < ApplicationJob
  queue_as :broadcast

  retry_on StandardError, wait: :polynomially_longer, attempts: 2
  discard_on ActiveJob::DeserializationError

  def perform(template_name, language_code = 'en', components = [])
    active_sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
    
    total_sellers = active_sellers.count
    
    return if total_sellers == 0

    sent_count = 0
    
    active_sellers.find_in_batches(batch_size: 100) do |seller_batch|
      seller_batch.each do |seller|
        SendWhatsappTemplateJob.perform_later(seller.id, template_name, language_code, components, 'seller')
        sent_count += 1
      end
      
      sleep(1)
    end
    
    Rails.logger.info "[SendBulkWhatsappTemplateJob] Queued #{sent_count} jobs for template: #{template_name}"
  end
end
