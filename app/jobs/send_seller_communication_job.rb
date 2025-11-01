class SendSellerCommunicationJob < ApplicationJob
  queue_as :default

  def perform(seller_id, email_type = 'general_update')
    # Log to both Rails logger and Sidekiq logger for visibility
    log_message = "=== SELLER COMMUNICATION JOB START ==="
    Rails.logger.info log_message
    
    log_message = "Job ID: #{job_id} | Seller ID: #{seller_id} | Email Type: #{email_type}"
    Rails.logger.info log_message
    
    log_message = "Job Queue: #{queue_name} | Priority: #{priority}"
    Rails.logger.info log_message
    
    seller = Seller.find_by(id: seller_id)
    
    if seller.nil?
      Rails.logger.error "SendSellerCommunicationJob: Seller with ID #{seller_id} not found"
      Rails.logger.error "=== SELLER COMMUNICATION JOB FAILED ==="
      return
    end
    
    log_message = "Seller found: #{seller.fullname} | Email: #{seller.email}"
    Rails.logger.info log_message
    
    log_message = "Target Email Address: #{seller.email}"
    Rails.logger.info log_message
    
    Rails.logger.info "Seller Enterprise: #{seller.enterprise_name}"
    Rails.logger.info "Seller Location: #{seller.location}"
    Rails.logger.info "Seller Analytics - Ads: #{seller.ads.count}, Reviews: #{seller.reviews.count}"
    
    begin
      Rails.logger.info "Attempting to send #{email_type} email..."
      
      case email_type
      when 'general_update'
        mail = SellerCommunicationsMailer.with(seller: seller).general_update
        Rails.logger.info "Mailer called successfully"
        Rails.logger.info "About to deliver email..."
        mail.deliver_now
        Rails.logger.info "Email delivered successfully!"
      when 'black_friday'
        mail = SellerCommunicationsMailer.with(seller: seller).black_friday_email
        Rails.logger.info "Mailer called successfully"
        Rails.logger.info "About to deliver email..."
        mail.deliver_now
        Rails.logger.info "Email delivered successfully!"
      else
        Rails.logger.error "SendSellerCommunicationJob: Unknown email type '#{email_type}'"
        Rails.logger.error "=== SELLER COMMUNICATION JOB FAILED ==="
        return
      end
      
      log_message = "✅ Successfully sent #{email_type} email to #{seller.email}"
      Rails.logger.info log_message
      
      log_message = "📧 Email delivery completed for: #{seller.email}"
      Rails.logger.info log_message
      
      log_message = "=== SELLER COMMUNICATION JOB COMPLETED ==="
      Rails.logger.info log_message
      
    rescue => e
      Rails.logger.error "SendSellerCommunicationJob: Failed to send email to seller #{seller_id}: #{e.message}"
      Rails.logger.error "Error Class: #{e.class}"
      Rails.logger.error "Error Backtrace:"
      e.backtrace.first(10).each { |line| Rails.logger.error "  #{line}" }
      Rails.logger.error "=== SELLER COMMUNICATION JOB FAILED ==="
      raise e
    end
  end
end
