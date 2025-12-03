class SellerCommunicationsMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"
  
  # Skip ApplicationMailer's before_action for black_friday_email to have full control
  skip_before_action :add_deliverability_headers, only: [:black_friday_email]
  
  # Use our custom job for better logging
  def self.delivery_job
    SellerCommunicationMailDeliveryJob
  end
  
  def custom_communication
    @user = params[:user] || params[:seller] || @seller
    @user_type = params[:user_type] || 'seller'
    @custom_subject = params[:subject]
    @custom_message = params[:message]

    # Log to both Rails logger and stdout for Sidekiq visibility
    log_message = "=== CUSTOM #{@user_type.upcase} COMMUNICATION EMAIL START ==="
    Rails.logger.info log_message

    user_name = if @user_type == 'seller'
      @user.fullname.presence || @user.enterprise_name.presence || 'Seller'
    else
      @user.fullname.presence || @user.username.presence || 'Buyer'
    end

    log_message = "#{@user_type.capitalize} ID: #{@user.id} | Name: #{user_name} | Email: #{@user.email}"
    Rails.logger.info log_message

    log_message = "Custom Subject: #{@custom_subject}"
    Rails.logger.info log_message

    # Generate unique subject with timestamp to prevent threading
    timestamp = Time.current.strftime('%Y%m%d%H%M')
    unique_subject = "#{@custom_subject} - #{timestamp}"

    mail(
      to: @user.email,
      subject: unique_subject
    ) do |format|
      Rails.logger.info "Generating custom email content..."
      format.html { render 'custom_communication' }
    end

    # AGGRESSIVE threading prevention
    mail['In-Reply-To'] = nil
    mail['References'] = nil
    mail['Thread-Topic'] = nil
    mail['Thread-Index'] = nil

    # Force new conversation
    mail['X-Threading'] = 'false'
    mail['X-Conversation-ID'] = SecureRandom.uuid

    log_message = "Custom email object created successfully | To: #{mail.to.join(', ')} | From: #{mail.from.join(', ')}"
    Rails.logger.info log_message

    log_message = "About to deliver custom email to: #{@user.email}"
    Rails.logger.info log_message

    log_message = "=== CUSTOM #{@user_type.upcase} COMMUNICATION EMAIL END ==="
    Rails.logger.info log_message

    mail
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
    
    # Get top 4 best performing products for this seller
    @top_products = @seller.ads
                           .where(deleted: false)
                           .where.not(media: [nil, [], ""])
                           .includes(:category)
                           .order('reviews_count DESC, created_at DESC')
                           .limit(4)
    
    # Log to both Rails logger and stdout for Sidekiq visibility
    log_message = "=== PLATFORM NOTIFICATION EMAIL START ==="
    Rails.logger.info log_message
    
    log_message = "Seller ID: #{@seller.id} | Name: #{@seller.fullname} | Email: #{@seller.email}"
    Rails.logger.info log_message
    
    log_message = "Recipient Email: #{@seller.email} | Enterprise: #{@seller.enterprise_name}"
    Rails.logger.info log_message
    
    Rails.logger.info "SMTP Settings: #{ActionMailer::Base.smtp_settings}"
    Rails.logger.info "Delivery Method: #{ActionMailer::Base.delivery_method}"
    Rails.logger.info "From Address: #{default_params[:from]}"
    
    # Transactional subject - Platform notification format with unique timestamp to prevent threading
    # NO promotional words, NO emoji - Gmail treats these as transactional
    timestamp = Time.current.strftime('%Y%m%d%H%M%S')
    subject_text = "Platform Notification #{timestamp} - High Traffic Period Expected"
    
    # Generate unique Message-ID
    timestamp_msg = Time.current.to_i
    random_id = SecureRandom.hex(8)
    headers['Message-ID'] = "<#{timestamp_msg}-#{random_id}@carboncube-ke.com>"
    
    # CRITICAL: Set headers BEFORE mail() to tell Gmail this is TRANSACTIONAL/NOTIFICATION
    # These headers force Gmail to show in Primary tab
    headers['X-Priority'] = '1'  # Highest priority
    headers['Importance'] = 'High'  # High importance
    headers['X-MSMail-Priority'] = 'High'
    headers['X-Message-Flag'] = 'Important'
    
    # Explicitly mark as transactional/notification (NOT promotional)
    headers['Precedence'] = nil  # No bulk precedence
    headers['List-Unsubscribe'] = nil  # No list headers - critical for avoiding promotional
    headers['List-Unsubscribe-Post'] = nil
    headers['List-Id'] = nil
    headers['List-Post'] = nil
    headers['Auto-Submitted'] = nil  # Not auto-generated
    headers['X-Auto-Response-Suppress'] = 'All'
    
    # Clear threading headers
    headers['In-Reply-To'] = nil
    headers['References'] = nil
    
    # Generate HTML content for attachment (BEFORE mail() is called)
    html_content = render_to_string(
      template: 'seller_communications_mailer/black_friday_email',
      layout: false,
      formats: [:html]
    )
    
    # Attach HTML preview file BEFORE creating mail message
    attachment_filename = "platform_notification_#{Time.current.strftime('%Y%m%d')}.html"
    attachments[attachment_filename] = {
      mime_type: 'text/html',
      content: html_content
    }
    Rails.logger.info "HTML preview attached: #{attachment_filename}"
    
    # Create mail message (attachments must be added before this)
    mail_message = mail(
      to: @seller.email,
      subject: subject_text
    ) do |format|
      Rails.logger.info "Generating email content..."
      format.html { render 'black_friday_email' }
    end
    
    # CRITICAL: Force transactional headers and remove ALL promotional markers
    mail_message['X-Priority'] = '1'
    mail_message['Importance'] = 'High'
    mail_message['X-MSMail-Priority'] = 'High'
    mail_message['X-Message-Flag'] = 'Important'
    
    # Remove ALL bulk/promotional markers - this is critical for Gmail categorization
    mail_message['Precedence'] = nil
    mail_message['List-Unsubscribe'] = nil
    mail_message['List-Unsubscribe-Post'] = nil
    mail_message['List-Id'] = nil
    mail_message['List-Post'] = nil
    mail_message['Auto-Submitted'] = nil
    
    # Clear threading
    mail_message['In-Reply-To'] = nil
    mail_message['References'] = nil
    
    # NO Reply-To (makes it appear as new message, not a reply)
    mail_message['Reply-To'] = nil
    
    log_message = "=== PLATFORM NOTIFICATION EMAIL END ==="
    Rails.logger.info log_message
    
    mail_message
  end
end
