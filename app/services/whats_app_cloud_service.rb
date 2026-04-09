# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class WhatsAppCloudService
  GRAPH_URL = 'https://graph.facebook.com/v22.0'

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
        { success: false, error: result['error']&.[]('message') || 'Unknown error' }
      end
    rescue StandardError => e
      Rails.logger.error "[WhatsAppCloudService] Exception: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def self.send_template_with_image(to, template_name, image_url, body_params = [])
    phone_number_id = ENV['WHATSAPP_CLOUD_PHONE_NUMBER_ID']
    access_token = ENV['WHATSAPP_CLOUD_ACCESS_TOKEN']

    formatted_to = format_phone_number(to)
    uri = URI("#{GRAPH_URL}/#{phone_number_id}/messages")
    
    # Structure for a Media Template
    payload = {
      messaging_product: 'whatsapp',
      to: formatted_to,
      type: 'template',
      template: {
        name: template_name,
        language: { code: 'en_US' },
        components: [
          {
            type: 'header',
            parameters: [
              { type: 'image', image: { link: image_url } }
            ]
          },
          {
            type: 'body',
            parameters: body_params.map { |val| { type: 'text', text: val } }
          }
        ]
      }
    }

    send_request(uri, payload, access_token)
  end

  def self.send_template(to, template_name, language_code = 'sw', components = [])
    phone_number_id = ENV['WHATSAPP_CLOUD_PHONE_NUMBER_ID']
    access_token = ENV['WHATSAPP_CLOUD_ACCESS_TOKEN']

    formatted_to = format_phone_number(to)
    uri = URI("#{GRAPH_URL}/#{phone_number_id}/messages")

    payload = {
      messaging_product: 'whatsapp',
      to: formatted_to,
      type: 'template',
      template: {
        name: template_name,
        language: { code: language_code }
      }
    }

    payload[:template][:components] = components if components.any?

    send_request(uri, payload, access_token)
  end

  private

  def self.send_request(uri, payload, access_token)
    # Log the targeted ID for observability
    Rails.logger.info "[WhatsAppCloudAPI] Sending request via Phone ID: #{uri.path.split('/')[2]}"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?
    http.read_timeout = 10 # Set a timeout

    request = Net::HTTP::Post.new(uri.path)
    request['Authorization'] = "Bearer #{access_token}"
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    begin
      response = http.request(request)
      
      if response.body.blank?
        return { success: false, error: "Empty response from WhatsApp API", error_type: 'service_unavailable' }
      end

      result = JSON.parse(response.body)

      if response.code.to_i == 200
        { success: true, message_id: result['messages']&.first&.[]('id') }
      else
        { 
          success: false, 
          error: result['error']&.[]('message') || 'Unknown error',
          error_type: result['error']&.[]('type') || 'unknown'
        }
      end
    rescue Net::ReadTimeout, Net::OpenTimeout
      { success: false, error: "Connection to WhatsApp API timed out", error_type: 'timeout' }
    rescue JSON::ParserError
      { success: false, error: "Invalid JSON response from WhatsApp API", error_type: 'service_unavailable' }
    rescue StandardError => e
      { success: false, error: "WhatsApp API error: #{e.message}", error_type: 'connection_error' }
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

    content = case msg_data['type']
              when 'text'
                msg_data['text']['body']
              when 'reaction'
                msg_data.dig('reaction', 'emoji') || "👍"
              when 'image', 'video'
                media_data = msg_data[msg_data['type']]
                media_id = media_data['id']
                caption = media_data['caption']
                
                # Attempt to download and upload to Cloudinary
                url = download_and_upload_media(media_id, msg_data['type'])
                if url
                  if msg_data['type'] == 'image'
                    caption.present? ? "![#{caption}](#{url})\n\n#{caption}" : "![Image](#{url})"
                  else
                    # For video, we can store it as a link or a special markdown if the frontend handles it
                    caption.present? ? "[Video: #{caption}](#{url})\n\n#{caption}" : "[Video Message](#{url})"
                  end
                else
                  "[Message type: #{msg_data['type']}]"
                end
              when 'document'
                doc_data = msg_data['document']
                "[Document: #{doc_data['filename'] || 'File'}]"
              when 'audio'
                "[Audio Message]"
              when 'sticker'
                "![Sticker](#{download_and_upload_media(msg_data['sticker']['id'], 'image')})"
              else
                "[Unsupported Message: #{msg_data['type']}]"
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

  def self.download_and_upload_media(media_id, type)
    access_token = ENV['WHATSAPP_CLOUD_ACCESS_TOKEN']
    return nil if access_token.blank?

    begin
      # 1. Get the media URL from Meta
      uri = URI("#{GRAPH_URL}/#{media_id}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?

      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{access_token}"
      
      response = http.request(request)
      return nil unless response.code.to_i == 200
      
      media_info = JSON.parse(response.body)
      download_url = media_info['url']
      return nil unless download_url

      # 2. Download the media file
      download_uri = URI(download_url)
      download_http = Net::HTTP.new(download_uri.host, download_uri.port)
      download_http.use_ssl = true
      download_http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?

      download_request = Net::HTTP::Get.new(download_uri)
      download_request['Authorization'] = "Bearer #{access_token}"
      
      file_response = download_http.request(download_request)
      return nil unless file_response.code.to_i == 200

      # 3. Upload to Cloudinary
      # We create a temp file to pass to Cloudinary
      temp_file = Tempfile.new(['whatsapp_media', ".#{media_info['mime_type'].split('/').last}"])
      temp_file.binmode
      temp_file.write(file_response.body)
      temp_file.rewind

      resource_type = ['video', 'audio'].include?(type) ? 'video' : 'image'
      
      uploaded = Cloudinary::Uploader.upload(temp_file.path,
        upload_preset: ENV['UPLOAD_PRESET'],
        folder: "whatsapp_media",
        resource_type: resource_type
      )
      
      temp_file.close
      temp_file.unlink

      uploaded['secure_url']
    rescue => e
      Rails.logger.error "[WhatsAppCloudService] Media processing failed: #{e.message}"
      nil
    end
  end

  def self.find_or_create_incoming_conversation(user)
    conv_attrs = if user.is_a?(Buyer)
                   { buyer_id: user.id }
                 else
                   { seller_id: user.id }
                 end
                 
    # 1. Prefer existing conversation with an admin (Support/Marketing)
    # This ensures replies to broadcasts stay in the support thread
    existing_support = Conversation.where(conv_attrs).where.not(admin_id: nil).order(updated_at: :desc).first
    if existing_support
      existing_support.update(is_whatsapp: true) unless existing_support.is_whatsapp?
      return existing_support
    end

    # 2. Prefer existing conversation marked as WhatsApp (even if no admin yet)
    existing_whatsapp = Conversation.where(conv_attrs).where(is_whatsapp: true, buyer_id: nil).order(updated_at: :desc).first
    return existing_whatsapp if existing_whatsapp

    # 3. Last resort: ANY conversation that looks like support (no buyer partner)
    existing_any_support = Conversation.where(conv_attrs).where(buyer_id: nil).order(updated_at: :desc).first
    if existing_any_support
      existing_any_support.update(is_whatsapp: true)
      return existing_any_support
    end

    # 4. Create a new conversation marked as WhatsApp
    Conversation.create(conv_attrs.merge(is_whatsapp: true))
  end
end
