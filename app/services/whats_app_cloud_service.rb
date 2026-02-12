# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class WhatsAppCloudService
  GRAPH_URL = 'https://graph.facebook.com/v18.0'

  def self.send_message(to, body)
    phone_number_id = ENV['WHATSAPP_CLOUD_PHONE_NUMBER_ID']
    access_token = ENV['WHATSAPP_CLOUD_ACCESS_TOKEN']

    if phone_number_id.blank? || access_token.blank?
      Rails.logger.error '[WhatsAppCloudService] Missing credentials'
      return { success: false, error: 'Missing credentials' }
    end

    # Format number: remove leading 0 and add 254 if needed
    formatted_to = format_phone_number(to)

    uri = URI("#{GRAPH_URL}/#{phone_number_id}/messages")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    # In development, we skip SSL verification to avoid local environment issues (cert CRL)
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?

    request = Net::HTTP::Post.new(uri.path)
    request['Authorization'] = "Bearer #{access_token}"
    request['Content-Type'] = 'application/json'

    payload = {
      messaging_product: 'whatsapp',
      to: formatted_to,
      type: 'text',
      text: { body: body }
    }

    request.body = payload.to_json

    begin
      response = http.request(request)
      result = JSON.parse(response.body)

      if response.code.to_i == 200
        Rails.logger.info "[WhatsAppCloudService] Message sent to #{formatted_to}: #{result['messages']&.first&.[]('id')}"
        { success: true, message_id: result['messages']&.first&.[]('id') }
      else
        Rails.logger.error "[WhatsAppCloudService] Failed to send message: #{response.body}"
        { success: false, error: result['error']&.[]('message') || 'Unknown error' }
      end
    rescue StandardError => e
      Rails.logger.error "[WhatsAppCloudService] Exception: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def self.format_phone_number(number)
    cleaned = number.to_s.gsub(/\D/, '')
    if cleaned.start_with?('0')
      "254#{cleaned[1..]}"
    elsif !cleaned.start_with?('254') && cleaned.length == 9
      "254#{cleaned}"
    else
      cleaned
    end
  end

  def self.handle_webhook_payload(payload)
    Rails.logger.info "[WhatsAppCloudService] Handling payload: #{payload.inspect}"
    unless payload['object'] == 'whatsapp_business_account'
      Rails.logger.warn "[WhatsAppCloudService] Skipping payload: object is #{payload['object']}"
      return
    end

    payload['entry']&.each do |entry|
      entry['changes']&.each do |change|
        next unless change['field'] == 'messages'

        value = change['value']
        next unless value['messages']

        value['messages'].each do |msg_data|
          Rails.logger.info "[WhatsAppCloudService] Processing message: #{msg_data['id']}"
          process_incoming_message(msg_data, value['metadata'])
        end
      end
    end
  end

  def self.process_incoming_message(msg_data, metadata)
    from_number = msg_data['from']
    # official WhatsApp numbers come with country code, e.g., 254716404137
    # Our DB stores them as 0716404137 (10 digits)
    local_number = from_number.start_with?('254') ? "0#{from_number[3..]}" : from_number
    
    # Try to find a user
    user = Buyer.find_by(phone_number: local_number) || Seller.find_by(phone_number: local_number)
    
    unless user
      Rails.logger.warn "[WhatsAppCloudService] Received message from unknown number: #{from_number}"
      return
    end

    content = if msg_data['type'] == 'text'
                msg_data['text']['body']
              else
                "[Message type: #{msg_data['type']}]"
              end

    # Find or create a conversation
    # For now, we'll try to find the most recent conversation for this user
    # or create a new one with a default admin/support if it's a general inquiry
    conversation = find_or_create_incoming_conversation(user)
    
    return unless conversation

    # Create the message
    # We skip callbacks that might trigger an infinite loop (sending back a notification)
    message = conversation.messages.build(
      content: content,
      sender: user,
      whatsapp_message_id: msg_data['id'],
      status: Message::STATUS_SENT # Meta already sent it to us
    )
    
    if message.save
      Rails.logger.info "[WhatsAppCloudService] Saved incoming message from #{user.class.name} #{user.id}"
    else
      Rails.logger.error "[WhatsAppCloudService] Failed to save message: #{message.errors.full_messages.join(', ')}"
    end
  end

  def self.find_or_create_incoming_conversation(user)
    # Strategy: 
    # 1. Look for an existing conversation with an admin (support)
    # 2. Or look for the most recent conversation the user had
    # 3. Or create a support conversation
    
    conv_attrs = if user.is_a?(Buyer)
                   { buyer_id: user.id }
                 else
                   { seller_id: user.id }
                 end
                 
    # Prefer existing conversation with messages that is marked as whatsapp
    existing = Conversation.where(conv_attrs).where(is_whatsapp: true).order(updated_at: :desc).first
    return existing if existing

    # Create a new conversation marked as WhatsApp
    Conversation.create(conv_attrs.merge(is_whatsapp: true))
  end
end
