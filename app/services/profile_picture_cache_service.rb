class ProfilePictureCacheService
  include Rails.application.routes.url_helpers

  def initialize
    @cache_dir = Rails.root.join('public', 'cached_profile_pictures')
    ensure_cache_directory_exists
  end

  # Download and cache a Google profile picture
  def cache_google_profile_picture(google_url, user_id)
    return nil if google_url.blank?

    # Generate a unique filename for this user
    filename = "user_#{user_id}_#{Time.current.to_i}.jpg"
    file_path = @cache_dir.join(filename)

    begin
      # Download the image from Google
      Rails.logger.info "🔄 Downloading profile picture from Google: #{google_url}"
      Rails.logger.info "🔄 Cache directory: #{@cache_dir}"
      Rails.logger.info "🔄 Target file path: #{file_path}"
      
      # Use Net::HTTP to download the image with proper SSL handling
      uri = URI(google_url)
      http = Net::HTTP.new(uri.host, uri.port)
      
      # Configure SSL
      if uri.scheme == 'https'
        http.use_ssl = true
        
        # In development, skip SSL verification to avoid certificate issues
        # This is safe for development but should never be used in production
        if Rails.env.development?
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        else
          # Production: always verify SSL
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          # Try to use system certificate store if available
          if File.exist?(OpenSSL::X509::DEFAULT_CERT_FILE)
            http.ca_file = OpenSSL::X509::DEFAULT_CERT_FILE
          elsif Dir.exist?(OpenSSL::X509::DEFAULT_CERT_DIR)
            http.ca_path = OpenSSL::X509::DEFAULT_CERT_DIR
          end
        end
      end
      
      # Set timeout
      http.open_timeout = 10
      http.read_timeout = 10
      
      request = Net::HTTP::Get.new(uri.request_uri)
      request['User-Agent'] = 'Mozilla/5.0 (compatible; CarbonApp/1.0)'
      
      response = http.request(request)
      
      Rails.logger.info "🔄 Response code: #{response.code}"
      
      if response.code == '200'
        # Save the image to our cache directory
        File.open(file_path, 'wb') do |file|
          file.write(response.body)
        end
        
        Rails.logger.info "✅ Profile picture cached successfully: #{filename}"
        Rails.logger.info "✅ File exists: #{File.exist?(file_path)}"
        Rails.logger.info "✅ File size: #{File.size(file_path)} bytes"
        
        # Return the URL to the cached image
        "/cached_profile_pictures/#{filename}"
      else
        Rails.logger.error "❌ Failed to download profile picture: #{response.code} - #{response.message}"
        nil
      end
    rescue OpenSSL::SSL::SSLError => e
      Rails.logger.error "❌ SSL error caching profile picture: #{e.message}"
      Rails.logger.error "💡 Tip: Try running 'brew install ca-certificates' or update Ruby certificates"
      # Return nil so we can fall back to original URL
      nil
    rescue => e
      Rails.logger.error "❌ Error caching profile picture: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.first(5).join('\n')}"
      nil
    end
  end

  # Get cached profile picture URL or cache a new one
  def get_or_cache_profile_picture(google_url, user_id)
    return nil if google_url.blank?

    # Check if we already have a cached version for this user
    existing_files = Dir.glob(@cache_dir.join("user_#{user_id}_*.jpg"))
    
    if existing_files.any?
      # Return the most recent cached version
      latest_file = existing_files.max_by { |f| File.mtime(f) }
      filename = File.basename(latest_file)
      return "/cached_profile_pictures/#{filename}"
    end

    # No cached version exists, download and cache it
    cache_google_profile_picture(google_url, user_id)
  end

  # Clean up old cached images (optional maintenance method)
  def cleanup_old_cache_files(days_old = 30)
    cutoff_time = days_old.days.ago
    
    Dir.glob(@cache_dir.join("*.jpg")).each do |file|
      if File.mtime(file) < cutoff_time
        File.delete(file)
        Rails.logger.info "🗑️ Cleaned up old cached profile picture: #{File.basename(file)}"
      end
    end
  end

  private

  def ensure_cache_directory_exists
    FileUtils.mkdir_p(@cache_dir) unless Dir.exist?(@cache_dir)
  end
end
