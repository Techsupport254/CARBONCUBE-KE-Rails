class SellerCommunicationsMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"
  
  # Use our custom job for better logging
  def self.delivery_job
    SellerCommunicationMailDeliveryJob
  end

  def general_update
    @seller = params[:seller] || @seller
    
    # Log to both Rails logger and stdout for Sidekiq visibility
    log_message = "=== SELLER COMMUNICATION EMAIL START ==="
    Rails.logger.info log_message
    
    log_message = "Seller ID: #{@seller.id} | Name: #{@seller.fullname} | Email: #{@seller.email}"
    Rails.logger.info log_message
    
    log_message = "Recipient Email: #{@seller.email} | Enterprise: #{@seller.enterprise_name}"
    Rails.logger.info log_message
    
    Rails.logger.info "SMTP Settings: #{ActionMailer::Base.smtp_settings}"
    Rails.logger.info "Delivery Method: #{ActionMailer::Base.delivery_method}"
    Rails.logger.info "From Address: #{default_params[:from]}"
    
    # Generate unique subject with timestamp to prevent threading
    timestamp = Time.current.strftime('%Y%m%d%H%M')
    unique_subject = "Platform Update #{timestamp} - Let's Grow Together!"
    
    mail(
      to: @seller.email,
      subject: unique_subject
    ) do |format|
      Rails.logger.info "Generating email content..."
      format.html { render 'general_update' }
    end
    
    # AGGRESSIVE threading prevention
    mail['In-Reply-To'] = nil
    mail['References'] = nil
    mail['Thread-Topic'] = nil
    mail['Thread-Index'] = nil
    
    # Force new conversation
    mail['X-Threading'] = 'false'
    mail['X-Conversation-ID'] = SecureRandom.uuid
    
    log_message = "Email object created successfully | To: #{mail.to.join(', ')} | From: #{mail.from.join(', ')}"
    Rails.logger.info log_message
    
    log_message = "About to deliver email to: #{@seller.email}"
    Rails.logger.info log_message
    
    log_message = "=== SELLER COMMUNICATION EMAIL END ==="
    Rails.logger.info log_message
    
    mail
  end

  def black_friday_email
    @seller = params[:seller] || @seller
    
    # Get top 3 best performing products for this seller
    @top_products = @seller.ads
                           .where(deleted: false)
                           .where.not(media: [nil, [], ""])
                           .includes(:category)
                           .order('reviews_count DESC, created_at DESC')
                           .limit(3)
    
    # Log to both Rails logger and stdout for Sidekiq visibility
    log_message = "=== BLACK FRIDAY EMAIL START ==="
    Rails.logger.info log_message
    
    log_message = "Seller ID: #{@seller.id} | Name: #{@seller.fullname} | Email: #{@seller.email}"
    Rails.logger.info log_message
    
    log_message = "Recipient Email: #{@seller.email} | Enterprise: #{@seller.enterprise_name}"
    Rails.logger.info log_message
    
    Rails.logger.info "SMTP Settings: #{ActionMailer::Base.smtp_settings}"
    Rails.logger.info "Delivery Method: #{ActionMailer::Base.delivery_method}"
    Rails.logger.info "From Address: #{default_params[:from]}"
    
    # Generate unique subject with timestamp to prevent threading
    timestamp = Time.current.strftime('%Y%m%d%H%M')
    unique_subject = "🎉 Black Friday Sale #{timestamp} - Maximize Your Revenue!"
    
    mail(
      to: @seller.email,
      subject: unique_subject
    ) do |format|
      Rails.logger.info "Generating email content..."
      format.html { render 'black_friday_email' }
    end
    
    # AGGRESSIVE threading prevention
    mail['In-Reply-To'] = nil
    mail['References'] = nil
    mail['Thread-Topic'] = nil
    mail['Thread-Index'] = nil
    
    # Force new conversation
    mail['X-Threading'] = 'false'
    mail['X-Conversation-ID'] = SecureRandom.uuid
    
    log_message = "Email object created successfully | To: #{mail.to.join(', ')} | From: #{mail.from.join(', ')}"
    Rails.logger.info log_message
    
    log_message = "About to deliver email to: #{@seller.email}"
    Rails.logger.info log_message
    
    log_message = "=== BLACK FRIDAY EMAIL END ==="
    Rails.logger.info log_message
    
    mail
  end
end
