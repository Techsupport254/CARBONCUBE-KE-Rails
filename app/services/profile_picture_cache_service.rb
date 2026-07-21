class ProfilePictureCacheService
  include Rails.application.routes.url_helpers

  def initialize
    @cache_dir = Rails.root.join('public', 'cached_profile_pictures')
    ensure_cache_directory_exists
  end

  def cache_google_profile_picture(google_url, user_id)
    return nil if google_url.blank?

    filename = "user_#{user_id}_#{Time.current.to_i}.jpg"
    file_path = @cache_dir.join(filename)

    begin
      uri = URI(google_url)
      http = Net::HTTP.new(uri.host, uri.port)
      
      if uri.scheme == 'https'
        http.use_ssl = true
        
        if Rails.env.development?
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        else
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          if File.exist?(OpenSSL::X509::DEFAULT_CERT_FILE)
            http.ca_file = OpenSSL::X509::DEFAULT_CERT_FILE
          elsif Dir.exist?(OpenSSL::X509::DEFAULT_CERT_DIR)
            http.ca_path = OpenSSL::X509::DEFAULT_CERT_DIR
          end
        end
      end
      
      http.open_timeout = 10
      http.read_timeout = 10
      
      request = Net::HTTP::Get.new(uri.request_uri)
      request['User-Agent'] = 'Mozilla/5.0 (compatible; CarbonApp/1.0)'
      
      response = http.request(request)
      
      if response.code == '200'
        File.open(file_path, 'wb') do |file|
          file.write(response.body)
        end
        
        "/cached_profile_pictures/#{filename}"
      else
        Rails.logger.error "Failed to download profile picture: #{response.code} - #{response.message}"
        nil
      end
    rescue OpenSSL::SSL::SSLError => e
      Rails.logger.error "SSL error caching profile picture: #{e.message}"
      nil
    rescue => e
      Rails.logger.error "Error caching profile picture: #{e.message}"
      nil
    end
  end

  def get_or_cache_profile_picture(google_url, user_id)
    return nil if google_url.blank?

    existing_files = Dir.glob(@cache_dir.join("user_#{user_id}_*.jpg"))
    
    if existing_files.any?
      latest_file = existing_files.max_by { |f| File.mtime(f) }
      filename = File.basename(latest_file)
      return "/cached_profile_pictures/#{filename}"
    end

    cache_google_profile_picture(google_url, user_id)
  end

  def cleanup_old_cache_files(days_old = 30)
    cutoff_time = days_old.days.ago
    
    Dir.glob(@cache_dir.join("*.jpg")).each do |file|
      if File.mtime(file) < cutoff_time
        File.delete(file)
      end
    end
  end

  private

  def ensure_cache_directory_exists
    FileUtils.mkdir_p(@cache_dir) unless Dir.exist?(@cache_dir)
    FileUtils.chmod(0755, @cache_dir) if Dir.exist?(@cache_dir)
  end
end
