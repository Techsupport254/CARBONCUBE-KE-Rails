# app/services/whatsapp_notification_service.rb
class WhatsAppNotificationService
  include HTTParty
  
  # Don't set base_uri to avoid conflicts - we'll use full URLs everywhere
  # WhatsApp service should run on a different port than Rails
  # Default to port 3002 if WHATSAPP_SERVICE_URL is not set
  
  # Simple response wrapper to maintain compatibility
  ResponseWrapper = Struct.new(:code, :body, :parsed_response) do
    def success?
      code >= 200 && code < 300
    end
  end
  
  def self.send_message(phone_number, message)
    Rails.logger.info "=== WhatsAppNotificationService.send_message START ==="
    Rails.logger.info "Phone number: #{phone_number.inspect}"
    Rails.logger.info "Message length: #{message.to_s.length} characters"
    
    unless phone_number.present?
      Rails.logger.error "Phone number is missing"
      return { success: false, error: 'Phone number is required' }
    end
    
    unless message.present?
      Rails.logger.error "Message is missing"
      return { success: false, error: 'Message is required' }
    end
    
    # Check if WhatsApp service is enabled
    is_enabled = enabled?
    Rails.logger.info "WhatsApp notifications enabled: #{is_enabled}"
    unless is_enabled
      Rails.logger.error "WhatsApp notifications are disabled"
      return { success: false, error: 'WhatsApp notifications are not enabled' }
    end
    
    # Validate phone number format (should be 10 digits for Kenyan numbers)
    cleaned_number = phone_number.to_s.gsub(/\D/, '')
    Rails.logger.info "Cleaned phone number: #{cleaned_number} (length: #{cleaned_number.length})"
    if cleaned_number.length != 10 && !cleaned_number.start_with?('254')
      Rails.logger.error "Invalid phone number format: #{cleaned_number}"
      return { success: false, error: 'Invalid phone number format. Expected 10 digits (e.g., 0712345678)' }
    end
    
    begin
      # Construct full URL for better error handling
      whatsapp_service_url_env = ENV['WHATSAPP_SERVICE_URL']
      whatsapp_service_port_env = ENV['WHATSAPP_SERVICE_PORT']
      default_port = ENV.fetch('WHATSAPP_SERVICE_PORT', '3002')
      default_url = "http://localhost:#{default_port}"
      
      Rails.logger.info "Environment variables:"
      Rails.logger.info "  WHATSAPP_SERVICE_URL: #{whatsapp_service_url_env.inspect}"
      Rails.logger.info "  WHATSAPP_SERVICE_PORT: #{whatsapp_service_port_env.inspect}"
      Rails.logger.info "  Default port: #{default_port}"
      Rails.logger.info "  Default URL: #{default_url}"
      
      service_url = ENV.fetch('WHATSAPP_SERVICE_URL', default_url)
      Rails.logger.info "Service URL before chomp: #{service_url.inspect}"
      # Ensure service_url doesn't have a trailing slash
      service_url = service_url.chomp('/')
      Rails.logger.info "Service URL after chomp: #{service_url.inspect}"
      
      full_url = "#{service_url}/send"
      Rails.logger.info "Full URL: #{full_url.inspect}"
      
      # Use Net::HTTP directly to avoid any HTTParty base_uri issues
      require 'net/http'
      require 'uri'
      
      Rails.logger.info "Parsing URI..."
      uri = URI(full_url)
      Rails.logger.info "Parsed URI details:"
      Rails.logger.info "  Scheme: #{uri.scheme}"
      Rails.logger.info "  Host: #{uri.host}"
      Rails.logger.info "  Port: #{uri.port}"
      Rails.logger.info "  Path: #{uri.path}"
      Rails.logger.info "  Full URI: #{uri.to_s}"
      
      Rails.logger.info "Creating Net::HTTP instance..."
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 10
      http.read_timeout = 10
      Rails.logger.info "Net::HTTP instance created with timeout: open=#{http.open_timeout}s, read=#{http.read_timeout}s"
      
      Rails.logger.info "Creating POST request..."
      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request_body = {
        phoneNumber: phone_number,
        message: message
      }.to_json
      request.body = request_body
      Rails.logger.info "Request body: #{request_body.inspect}"
      Rails.logger.info "Request headers: #{request.to_hash.inspect}"
      
      Rails.logger.info "Making HTTP request to #{uri.host}:#{uri.port}#{uri.path}..."
      start_time = Time.now
      http_response = http.request(request)
      elapsed_time = Time.now - start_time
      Rails.logger.info "HTTP request completed in #{elapsed_time}s"
      Rails.logger.info "Response code: #{http_response.code}"
      Rails.logger.info "Response message: #{http_response.message}"
      Rails.logger.info "Response headers: #{http_response.to_hash.inspect}"
      Rails.logger.info "Response body length: #{http_response.body.to_s.length} bytes"
      Rails.logger.info "Response body: #{http_response.body.inspect}"
      
      # Convert Net::HTTP response to HTTParty-like response for compatibility
      Rails.logger.info "Parsing response body..."
      parsed_body = begin
        if http_response.body.present?
          parsed = JSON.parse(http_response.body)
          Rails.logger.info "Successfully parsed JSON response: #{parsed.inspect}"
          parsed
        else
          Rails.logger.warn "Response body is empty"
          {}
        end
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse JSON response: #{e.message}"
        Rails.logger.error "Response body that failed to parse: #{http_response.body.inspect}"
        {}
      end
      
      response = ResponseWrapper.new(
        http_response.code.to_i,
        http_response.body,
        parsed_body
      )
      Rails.logger.info "Response wrapper created - code: #{response.code}, success?: #{response.success?}"
      
      if response.success?
        Rails.logger.info "=== WhatsApp message sent successfully ==="
        Rails.logger.info "Message ID: #{response.parsed_response['messageId']}"
        result = { success: true, message_id: response.parsed_response['messageId'] }
        Rails.logger.info "Returning result: #{result.inspect}"
        return result
      else
        Rails.logger.warn "=== WhatsApp message send failed ==="
        Rails.logger.warn "Response code: #{response.code}"
        error_body = response.parsed_response rescue response.body
        Rails.logger.warn "Error body: #{error_body.inspect}"
        
        # Check if we got a 404 - this likely means we're hitting Rails instead of WhatsApp service
        if response.code == 404
          Rails.logger.error "*** 404 ERROR - Likely hitting wrong server ***"
          Rails.logger.error "This suggests the request went to Rails (port 3001) instead of WhatsApp service (port 3002)!"
          Rails.logger.error "WHATSAPP_SERVICE_URL: #{ENV['WHATSAPP_SERVICE_URL'].inspect}"
          Rails.logger.error "WHATSAPP_SERVICE_PORT: #{ENV['WHATSAPP_SERVICE_PORT'].inspect}"
          Rails.logger.error "Full URL that was attempted: #{full_url}"
          Rails.logger.error "Expected URL should be: http://localhost:3002/send (or as configured)"
          result = { 
            success: false, 
            error: 'WhatsApp service is not running or URL is misconfigured. Please ensure the WhatsApp service is running on port 3002.', 
            error_type: 'service_unavailable' 
          }
          Rails.logger.error "Returning error result: #{result.inspect}"
          return result
        end
        
        error_message = if error_body.is_a?(Hash)
          error_body['error'] || error_body['message'] || 'Failed to send WhatsApp message'
        else
          error_body.to_s.include?('No route matches') ? 'WhatsApp service URL is incorrect or pointing to the wrong server' : 'Failed to send WhatsApp message'
        end
        Rails.logger.warn "Extracted error message: #{error_message}"
        
        # Check for specific error types
        if error_message.include?('not registered on WhatsApp')
          Rails.logger.warn "Phone number #{phone_number} is not registered on WhatsApp"
          result = { success: false, error: 'Phone number is not registered on WhatsApp', error_type: 'not_registered' }
        elsif error_message.include?('not ready')
          Rails.logger.error "WhatsApp service is not ready: #{error_message}"
          result = { success: false, error: 'WhatsApp service is not ready. Please check the service status.', error_type: 'service_unavailable' }
        elsif error_message.include?('No route matches') || error_message.include?('pointing to the wrong server')
          Rails.logger.error "Detected routing error - wrong server"
          result = { success: false, error: 'WhatsApp service is not running or URL is misconfigured. Please ensure the WhatsApp service is running on port 3002.', error_type: 'service_unavailable' }
        else
          Rails.logger.error "Failed to send WhatsApp message: #{error_message}"
          result = { success: false, error: error_message, error_type: 'send_failed' }
        end
        Rails.logger.info "Returning error result: #{result.inspect}"
        return result
      end
    rescue Net::ReadTimeout, Net::OpenTimeout => e
      Rails.logger.error "=== TIMEOUT ERROR ==="
      Rails.logger.error "Exception class: #{e.class.name}"
      Rails.logger.error "Exception message: #{e.message}"
      Rails.logger.error "Service URL: #{full_url rescue 'N/A (full_url not set)'}"
      Rails.logger.error "Backtrace:"
      Rails.logger.error e.backtrace.join("\n")
      result = { success: false, error: 'WhatsApp service timeout. The service may be unavailable or not responding. Please check if the WhatsApp service is running.', error_type: 'timeout' }
      Rails.logger.error "Returning result: #{result.inspect}"
      return result
    rescue Errno::ECONNREFUSED, SocketError => e
      Rails.logger.error "=== CONNECTION REFUSED ERROR ==="
      Rails.logger.error "Exception class: #{e.class.name}"
      Rails.logger.error "Exception message: #{e.message}"
      Rails.logger.error "Service URL: #{full_url rescue 'N/A (full_url not set)'}"
      Rails.logger.error "Backtrace:"
      Rails.logger.error e.backtrace.join("\n")
      result = { success: false, error: 'WhatsApp service is not running or not accessible. Please check if the service is started on the correct port.', error_type: 'connection_error' }
      Rails.logger.error "Returning result: #{result.inspect}"
      return result
    rescue => e
      Rails.logger.error "=== UNEXPECTED ERROR ==="
      Rails.logger.error "Exception class: #{e.class.name}"
      Rails.logger.error "Exception message: #{e.message}"
      Rails.logger.error "Service URL: #{full_url rescue 'N/A (full_url not set)'}"
      Rails.logger.error "Full backtrace:"
      Rails.logger.error e.backtrace.join("\n")
      
      error_msg = if e.message.include?('No route matches') || e.class.name.include?('RoutingError')
        Rails.logger.error "*** DETECTED ROUTING ERROR ***"
        Rails.logger.error "This suggests the request went to Rails instead of WhatsApp service!"
        Rails.logger.error "WHATSAPP_SERVICE_URL: #{ENV['WHATSAPP_SERVICE_URL'].inspect}"
        Rails.logger.error "WHATSAPP_SERVICE_PORT: #{ENV['WHATSAPP_SERVICE_PORT'].inspect}"
        Rails.logger.error "Full URL that was attempted: #{full_url rescue 'N/A'}"
        'WhatsApp service URL is incorrect or pointing to the wrong server. Please check WHATSAPP_SERVICE_URL configuration.'
      else
        "Failed to connect to WhatsApp service: #{e.message}"
      end
      result = { success: false, error: error_msg, error_type: 'connection_error' }
      Rails.logger.error "Returning result: #{result.inspect}"
      return result
    ensure
      Rails.logger.info "=== WhatsAppNotificationService.send_message END ==="
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
    
    # Use send_message and return boolean for backward compatibility
    result = send_message(phone_number, notification_message)
    result.is_a?(Hash) ? result[:success] : false
  end
  
  def self.build_notification_message(sender_name:, message_preview:, conversation_url:)
    # Format with WhatsApp-compatible markdown
    # WhatsApp supports: *bold*, _italic_, ~strikethrough~, ```monospace```, `inline code`, > block quotes, and lists
    <<~MESSAGE
      🔔 *New Message on Carbon Cube Kenya*
      
      You have a new message from *#{sender_name}*:
      
      > #{message_preview}
      
      👉 Reply here: #{conversation_url}
      
      ────────────────
      *Carbon Cube Kenya*
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
    # Use environment-aware URL: localhost for development, production URL for production
    base_url = if Rails.env.development?
      ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    else
      ENV.fetch('FRONTEND_URL', 'https://carboncube-ke.com')
    end
    
    # Use unified /messages route with conversationId query parameter for all user types
    if conversation&.id
      "#{base_url}/messages?conversationId=#{conversation.id}"
    else
      "#{base_url}/messages"
    end
  end
  
  def self.enabled?
    ENV.fetch('WHATSAPP_NOTIFICATIONS_ENABLED', 'false') == 'true'
  end
  
  def self.health_check
    begin
      require 'net/http'
      require 'uri'
      
      service_url = ENV.fetch('WHATSAPP_SERVICE_URL', "http://localhost:#{ENV.fetch('WHATSAPP_SERVICE_PORT', '3002')}")
      service_url = service_url.chomp('/')
      full_url = "#{service_url}/health"
      
      uri = URI(full_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 5
      
      request = Net::HTTP::Get.new(uri.path)
      response = http.request(request)
      
      if response.code.to_i >= 200 && response.code.to_i < 300
        parsed = JSON.parse(response.body) rescue {}
        parsed['whatsapp_ready'] == true
      else
        false
      end
    rescue => e
      Rails.logger.error "WhatsApp service health check failed: #{e.message}"
      false
    end
  end
end

