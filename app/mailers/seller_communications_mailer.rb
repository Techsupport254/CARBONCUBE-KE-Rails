class SellerCommunicationsMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"
  
  # Skip global headers for full control over Primary inboxing
  skip_before_action :add_deliverability_headers, only: [:seller_growth_initiative]
  
  helper UtmUrlHelper
  
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
  def seller_growth_initiative
    @seller = params[:seller]
    @fullname = @seller.fullname
    @enterprise_name = @seller.enterprise_name
    @gender = @seller.gender # Standard gender check
    
    # Personal greeting name (First name)
    @first_name = @fullname.to_s.split(' ').first.presence || "Legend"
    
    # Profile Picture Logic
    raw_pic = @seller.profile_picture
    if raw_pic.present? && !raw_pic.to_s.start_with?('/cached_profile_pictures/')
      @profile_picture = raw_pic
    else
      @profile_picture = "https://ui-avatars.com/api/?name=#{URI.encode_www_form_component(@name)}&background=1f2937&color=ffffff&size=128&bold=true&format=png"
    end

    # Ads Count
    @ads_count = @seller.ads.where(deleted: false).count

    # Total Clicks
    @total_clicks = ClickEvent.where(ad_id: @seller.ads.select(:id), event_type: 'Ad-Click').count

    # Identify Top Performing Ad
    top_ad_data = ClickEvent.where(ad_id: @seller.ads.select(:id), event_type: 'Ad-Click')
                            .group(:ad_id)
                            .order('count_all DESC')
                            .count
                            .first
    
    if top_ad_data
      @top_ad = Ad.find_by(id: top_ad_data[0])
      @top_ad_clicks = top_ad_data[1]
    elsif @seller.ads.exists?
       @top_ad = @seller.ads.where(deleted: false).order(created_at: :desc).first
       @top_ad_clicks = 0
    end

    # Days since last ad
    last_ad = @seller.ads.where(deleted: false).order(created_at: :desc).first
    @days_since_last_ad = last_ad ? ((Time.current - last_ad.created_at) / 1.day).to_i : 999
    
    # Tier Name
    @tier_name = @seller.seller_tier&.tier&.name || "Free"
    
    # Timestamp for footer
    @timestamp = Time.current.in_time_zone("Nairobi").strftime("%B %d, %Y")

    # High-engagement subject line
    subject_text = "You have a new message"

    # Append subtle unique ID
    subject_text += " [Ref: #{Time.current.to_i.to_s[-4..-1]}]"

    @upload_url = "https://carboncube-ke.com/seller/ads/new"

    # Minimal headers to mimic manual email
    headers['X-Priority'] = '1'
    headers['X-MSMail-Priority'] = 'High'
    headers['Importance'] = 'High'
    headers['Precedence'] = nil
    headers['List-Unsubscribe'] = nil
    headers['List-Unsubscribe-Post'] = nil
    headers['Message-ID'] = "<#{Time.current.to_f}-#{@seller.id}@carboncube-ke.com>"

    mail(
      to: @seller.email,
      from: "Victor from Carbon Cube <#{ENV['BREVO_EMAIL']}>",
      subject: subject_text
    )
  end
end
