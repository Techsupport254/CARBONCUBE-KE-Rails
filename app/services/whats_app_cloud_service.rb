# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class WhatsAppCloudService
  GRAPH_URL = 'https://graph.facebook.com/v22.0'

  def self.send_message(to, body, sender: nil, conversation: nil)
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
        message_id = result['messages']&.first&.[]('id')
        Rails.logger.info "[WhatsAppCloudService] Message sent to #{formatted_to}: #{message_id}"
        
        # Store message in database if sender and conversation provided
        if sender && conversation
          begin
            message = conversation.messages.create!(
              content: body,
              sender: sender,
              whatsapp_message_id: message_id,
              status: Message::STATUS_SENT
            )
            Rails.logger.info "[WhatsAppCloudService] Message stored in database: #{message.id}"
          rescue => e
            Rails.logger.error "[WhatsAppCloudService] Failed to store message in database: #{e.message}"
          end
        end
        
        { success: true, message_id: message_id }
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

  def self.send_interactive_buttons(to, body_text, buttons)
    phone_number_id = ENV['WHATSAPP_CLOUD_PHONE_NUMBER_ID']
    access_token = ENV['WHATSAPP_CLOUD_ACCESS_TOKEN']

    formatted_to = format_phone_number(to)
    uri = URI("#{GRAPH_URL}/#{phone_number_id}/messages")

    payload = {
      messaging_product: 'whatsapp',
      to: formatted_to,
      type: 'interactive',
      interactive: {
        type: 'button',
        body: {
          text: body_text
        },
        action: {
          buttons: buttons.map { |btn|
            {
              type: 'reply',
              reply: {
                id: btn[:id],
                title: btn[:title]
              }
            }
          }
        }
      }
    }

    send_request(uri, payload, access_token)
  end

  def self.send_interactive_list(to, body_text, header_text, button_text, sections)
    phone_number_id = ENV['WHATSAPP_CLOUD_PHONE_NUMBER_ID']
    access_token = ENV['WHATSAPP_CLOUD_ACCESS_TOKEN']

    formatted_to = format_phone_number(to)
    uri = URI("#{GRAPH_URL}/#{phone_number_id}/messages")

    payload = {
      messaging_product: 'whatsapp',
      to: formatted_to,
      type: 'interactive',
      interactive: {
        type: 'list',
        header: {
          type: 'text',
          text: header_text
        },
        body: {
          text: body_text
        },
        action: {
          button: button_text,
          sections: sections.map { |section|
            {
              title: section[:title],
              rows: section[:rows].map { |row|
                {
                  id: row[:id],
                  title: row[:title],
                  description: row[:description]
                }
              }
            }
          }
        }
      }
    }

    send_request(uri, payload, access_token)
  end

  private

  def self.send_request(uri, payload, access_token)
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
        next unless value

        if value['messages']
          value['messages'].each do |msg_data|
            Rails.logger.info "[WhatsAppCloudService] Processing message: #{msg_data['id']}"
            process_incoming_message(msg_data, value['metadata'])
          end
        end

        if value['statuses']
          value['statuses'].each do |status_data|
            Rails.logger.info "[WhatsAppCloudService] Processing status: #{status_data['id']} -> #{status_data['status']}"
            process_status_update(status_data)
          end
        end
      end
    end
  end

  def self.process_incoming_message(msg_data, metadata)
    from_number = msg_data['from']
    # official WhatsApp numbers come with country code, e.g., 254716404137
    # Our DB stores them as 0716404137 (10 digits)
    local_number = from_number.start_with?('254') ? "0#{from_number[3..]}" : from_number

    Rails.logger.info "[WhatsAppCloudService] Incoming message from: #{from_number} (local: #{local_number}), type: #{msg_data['type']}"

    # Try to find a user
    user = Buyer.find_by(phone_number: local_number) || Seller.find_by(phone_number: local_number)

    unless user
      Rails.logger.warn "[WhatsAppCloudService] Received message from unknown number: #{from_number} (local: #{local_number})"
      return
    end

    Rails.logger.info "[WhatsAppCloudService] Resolved user: #{user.class.name} #{user.id} (#{user.respond_to?(:email) ? user.email : 'no email'})"

    # Extract content and media URLs
    content, media_urls = extract_message_content(msg_data)

    Rails.logger.info "[WhatsAppCloudService] Extracted content: #{content&.truncate(200)} (media_urls: #{media_urls&.length})"
    
    # Product creation logic disabled - not complete yet
    # # Check if this is a seller using product creation commands
    # if user.is_a?(Seller)
    #   product_creation_result = WhatsappProductCreationService.process_message(
    #     user,
    #     local_number,
    #     content,
    #     media_urls
    #   )
    #   
    #   if product_creation_result.is_a?(Hash) && product_creation_result[:should_respond]
    #     send_message(from_number, product_creation_result[:response])
    #     Rails.logger.info "[WhatsAppCloudService] Sent product creation response to seller #{user.id}"
    #     
    #     # Handle interactive category selection trigger
    #     if product_creation_result[:trigger_category_selection]
    #       category_result = WhatsappProductCreationService.send_category_selection(from_number)
    #       Rails.logger.info "[WhatsAppCloudService] Category selection triggered: #{category_result}"
    #     end
    #   end
    # end

    # Find or create a conversation
    # For now, we'll try to find the most recent conversation for this user
    # or create a new one with a default admin/support if it's a general inquiry
    conversation = find_or_create_incoming_conversation(user)

    unless conversation
      Rails.logger.warn "[WhatsAppCloudService] No conversation found/created for #{user.class.name} #{user.id}"
      return
    end

    Rails.logger.info "[WhatsAppCloudService] Conversation: #{conversation.id} (buyer: #{conversation.buyer_id}, seller: #{conversation.seller_id})"

    # Create the message
    # We skip callbacks that might trigger an infinite loop (sending back a notification)
    message = conversation.messages.build(
      content: content,
      sender: user,
      whatsapp_message_id: msg_data['id'],
      status: Message::STATUS_SENT # Meta already sent it to us
    )

    if message.save
      Rails.logger.info "[WhatsAppCloudService] Saved incoming message ID=#{message.id} from #{user.class.name} #{user.id} in conversation #{conversation.id}"
    else
      Rails.logger.error "[WhatsAppCloudService] Failed to save message: #{message.errors.full_messages.join(', ')}"
    end
  end
  
  def self.extract_message_content(msg_data)
    content = case msg_data['type']
              when 'text'
                msg_data['text']['body']
              when 'interactive'
                # Handle interactive button responses
                if msg_data['interactive']['type'] == 'button_reply'
                  msg_data['interactive']['button_reply']['id'] # Returns the button ID (e.g., "category_123")
                elsif msg_data['interactive']['type'] == 'list_reply'
                  msg_data['interactive']['list_reply']['id'] # Returns the list item ID (e.g., "category_123")
                else
                  "[Interactive Message]"
                end
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
              when 'system'
                msg_data.dig('system', 'body') || '[System message]'
              else
                "[Unsupported Message: #{msg_data['type']}]"
              end
    
    # Extract media URLs for product creation
    media_urls = []
    image_caption = nil
    
    if ['image', 'video'].include?(msg_data['type'])
      media_data = msg_data[msg_data['type']]
      media_id = media_data['id']
      url = download_and_upload_media(media_id, msg_data['type'])
      media_urls << url if url
      
      # Extract image caption if present
      image_caption = media_data['caption'] if media_data['caption']
    end
    
    # If there's an image caption, use it as the content (for product details)
    if image_caption && content.blank?
      content = image_caption
    elsif image_caption && content.present?
      # Combine caption with existing content
      content = "#{content}\n\nCaption: #{image_caption}"
    end
    
    [content, media_urls]
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
                 
    # We want a support-like conversation (no other partner). 
    partner_condition = if user.is_a?(Buyer)
                          { seller_id: nil }
                        else
                          { buyer_id: nil }
                        end
                 
    # 1. Prefer existing conversation with an admin (Support/Marketing)
    # This ensures replies to broadcasts stay in the support thread
    existing_support = Conversation.where(conv_attrs).where.not(admin_id: nil).order(updated_at: :desc).first
    if existing_support
      existing_support.update(is_whatsapp: true) unless existing_support.is_whatsapp?
      return existing_support
    end

    # 2. Prefer existing conversation marked as WhatsApp (even if no admin yet)
    existing_whatsapp = Conversation.where(conv_attrs).where(is_whatsapp: true).where(partner_condition).order(updated_at: :desc).first
    return existing_whatsapp if existing_whatsapp

    # 3. Last resort: ANY conversation that looks like support (no partner)
    existing_any_support = Conversation.where(conv_attrs).where(partner_condition).order(updated_at: :desc).first
    if existing_any_support
      existing_any_support.update(is_whatsapp: true)
      return existing_any_support
    end

    # 4. Create a new conversation marked as WhatsApp
    # Assign a default admin_id if possible so it shows up in the Sales dashboard
    system_admin = Rails.cache.fetch("system_admin_user", expires_in: 1.hour) do
      Admin.find_by(email: 'support@carboncube-ke.com') || Admin.find_by(username: 'admin') || Admin.first
    end
    
    Conversation.create(conv_attrs.merge(
      is_whatsapp: true,
      admin_id: system_admin&.id
    ))
  end

  def self.process_status_update(status_data)
    msg_id = status_data['id']
    status = status_data['status'] # 'sent', 'delivered', 'read', 'failed'

    message = Message.find_by(whatsapp_message_id: msg_id)
    unless message
      Rails.logger.debug "[WhatsAppCloudService] Status update for untracked message: #{msg_id}"
      return
    end

    case status
    when 'delivered'
      unless message.read? || message.delivered?
        message.update(status: Message::STATUS_DELIVERED, delivered_at: Time.current)
        broadcast_status_receipt(message, 'delivered')
      end
    when 'read'
      unless message.read?
        message.update(status: Message::STATUS_READ, read_at: Time.current)
        broadcast_status_receipt(message, 'read')
      end
    when 'failed'
      Rails.logger.error "[WhatsAppCloudService] Message delivery failed for #{msg_id}: #{status_data['errors']&.inspect}"
    end
  end

  def self.broadcast_status_receipt(message, status)
    sender_type = message.sender_type.downcase
    sender_id = message.sender_id

    # Broadcast to the presence channel of the sender
    ActionCable.server.broadcast(
      "presence_#{sender_type}_#{sender_id}",
      {
        type: status == 'read' ? 'message_read' : 'message_delivered',
        message_id: message.id,
        conversation_id: message.conversation_id,
        "#{status}_at" => message.send("#{status}_at"),
        status: status
      }
    )

    # Broadcast to the conversation channel to update UI in real-time
    broadcast_payload = {
      type: status == 'read' ? 'message_read' : 'message_delivered',
      message_id: message.id,
      conversation_id: message.conversation_id,
      status: status
    }
    broadcast_payload["#{status}_at"] = message.send("#{status}_at")

    if message.conversation.buyer_id
      ActionCable.server.broadcast(
        "conversations_buyer_#{message.conversation.buyer_id}",
        broadcast_payload
      )
    end
    if message.conversation.seller_id
      ActionCable.server.broadcast(
        "conversations_seller_#{message.conversation.seller_id}",
        broadcast_payload
      )
    end
    if message.conversation.inquirer_seller_id && message.conversation.inquirer_seller_id != message.conversation.seller_id
      ActionCable.server.broadcast(
        "conversations_seller_#{message.conversation.inquirer_seller_id}",
        broadcast_payload
      )
    end
  end
end
