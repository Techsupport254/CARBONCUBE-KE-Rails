class SellerCommunicationsMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  # Skip ApplicationMailer's before_action for black_friday_email to have full control
  skip_before_action :add_deliverability_headers, only: [:black_friday_email]

  # Markdown processor for email templates
  def self.markdown_processor
    require 'redcarpet'
    renderer = Redcarpet::Render::HTML.new({
      filter_html: true,
      no_images: true,
      no_styles: false,
      safe_links_only: true,
      with_toc_data: false,
      hard_wrap: true,
      xhtml: false,
      link_attributes: { target: '_blank' }
    })

    Redcarpet::Markdown.new(renderer, {
      autolink: true,
      tables: false,
      fenced_code_blocks: false,
      disable_indented_code_blocks: true,
      strikethrough: true,
      superscript: false,
      underline: false,
      highlight: false,
      quote: true,
      footnotes: false,
      lax_spacing: true
    })
  end

  def self.process_markdown(message)
    markdown = markdown_processor
    html_content = markdown.render(message.to_s)

    # Apply email-safe inline styles
    html_content
      .gsub('<p>', '<p style="margin: 12px 0; font-size: 14px; line-height: 1.7; color: #374151; font-family: \'Inter\', sans-serif;">')
      .gsub('<strong>', '<strong style="font-weight: 600; color: #111827; font-family: \'Inter\', sans-serif;">')
      .gsub('<em>', '<em style="font-style: italic; color: #374151; font-family: \'Inter\', sans-serif;">')
      .gsub('<h1>', '<h1 style="font-size: 20px; font-weight: 600; color: #111827; margin: 20px 0 10px 0; font-family: \'Inter\', sans-serif;">')
      .gsub('<h2>', '<h2 style="font-size: 18px; font-weight: 600; color: #111827; margin: 18px 0 8px 0; font-family: \'Inter\', sans-serif;">')
      .gsub('<h3>', '<h3 style="font-size: 16px; font-weight: 600; color: #111827; margin: 16px 0 8px 0; font-family: \'Inter\', sans-serif;">')
      .gsub('<blockquote>', '<blockquote style="border-left: 4px solid #e5e7eb; padding: 8px 0 8px 16px; margin: 12px 0; font-style: italic; color: #6b7280; background: #f9fafb; border-radius: 0 4px 4px 0; font-family: \'Inter\', sans-serif;">')
      .gsub('<code>', '<code style="background: #f3f4f6; padding: 2px 6px; border-radius: 4px; font-family: \'JetBrains Mono\', \'Fira Code\', \'Courier New\', monospace; font-size: 13px; color: #d73a49; border: 1px solid #e1e4e8;">')
      .gsub('<ul>', '<ul style="margin: 12px 0; padding-left: 20px;">')
      .gsub('<ol>', '<ol style="margin: 12px 0; padding-left: 20px;">')
      .gsub('<li>', '<li style="margin: 6px 0; font-size: 14px; line-height: 1.7; color: #374151; font-family: \'Inter\', sans-serif;">')
      .gsub(/<[^>]+><\/[^>]+>/, '') # Remove empty tags
  end
  
  # Use our custom job for better logging
  def self.delivery_job
    SellerCommunicationMailDeliveryJob
  end
  
  def custom_communication
    @user = params[:user] || params[:seller] || @seller
    @user_type = params[:user_type] || 'seller'
    @custom_subject = params[:subject]
    @custom_message = params[:message]
    @attachments = params[:attachments] || []

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

    # Add attachments if provided
    if @attachments.present? && @attachments.is_a?(Array)
      @attachments.each do |attachment|
        next unless attachment.respond_to?(:original_filename) && attachment.respond_to?(:read)

        # Get file content and metadata
        file_content = attachment.read
        filename = attachment.original_filename

        # Add attachment to mail
        attachments[filename] = {
          mime_type: attachment.content_type,
          content: file_content
        }

        log_message = "Attachment added: #{filename} (#{attachment.content_type}, #{file_content.bytesize} bytes)"
        Rails.logger.info log_message
      end
    end

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
