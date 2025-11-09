# app/services/whatsapp_notification_service.rb
class WhatsAppNotificationService
  include HTTParty
  
  base_uri ENV.fetch('WHATSAPP_SERVICE_URL', 'http://localhost:3001')
  
  def self.send_message(phone_number, message)
    return false unless phone_number.present? && message.present?
    
    # Check if WhatsApp service is enabled
    return false unless enabled?
    
    begin
      response = post('/send', {
        body: {
          phoneNumber: phone_number,
          message: message
        }.to_json,
        headers: {
          'Content-Type' => 'application/json'
        },
        timeout: 10
      })
      
      if response.success?
        Rails.logger.info "WhatsApp message sent successfully to #{phone_number}"
        true
      else
        Rails.logger.error "Failed to send WhatsApp message: #{response.body}"
        false
      end
    rescue => e
      Rails.logger.error "Error sending WhatsApp message: #{e.message}"
      false
    end
  end
  
  def self.send_message_notification(message, recipient, conversation = nil)
    return false unless message.present? && recipient.present?
    
    # Only send to sellers for now
    return false unless recipient.is_a?(Seller)
    
    # Get phone number
    phone_number = recipient.phone_number
    return false unless phone_number.present?
    
    # Build notification message
    sender_name = get_sender_name(message.sender)
    conversation_url = get_conversation_url(recipient, conversation)
    
    notification_message = build_notification_message(
      sender_name: sender_name,
      message_preview: message.content.truncate(100),
      conversation_url: conversation_url
    )
    
    send_message(phone_number, notification_message)
  end
  
  def self.build_notification_message(sender_name:, message_preview:, conversation_url:)
    <<~MESSAGE
      🔔 New Message on Carbon Cube Kenya
      
      You have a new message from #{sender_name}:
      
      "#{message_preview}"
      
      Reply here: #{conversation_url}
      
      ---
      Carbon Cube Kenya
    MESSAGE
  end
  
  def self.get_sender_name(sender)
    case sender.class.name
    when 'Buyer'
      sender.username.present? ? sender.username : sender.email.split('@').first
    when 'Seller'
      sender.fullname.present? ? sender.fullname : sender.enterprise_name
    when 'Admin'
      'Carbon Cube Support'
    else
      sender.email.split('@').first
    end
  end
  
  def self.get_conversation_url(recipient, conversation = nil)
    base_url = ENV.fetch('FRONTEND_URL', 'https://carboncube-ke.com')
    
    if recipient.is_a?(Seller)
      if conversation&.id
        "#{base_url}/seller/conversations/#{conversation.id}"
      else
        "#{base_url}/seller/conversations"
      end
    else
      if conversation&.id
        "#{base_url}/conversations/#{conversation.id}"
      else
        "#{base_url}/conversations"
      end
    end
  end
  
  def self.enabled?
    ENV.fetch('WHATSAPP_NOTIFICATIONS_ENABLED', 'false') == 'true'
  end
  
  def self.health_check
    begin
      response = get('/health', timeout: 5)
      response.success? && response.parsed_response['whatsapp_ready'] == true
    rescue => e
      Rails.logger.error "WhatsApp service health check failed: #{e.message}"
      false
    end
  end
end

