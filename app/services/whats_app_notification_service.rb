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
  
  # Helper method to get the WhatsApp service URL
  # Priority: 1. WHATSAPP_SERVICE_URL env var (if set) - respects local/production config
  #           2. VPS IP in production (from VPS_HOST env var or default) - fallback if env var not set
  #           3. localhost in development/test (localhost:3002) - fallback if env var not set
  # 
  # Note: If domain-based URL fails to resolve, automatically falls back to VPS IP in production
  def self.get_service_url
    # If WHATSAPP_SERVICE_URL is explicitly set, use it (respects local config)
    if ENV['WHATSAPP_SERVICE_URL'].present?
      url = ENV['WHATSAPP_SERVICE_URL'].chomp('/')
      
      # In production, if domain doesn't resolve, fall back to VPS IP
      vps_host = ENV.fetch('VPS_HOST', '188.245.245.79')
      if Rails.env.production? && url.include?('carboncube-ke.com') && !url.include?(vps_host)
        # Try to resolve the domain - if it fails, use VPS IP
        begin
          require 'socket'
          uri = URI(url)
          # Try to resolve the hostname
          Socket.getaddrinfo(uri.host, nil, Socket::AF_INET)
          # If we get here, domain resolves, use it
          return url
        rescue SocketError => e
          # Domain doesn't resolve, use VPS IP fallback
          Rails.logger.warn "WHATSAPP_SERVICE_URL domain (#{url}) doesn't resolve, falling back to VPS IP"
          default_port = ENV.fetch('WHATSAPP_SERVICE_PORT', '3002')
          return "http://#{vps_host}:#{default_port}"
        end
      end
      
      return url
    end
    
    # Otherwise, use environment-appropriate default
    default_port = ENV.fetch('WHATSAPP_SERVICE_PORT', '3002')
    if Rails.env.production?
      vps_host = ENV.fetch('VPS_HOST', '188.245.245.79')
      "http://#{vps_host}:#{default_port}"
    else
      "http://localhost:#{default_port}"
    end
  end
  
  def self.send_message(phone_number, message)
    if Rails.env.development?
      Rails.logger.info "=== WhatsAppNotificationService.send_message START ==="
      Rails.logger.info "Phone number: #{phone_number.inspect}"
      Rails.logger.info "Message length: #{message.to_s.length} characters"
    end
    
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
    
    # Validate phone number format (accept various international and local formats)
    cleaned_number = phone_number.to_s.gsub(/\D/, '')
        if Rails.env.development?
      Rails.logger.info "Cleaned phone number: #{cleaned_number} (length: #{cleaned_number.length})"
    end
    # Accept numbers with 7-15 digits, or international format starting with 254
    if cleaned_number.length < 7 || cleaned_number.length > 15
      Rails.logger.error "Invalid phone number format: #{cleaned_number}"
      return { success: false, error: 'Invalid phone number format. Please enter a valid phone number.' }
    end
    
    begin
      # Get service URL using helper method (respects env vars and environment)
      service_url = get_service_url
      
      if Rails.env.development?
        Rails.logger.info "WhatsApp Service Configuration:"
        Rails.logger.info "  WHATSAPP_SERVICE_URL: #{ENV['WHATSAPP_SERVICE_URL'].inspect || 'NOT SET (using default)'}"
        Rails.logger.info "  WHATSAPP_SERVICE_PORT: #{ENV['WHATSAPP_SERVICE_PORT'].inspect || 'NOT SET (using 3002)'}"
        Rails.logger.info "  Environment: #{Rails.env}"
        Rails.logger.info "  Service URL: #{service_url}"
      end

      full_url = "#{service_url}/send"
      
      # Use Net::HTTP directly to avoid any HTTParty base_uri issues
      require 'net/http'
      require 'uri'
      
      if Rails.env.development?
        Rails.logger.info "Parsing URI..."
      end
      uri = URI(full_url)
      if Rails.env.development?
        Rails.logger.info "Parsed URI details:"
        Rails.logger.info "  Scheme: #{uri.scheme}"
        Rails.logger.info "  Host: #{uri.host}"
        Rails.logger.info "  Port: #{uri.port}"
        Rails.logger.info "  Path: #{uri.path}"
        Rails.logger.info "  Full URI: #{uri.to_s}"

        Rails.logger.info "Creating Net::HTTP instance..."
      end
      http = Net::HTTP.new(uri.host, uri.port)
      if uri.scheme == 'https'
        http.use_ssl = true
        # Disable SSL verification for self-signed certificates (common on VPS)
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http.open_timeout = 15  # Increased timeout for VPS connection
      http.read_timeout = 30  # Increased timeout for VPS connection
      if Rails.env.development?
        Rails.logger.info "Net::HTTP instance created with timeout: open=#{http.open_timeout}s, read=#{http.read_timeout}s"

        Rails.logger.info "Creating POST request..."
      end
      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request_body = {
        phoneNumber: phone_number,
        message: message
      }.to_json
      request.body = request_body
      if Rails.env.development?
        Rails.logger.info "Request body: #{request_body.inspect}"
        Rails.logger.info "Request headers: #{request.to_hash.inspect}"

        Rails.logger.info "Making HTTP request to #{uri.host}:#{uri.port}#{uri.path}..."
      end
      start_time = Time.now
      http_response = http.request(request)
      elapsed_time = Time.now - start_time
      if Rails.env.development?
        Rails.logger.info "HTTP request completed in #{elapsed_time}s"
        Rails.logger.info "Response code: #{http_response.code}"
        Rails.logger.info "Response message: #{http_response.message}"
        Rails.logger.info "Response headers: #{http_response.to_hash.inspect}"
        Rails.logger.info "Response body length: #{http_response.body.to_s.length} bytes"
        Rails.logger.info "Response body: #{http_response.body.inspect}"
      end
      
      # Convert Net::HTTP response to HTTParty-like response for compatibility
      if Rails.env.development?
        Rails.logger.info "Parsing response body..."
      end
      parsed_body = begin
        if http_response.body.present?
          parsed = JSON.parse(http_response.body)
          if Rails.env.development?
            Rails.logger.info "Successfully parsed JSON response: #{parsed.inspect}"
          end
          parsed
        else
          if Rails.env.development?
            Rails.logger.warn "Response body is empty"
          end
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
      # Log timeout errors gracefully - less verbose in production
      if Rails.env.development?
        Rails.logger.warn "=== WhatsApp Service Timeout ==="
        Rails.logger.warn "Service URL: #{full_url rescue 'N/A (full_url not set)'}"
        Rails.logger.warn "Error: #{e.class.name} - #{e.message}"
      else
        # In production, log a simple warning without full backtrace
        Rails.logger.warn "WhatsApp service timeout: #{e.message}"
      end
      result = { success: false, error: 'WhatsApp service timeout. The service may be unavailable or not responding. Please check if the WhatsApp service is running.', error_type: 'timeout' }
      return result
    rescue Errno::ECONNREFUSED, SocketError => e
      # Log connection errors gracefully - less verbose in production
      if Rails.env.development?
        Rails.logger.warn "=== WhatsApp Service Connection Error ==="
        Rails.logger.warn "Service URL: #{full_url rescue 'N/A (full_url not set)'}"
        Rails.logger.warn "Error: #{e.class.name} - #{e.message}"
      else
        # In production, log a simple warning without full backtrace
        Rails.logger.warn "WhatsApp service unavailable: #{e.message}"
      end
      result = { success: false, error: 'WhatsApp service is not running or not accessible. Please check if the service is started on the correct port.', error_type: 'connection_error' }
      return result
    rescue => e
      # Log unexpected errors gracefully - less verbose in production
      if Rails.env.development?
        Rails.logger.warn "=== WhatsApp Service Unexpected Error ==="
        Rails.logger.warn "Exception class: #{e.class.name}"
        Rails.logger.warn "Exception message: #{e.message}"
        Rails.logger.warn "Service URL: #{full_url rescue 'N/A (full_url not set)'}"
        if e.message.include?('No route matches') || e.class.name.include?('RoutingError')
          Rails.logger.warn "Routing error detected - request may have gone to Rails instead of WhatsApp service"
          Rails.logger.warn "WHATSAPP_SERVICE_URL: #{ENV['WHATSAPP_SERVICE_URL'].inspect}"
          Rails.logger.warn "WHATSAPP_SERVICE_PORT: #{ENV['WHATSAPP_SERVICE_PORT'].inspect}"
        end
      else
        # In production, log a simple warning without full backtrace
        Rails.logger.warn "WhatsApp service error: #{e.class.name} - #{e.message}"
      end
      
      error_msg = if e.message.include?('No route matches') || e.class.name.include?('RoutingError')
        'WhatsApp service URL is incorrect or pointing to the wrong server. Please check WHATSAPP_SERVICE_URL configuration.'
      else
        "Failed to connect to WhatsApp service: #{e.message}"
      end
      result = { success: false, error: error_msg, error_type: 'connection_error' }
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
  
  # Send welcome message to new users
  # Note: Welcome messages are sent regardless of WhatsApp notifications enabled setting
  # since they are important onboarding communications for new users
  def self.send_welcome_message(user)
    return false unless user.present?
    
    # Get phone number
    phone_number = user.phone_number
    return false unless phone_number.present?
    
    # Build welcome message based on user type
    welcome_message = build_welcome_message(user)
    
    # Send message via WhatsApp (bypass enabled? check for welcome messages)
    # Welcome messages are important onboarding communications and should always be sent
    # We call send_message_without_enabled_check to bypass the enabled? check
    # Send text-only message (no image)
    result = send_message_without_enabled_check(phone_number, welcome_message, nil)
    
    if result.is_a?(Hash) && result[:success]
      Rails.logger.info "✅ Welcome WhatsApp message sent to #{user.class.name} #{user.email} (#{phone_number})"
      true
    else
      error_msg = result.is_a?(Hash) ? result[:error] : 'Unknown error'
      Rails.logger.warn "⚠️ Failed to send welcome WhatsApp message to #{user.class.name} #{user.email}: #{error_msg}"
      false
    end
  rescue => e
    Rails.logger.error "❌ Error sending welcome WhatsApp message: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    false
  end
  
  # Send message without checking if WhatsApp notifications are enabled
  # Used for critical messages like welcome messages that should always be sent
  # image_path: optional path to image file to attach
  def self.send_message_without_enabled_check(phone_number, message, image_path = nil)
    if Rails.env.development?
      Rails.logger.info "=== WhatsAppNotificationService.send_message_without_enabled_check START ==="
      Rails.logger.info "Phone number: #{phone_number.inspect}"
      Rails.logger.info "Message length: #{message.to_s.length} characters"
      Rails.logger.info "Image path: #{image_path.inspect}" if image_path
    end
    
    unless phone_number.present?
      Rails.logger.error "Phone number is missing"
      return { success: false, error: 'Phone number is required' }
    end
    
    unless message.present?
      Rails.logger.error "Message is missing"
      return { success: false, error: 'Message is required' }
    end
    
    # Validate phone number format (accept various international and local formats)
    cleaned_number = phone_number.to_s.gsub(/\D/, '')
    if Rails.env.development?
      Rails.logger.info "Cleaned phone number: #{cleaned_number} (length: #{cleaned_number.length})"
    end
    # Accept numbers with 7-15 digits, or international format starting with 254
    if cleaned_number.length < 7 || cleaned_number.length > 15
      Rails.logger.error "Invalid phone number format: #{cleaned_number}"
      return { success: false, error: 'Invalid phone number format. Please enter a valid phone number.' }
    end
    
    begin
      # Get service URL using helper method (respects env vars and environment)
      service_url = get_service_url
      
      if Rails.env.development?
        Rails.logger.info "WhatsApp Service Configuration:"
        Rails.logger.info "  WHATSAPP_SERVICE_URL: #{ENV['WHATSAPP_SERVICE_URL'].inspect || 'NOT SET (using default)'}"
        Rails.logger.info "  WHATSAPP_SERVICE_PORT: #{ENV['WHATSAPP_SERVICE_PORT'].inspect || 'NOT SET (using 3002)'}"
        Rails.logger.info "  Environment: #{Rails.env}"
        Rails.logger.info "  Service URL: #{service_url}"
      end

      full_url = "#{service_url}/send"
      
      # Use Net::HTTP directly to avoid any HTTParty base_uri issues
      require 'net/http'
      require 'uri'
      
      if Rails.env.development?
        Rails.logger.info "Parsing URI..."
      end
      uri = URI(full_url)
      if Rails.env.development?
        Rails.logger.info "Parsed URI details:"
        Rails.logger.info "  Scheme: #{uri.scheme}"
        Rails.logger.info "  Host: #{uri.host}"
        Rails.logger.info "  Port: #{uri.port}"
        Rails.logger.info "  Path: #{uri.path}"
        Rails.logger.info "  Full URI: #{uri.to_s}"

        Rails.logger.info "Creating Net::HTTP instance..."
      end
      http = Net::HTTP.new(uri.host, uri.port)
      if uri.scheme == 'https'
        http.use_ssl = true
        # Disable SSL verification for self-signed certificates (common on VPS)
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http.open_timeout = 15  # Increased timeout for VPS connection
      http.read_timeout = 30  # Increased timeout for VPS connection
      if Rails.env.development?
        Rails.logger.info "Net::HTTP instance created with timeout: open=#{http.open_timeout}s, read=#{http.read_timeout}s"

        Rails.logger.info "Creating POST request..."
      end
      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request_body = {
        phoneNumber: phone_number,
        message: message
      }
      request_body[:imagePath] = image_path if image_path.present? && File.exist?(image_path)
      request.body = request_body.to_json
      if Rails.env.development?
        Rails.logger.info "Request body: #{request_body.inspect}"
        Rails.logger.info "Request headers: #{request.to_hash.inspect}"

        Rails.logger.info "Making HTTP request to #{uri.host}:#{uri.port}#{uri.path}..."
      end
      start_time = Time.now
      http_response = http.request(request)
      elapsed_time = Time.now - start_time
      if Rails.env.development?
        Rails.logger.info "HTTP request completed in #{elapsed_time}s"
        Rails.logger.info "Response code: #{http_response.code}"
        Rails.logger.info "Response message: #{http_response.message}"
        Rails.logger.info "Response headers: #{http_response.to_hash.inspect}"
        Rails.logger.info "Response body length: #{http_response.body.to_s.length} bytes"
        Rails.logger.info "Response body: #{http_response.body.inspect}"
      end
      
      # Convert Net::HTTP response to HTTParty-like response for compatibility
      if Rails.env.development?
        Rails.logger.info "Parsing response body..."
      end
      parsed_body = begin
        if http_response.body.present?
          parsed = JSON.parse(http_response.body)
          if Rails.env.development?
            Rails.logger.info "Successfully parsed JSON response: #{parsed.inspect}"
          end
          parsed
        else
          if Rails.env.development?
            Rails.logger.warn "Response body is empty"
          end
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
      # Log timeout errors gracefully - less verbose in production
      if Rails.env.development?
        Rails.logger.warn "=== WhatsApp Service Timeout ==="
        Rails.logger.warn "Service URL: #{full_url rescue 'N/A (full_url not set)'}"
        Rails.logger.warn "Error: #{e.class.name} - #{e.message}"
      else
        # In production, log a simple warning without full backtrace
        Rails.logger.warn "WhatsApp service timeout: #{e.message}"
      end
      result = { success: false, error: 'WhatsApp service timeout. The service may be unavailable or not responding. Please check if the WhatsApp service is running.', error_type: 'timeout' }
      return result
    rescue Errno::ECONNREFUSED, SocketError => e
      # Log connection errors gracefully - less verbose in production
      if Rails.env.development?
        Rails.logger.warn "=== WhatsApp Service Connection Error ==="
        Rails.logger.warn "Service URL: #{full_url rescue 'N/A (full_url not set)'}"
        Rails.logger.warn "Error: #{e.class.name} - #{e.message}"
      else
        # In production, log a simple warning without full backtrace
        Rails.logger.warn "WhatsApp service unavailable: #{e.message}"
      end
      result = { success: false, error: 'WhatsApp service is not running or not accessible. Please check if the service is started on the correct port.', error_type: 'connection_error' }
      return result
    rescue => e
      # Log unexpected errors gracefully - less verbose in production
      if Rails.env.development?
        Rails.logger.warn "=== WhatsApp Service Unexpected Error ==="
        Rails.logger.warn "Exception class: #{e.class.name}"
        Rails.logger.warn "Exception message: #{e.message}"
        Rails.logger.warn "Service URL: #{full_url rescue 'N/A (full_url not set)'}"
        if e.message.include?('No route matches') || e.class.name.include?('RoutingError')
          Rails.logger.warn "Routing error detected - request may have gone to Rails instead of WhatsApp service"
          Rails.logger.warn "WHATSAPP_SERVICE_URL: #{ENV['WHATSAPP_SERVICE_URL'].inspect}"
          Rails.logger.warn "WHATSAPP_SERVICE_PORT: #{ENV['WHATSAPP_SERVICE_PORT'].inspect}"
        end
      else
        # In production, log a simple warning without full backtrace
        Rails.logger.warn "WhatsApp service error: #{e.class.name} - #{e.message}"
      end
      
      error_msg = if e.message.include?('No route matches') || e.class.name.include?('RoutingError')
        'WhatsApp service URL is incorrect or pointing to the wrong server. Please check WHATSAPP_SERVICE_URL configuration.'
      else
        "Failed to connect to WhatsApp service: #{e.message}"
      end
      result = { success: false, error: error_msg, error_type: 'connection_error' }
      return result
    ensure
      Rails.logger.info "=== WhatsAppNotificationService.send_message_without_enabled_check END ==="
    end
  end
  
  def self.build_welcome_message(user)
    user_name = get_user_display_name(user)
    user_type = user.class.name.downcase
    
    # Get frontend URL
    base_url = if Rails.env.development?
      ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    else
      ENV.fetch('FRONTEND_URL', 'https://carboncube-ke.com')
    end
    
    # Build message based on user type
    # Note: URLs are placed on separate lines to ensure WhatsApp detects them as clickable links
    # WhatsApp requires recipients to save the sender's number or reply for links to be clickable
    if user_type == 'seller'
      <<~MESSAGE
        🎉 *Welcome to Carbon Cube Kenya!*
        
        Hi #{user_name},
        
        Thank you for joining Carbon Cube Kenya as a seller! We're excited to have you on board.
        
        *Get started:*
        • Complete your profile:
        #{base_url}/seller/profile
        
        • List your products:
        #{base_url}/seller/products/new
        
        • View your dashboard:
        #{base_url}/seller/dashboard
        
        💡 *Tip:* Reply to this message to make links clickable!
        
        *Need help?*
        Contact our support team anytime - we're here to help you succeed!
        
        Welcome aboard! 🚀
        
        ────────────────
        *Carbon Cube Kenya*
      MESSAGE
    else
      # Buyer welcome message
      <<~MESSAGE
        🎉 *Welcome to Carbon Cube Kenya!*
        
        Hi #{user_name},
        
        Thank you for joining Carbon Cube Kenya! We're thrilled to have you as part of our community.
        
        *Discover amazing products:*
        • Browse categories:
        #{base_url}
        
        • Find best deals:
        #{base_url}/deals
        
        • Save favorites:
        #{base_url}/wishlist
        
        💡 *Tip:* Reply to this message to make links clickable!
        
        *Need help?*
        Contact our support team anytime - we're here to help!
        
        Happy shopping! 🛍️
        
        ────────────────
        *Carbon Cube Kenya*
      MESSAGE
    end
  end
  
  def self.get_user_display_name(user)
    case user.class.name
    when 'Buyer'
      user.fullname.present? ? user.fullname : (user.username.present? ? user.username : user.email.split('@').first)
    when 'Seller'
      user.fullname.present? ? user.fullname : (user.enterprise_name.present? ? user.enterprise_name : user.email.split('@').first)
    else
      user.email.split('@').first
    end
  end
  
  def self.check_number(phone_number)
    # Logging disabled to reduce console noise
    # Rails.logger.info "=== WhatsAppNotificationService.check_number START ==="
    # Rails.logger.info "Phone number: #{phone_number.inspect}"
    
    unless phone_number.present?
      Rails.logger.error "Phone number is missing"
      return { isRegistered: false, error: 'Phone number is required' }
    end
    
    # Validate phone number format (should be 10 digits for Kenyan numbers)
    cleaned_number = phone_number.to_s.gsub(/\D/, '')
    # Logging disabled to reduce console noise
    # if Rails.env.development?
    #   Rails.logger.info "Cleaned phone number: #{cleaned_number} (length: #{cleaned_number.length})"
    # end
    if cleaned_number.length != 10 && !cleaned_number.start_with?('254')
      Rails.logger.error "Invalid phone number format: #{cleaned_number}"
      return { isRegistered: false, error: 'Invalid phone number format. Expected 10 digits (e.g., 0712345678)' }
    end
    
    # Format number for international format (254XXXXXXXXX)
    formatted_number = if cleaned_number.start_with?('254')
      cleaned_number
    elsif cleaned_number.start_with?('0')
      "254#{cleaned_number[1..-1]}"
    else
      "254#{cleaned_number}"
    end
    
    # Try local WhatsApp service first (if enabled)
    if enabled?
      begin
        # Get service URL using helper method (respects env vars and environment)
        service_url = get_service_url
        full_url = "#{service_url}/check"
        
        # Logging disabled to reduce console noise
        # Rails.logger.info "Checking WhatsApp number via local service: #{full_url}"
        
        response = HTTParty.post(
          full_url,
          body: {
            phoneNumber: cleaned_number
          }.to_json,
          headers: {
            'Content-Type' => 'application/json'
          },
          timeout: 5  # Shorter timeout for faster fallback
        )
        
        if response.success?
          parsed_response = response.parsed_response
          is_registered = parsed_response['isRegistered'] == true
          
          # Logging disabled to reduce console noise
          # Rails.logger.info "Phone number #{cleaned_number} is #{is_registered ? 'registered' : 'not registered'} on WhatsApp (via local service)"
          
          return {
            isRegistered: is_registered,
            phoneNumber: cleaned_number,
            formattedNumber: formatted_number,
            success: true,
            method: 'local_service'
          }
        end
      rescue Net::ReadTimeout, Net::OpenTimeout => e
        Rails.logger.warn "Local WhatsApp service timeout, trying fallback method"
      rescue => e
        Rails.logger.warn "Local WhatsApp service error: #{e.message}, trying fallback method"
      end
    end
    
    # Fallback: Use WhatsApp API endpoint to check if number is registered
    # This uses WhatsApp's public API endpoint which is more reliable
    # Logging disabled to reduce console noise
    # Rails.logger.info "Using WhatsApp API method to check registration"
    
    begin
      require 'net/http'
      require 'uri'
      
      # Use WhatsApp's check number endpoint (if available) or wa.me redirect method
      # Try the WhatsApp Web API endpoint first
      api_url = "https://api.whatsapp.com/send/?phone=#{formatted_number}&text=&type=phone_number&app_absent=0"
      
      uri = URI(api_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      # Disable SSL verification for WhatsApp API in development to avoid certificate issues
      if Rails.env.development?
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http.open_timeout = 5
      http.read_timeout = 5
      
      request = Net::HTTP::Get.new(uri.path + "?" + uri.query)
      request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      request['Accept-Language'] = 'en-US,en;q=0.5'
      
      response = http.request(request)
      
      # Logging disabled to reduce console noise
      # Rails.logger.info "WhatsApp API check response code: #{response.code}"
      
      # Follow redirects if needed
      if response.is_a?(Net::HTTPRedirection)
        location = response['location']
        Rails.logger.info "Following redirect to: #{location}"
        
        redirect_uri = URI(location)
        redirect_http = Net::HTTP.new(redirect_uri.host, redirect_uri.port)
        redirect_http.use_ssl = true
        # Disable SSL verification for WhatsApp API in development to avoid certificate issues
        if Rails.env.development?
          redirect_http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        redirect_http.open_timeout = 5
        redirect_http.read_timeout = 5
        
        redirect_request = Net::HTTP::Get.new(redirect_uri.path + (redirect_uri.query ? "?" + redirect_uri.query : ""))
        redirect_request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        
        response = redirect_http.request(redirect_request)
      end
      
      body = response.body.to_s
      
      # Check for error indicators in the page content
      # WhatsApp shows specific messages when number is not registered
      error_indicators = [
        'phone number shared via url is invalid',
        'not registered',
        'invalid phone number',
        'this phone number is not on whatsapp',
        'phone number is not registered',
        'number not registered',
        'invalid number'
      ]
      
      has_error = error_indicators.any? { |indicator| body.downcase.include?(indicator.downcase) }
      is_registered = !has_error && response.code.to_i < 400
      
      # Additional check: If we get a successful redirect to WhatsApp Web, it's likely registered
      if response.code.to_i == 200 && body.include?('whatsapp') && !has_error
        is_registered = true
      end
      
      # Logging disabled to reduce console noise
      # Rails.logger.info "Phone number #{cleaned_number} is #{is_registered ? 'registered' : 'not registered'} on WhatsApp (via API method)"
      
      return {
        isRegistered: is_registered,
        phoneNumber: cleaned_number,
        formattedNumber: formatted_number,
        success: true,
        method: 'whatsapp_api_check'
      }
      
    rescue Net::ReadTimeout, Net::OpenTimeout => e
      Rails.logger.warn "Timeout checking WhatsApp API: #{e.message}, falling back to format validation"
      # Fall back to format validation if timeout
    rescue => e
      Rails.logger.warn "Error checking WhatsApp API: #{e.message}, falling back to format validation"
      Rails.logger.warn e.backtrace.first(3).join("\n")
      # Fall back to format validation on error
    end
    
    # Final fallback: Simple format validation if wa.me check fails
    Rails.logger.info "Using format validation fallback"
    
    # Basic validation: Kenyan numbers should be 10 digits starting with 0 or 7
    is_valid_format = cleaned_number.length == 10 && (cleaned_number.start_with?('0') || cleaned_number.start_with?('7'))
    
    if is_valid_format
      # Return optimistic result - show WhatsApp button, let WhatsApp handle validation
      return {
        isRegistered: true,  # Optimistic - assume valid
        phoneNumber: cleaned_number,
        formattedNumber: formatted_number,
        success: true,
        method: 'format_validation_fallback',
        note: 'Using format validation only. WhatsApp will verify when messaging.'
      }
    else
      return {
        isRegistered: false,
        phoneNumber: cleaned_number,
        error: 'Invalid phone number format',
        success: false
      }
    end
  end
  
  def self.health_check
    begin
      require 'net/http'
      require 'uri'
      
      # Get service URL using helper method (respects env vars and environment)
      service_url = get_service_url
      full_url = "#{service_url}/health"
      
      uri = URI(full_url)
      http = Net::HTTP.new(uri.host, uri.port)
      if uri.scheme == 'https'
        http.use_ssl = true
        # Disable SSL verification for self-signed certificates (common on VPS)
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http.open_timeout = 10  # Increased timeout for VPS connection
      http.read_timeout = 10  # Increased timeout for VPS connection
      
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

