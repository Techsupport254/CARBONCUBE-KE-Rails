class SendSellerCommunicationJob < ApplicationJob
  queue_as :default

  def perform(user_id, email_type = 'general_update', channels = { email: true, whatsapp: false }, custom_subject = nil, custom_message = nil, user_type = 'seller')
    # BLOCK BLACK FRIDAY EMAILS - Prevent sending to avoid spam
    if email_type == 'black_friday'
      Rails.logger.warn "=== BLACK FRIDAY EMAIL BLOCKED ==="
      Rails.logger.warn "SendSellerCommunicationJob: Black Friday emails are disabled. Email to seller #{seller_id} was blocked."
      Rails.logger.warn "=== JOB CANCELLED ==="
      return
    end
    
    # Log to both Rails logger and Sidekiq logger for visibility
    log_message = "=== SELLER COMMUNICATION JOB START ==="
    Rails.logger.info log_message
    
    log_message = "Job ID: #{job_id} | User ID: #{user_id} | User Type: #{user_type} | Email Type: #{email_type} | Channels: #{channels.inspect}"
    Rails.logger.info log_message

    log_message = "Job Queue: #{queue_name} | Priority: #{priority}"
    Rails.logger.info log_message

    # Determine model class based on user type
    model_class = case user_type
    when 'buyer'
      Buyer
    when 'sellers', 'seller'
      Seller
    else
      Seller # Default to Seller
    end

    user = model_class.find_by(id: user_id)

    if user.nil?
      Rails.logger.error "SendSellerCommunicationJob: #{user_type.capitalize} with ID #{user_id} not found"
      Rails.logger.error "=== #{user_type.upcase} COMMUNICATION JOB FAILED ==="
      return
    end

    log_message = "#{user_type.capitalize} found: #{user.fullname || user.username || 'Unnamed'} | Email: #{user.email}"
    Rails.logger.info log_message

    log_message = "Target Email Address: #{user.email}"
    Rails.logger.info log_message

    if user_type == 'seller'
      Rails.logger.info "Seller Enterprise: #{user.enterprise_name}"
      Rails.logger.info "Seller Location: #{user.location}"
      Rails.logger.info "Seller Analytics - Ads: #{user.ads.count}, Reviews: #{user.reviews.count}"
    else
      Rails.logger.info "Buyer Profile: #{user.username}"
    end
    
    begin
      sent_channels = []

      # Send email if requested
      if channels[:email] || channels['email']
        Rails.logger.info "Attempting to send #{email_type} email..."

        case email_type
        when 'general_update'
          if custom_subject.present? && custom_message.present?
            # Send custom message using a custom mailer method
            mail = SellerCommunicationsMailer.with(user: user, user_type: user_type, subject: custom_subject, message: custom_message).custom_communication
          else
            mail = SellerCommunicationsMailer.with(seller: user).general_update
          end
          Rails.logger.info "Mailer called successfully"
          Rails.logger.info "About to deliver email..."
          mail.deliver_now
          Rails.logger.info "Email delivered successfully!"
        when 'black_friday'
          mail = SellerCommunicationsMailer.with(seller: user).black_friday_email
          Rails.logger.info "Mailer called successfully"
          Rails.logger.info "About to deliver email..."
          mail.deliver_now
          Rails.logger.info "Email delivered successfully!"
        else
          Rails.logger.error "SendSellerCommunicationJob: Unknown email type '#{email_type}'"
          Rails.logger.error "=== #{user_type.upcase} COMMUNICATION JOB FAILED ==="
          return
        end

        sent_channels << "email"
        log_message = "✅ Successfully sent #{email_type} email to #{user.email}"
        Rails.logger.info log_message
      end

      # Send WhatsApp message if requested
      if channels[:whatsapp] || channels['whatsapp']
        Rails.logger.info "Attempting to send WhatsApp message..."

        if user.phone_number.present?
          if custom_message.present?
            # Process custom message for WhatsApp markdown compatibility
            message_text = process_whatsapp_markdown(custom_message, user, user_type)
          else
            message_text = build_communication_message(user, user_type, email_type)
          end

          whatsapp_result = WhatsAppNotificationService.send_message(user.phone_number, message_text)

          if whatsapp_result.is_a?(Hash) && whatsapp_result[:success]
            sent_channels << "whatsapp"
            Rails.logger.info "✅ Successfully sent WhatsApp message to #{user.phone_number}"
          else
            error_msg = whatsapp_result.is_a?(Hash) ? whatsapp_result[:error] : 'Unknown error'
            Rails.logger.warn "⚠️ Failed to send WhatsApp message to #{user.phone_number}: #{error_msg}"
          end
        else
          Rails.logger.warn "⚠️ #{user_type.capitalize} #{user.id} has no phone number - skipping WhatsApp message"
        end
      end

      if sent_channels.any?
        log_message = "📧 Communication sent via: #{sent_channels.join(', ')} for: #{user.email}"
        Rails.logger.info log_message

        log_message = "=== #{user_type.upcase} COMMUNICATION JOB COMPLETED ==="
        Rails.logger.info log_message
      else
        Rails.logger.warn "No communication channels were successfully used for #{user_type} #{user.id}"
      end

    rescue => e
      Rails.logger.error "SendSellerCommunicationJob: Failed to send email to seller #{user_id}: #{e.message}"
      Rails.logger.error "Error Class: #{e.class}"
      Rails.logger.error "Error Backtrace:"
      e.backtrace.first(10).each { |line| Rails.logger.error "  #{line}" }
      Rails.logger.error "=== SELLER COMMUNICATION JOB FAILED ==="
      raise e
    end
  end

  private

  def process_whatsapp_markdown(message, user, user_type)
    formatted_message = message.dup

    # Convert markdown to WhatsApp-compatible formatting
    # WhatsApp supports: *bold*, _italic_, ~strikethrough~, ```monospace```
    formatted_message = formatted_message
      # Headers become bold with extra spacing
      .gsub(/^### (.*)$/, '*\1*')
      .gsub(/^## (.*)$/, '*\1*')
      .gsub(/^# (.*)$/, '*\1*')
      # Bold: **text** -> *text*
      .gsub(/\*\*(.*?)\*\*/, '*\1*')
      # Italic: *text* -> _text_ (but avoid double-processing)
      .gsub(/(?<!\*)\*([^*\n]+)\*(?!\*)/, '_\1_')
      # Strikethrough: ~~text~~ -> ~text~
      .gsub(/~~(.*?)~~/, '~\1~')
      # Inline code: `text` -> ```text```
      .gsub(/`([^`]+)`/, '```\1```')
      # Blockquotes become italic
      .gsub(/^> (.*)$/, '_\1_')
      # Handle lists - convert to bullet points
      .gsub(/^\* (.*)$/, '• \1')
      .gsub(/^\d+\. (.*)$/, '• \1')
      # Clean up excessive line breaks
      .gsub(/\n{3,}/, "\n\n")

    # Add greeting at the beginning if not already present
    user_name = if user_type == 'seller'
      user.fullname.presence || user.enterprise_name.presence || 'Seller'
    else
      user.fullname.presence || user.username.presence || 'Buyer'
    end

    unless formatted_message =~ /^Hello/i || formatted_message =~ /^Hi/i
      formatted_message = "Hello *#{user_name}*,\n\n#{formatted_message}"
    end

    formatted_message
  end

  def build_communication_message(user, user_type, email_type)
    user_name = if user_type == 'seller'
      user.fullname.presence || user.enterprise_name.presence || 'Seller'
    else
      user.fullname.presence || user.username.presence || 'Buyer'
    end

    case email_type
    when 'general_update'
      <<~MESSAGE
        🔔 *Carbon Cube Kenya Update*

        Hi #{user_name},

        We wanted to share an important update with you.

        For more details, please check your email.

        ────────────────
        *Carbon Cube Kenya*
      MESSAGE
    else
      "Hello #{user_name}, you have an important update from Carbon Cube Kenya. Please check your email for details."
    end
  end
end
