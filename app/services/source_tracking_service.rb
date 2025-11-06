class SourceTrackingService
  def initialize(request)
    @request = request
    @params = request.params
    @referrer = request.referrer
    @user_agent = request.user_agent
    @ip_address = request.remote_ip
  end

  def track_visit
    # Parse source from URL parameters
    source = parse_source_from_params
    
    # Parse UTM parameters
    utm_params = parse_utm_params
    
    # If no UTM source but source is determined from referrer/click ID,
    # set utm_source to match source for data consistency
    # This ensures External Sources matches UTM Source Distribution
    # EXCEPT for 'other' which shouldn't be in UTM Source Distribution
    final_utm_source = utm_params[:utm_source]
    if final_utm_source.blank? && source.present? && source != 'direct' && source != 'other'
      # Only set utm_source if source is a valid UTM source name
      # Exclude 'other' since it represents unknown referrers, not UTM-tracked traffic
      # This maintains data integrity while ensuring consistency
      final_utm_source = source
    end
    
    # Parse referrer
    referrer = parse_referrer
    
    # Parse device and browser information
    device_info = parse_device_info
    
    # Parse location information (if available)
    location_info = parse_location_info
    
    # Create analytics record with better error handling
    begin
      analytic = Analytic.create!(
        source: source,
        referrer: referrer,
        utm_source: final_utm_source,
        utm_medium: utm_params[:utm_medium],
        utm_campaign: utm_params[:utm_campaign],
        utm_content: utm_params[:utm_content],
        utm_term: utm_params[:utm_term],
        user_agent: @user_agent,
        ip_address: @ip_address,
        data: {
          full_url: @request.url,
          path: @request.path,
          method: @request.method,
          timestamp: Time.current,
          device: device_info,
          location: location_info,
          screen_resolution: @params[:screen_resolution],
          language: @params[:language] || @request.headers['Accept-Language'],
          timezone: @params[:timezone],
          session_duration: @params[:session_duration],
          page_load_time: @params[:page_load_time],
          device_fingerprint: @params[:device_fingerprint],
          session_id: @params[:session_id],
          visitor_id: @params[:visitor_id],
          is_unique_visit: @params[:is_unique_visit] == 'true',
          visit_count: @params[:visit_count],
          # Platform click IDs for SEO and paid ads tracking
          gclid: @params[:gclid], # Google Click ID
          fbclid: @params[:fbclid], # Facebook Click ID
          msclkid: @params[:msclkid] # Microsoft Click ID
        }
      )
      
      Rails.logger.info "Successfully tracked visit from source: #{source}"
      analytic
      
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Validation failed for source tracking: #{e.message}"
      Rails.logger.error "Validation errors: #{e.record.errors.full_messages}"
      Rails.logger.error "Source: #{source}, Referrer: #{referrer}"
      nil
    rescue => e
      Rails.logger.error "Failed to track source: #{e.message}"
      Rails.logger.error "Error details: #{e.backtrace.first(5)}"
      Rails.logger.error "Source: #{source}, Referrer: #{referrer}"
      nil
    end
  end

  private

  def parse_source_from_params
    # Priority 1: UTM source (highest priority - campaign tracking)
    if @params[:utm_source].present?
      source = self.class.sanitize_source(@params[:utm_source])
      return source
    end
    
    # Priority 2: Check for platform click IDs (Google, Facebook, etc.)
    # These indicate paid advertising campaigns from specific platforms
    if @params[:gclid].present?
      return 'google' # Google Ads click
    end
    if @params[:fbclid].present?
      return 'facebook' # Facebook click
    end
    if @params[:msclkid].present?
      return 'microsoft' # Microsoft Ads click
    end
    
    # Priority 3: Check referrer domain and map to proper source
    # This handles organic search, social media, etc.
    referrer_source = parse_referrer_source
    if referrer_source.present?
      return referrer_source
    end
    
    # Default to 'direct' if no source indicators found
    'direct'
  end

  def parse_referrer_source
    return nil unless @referrer.present?
    
    # Extract domain from referrer
    domain = extract_domain(@referrer)
    return nil unless domain.present?
    
    # Skip localhost and development domains
    return nil if development_domain?(domain)
    
    # Map common domains to proper source names
    case domain
    when 'facebook.com', 'm.facebook.com', 'www.facebook.com', 'l.facebook.com'
      'facebook'
    when 'twitter.com', 'x.com', 'mobile.twitter.com', 't.co'
      'twitter'
    when 'instagram.com', 'www.instagram.com'
      'instagram'
    when 'linkedin.com', 'www.linkedin.com'
      'linkedin'
    when 'whatsapp.com', 'web.whatsapp.com', 'wa.me'
      'whatsapp'
    when 'telegram.org', 't.me'
      'telegram'
    when 'google.com', 'www.google.com', 'google.co.ke'
      'google'
    when 'bing.com', 'www.bing.com'
      'bing'
    when 'yahoo.com', 'search.yahoo.com'
      'yahoo'
    when 'youtube.com', 'www.youtube.com', 'm.youtube.com'
      'youtube'
    when 'tiktok.com', 'www.tiktok.com'
      'tiktok'
    when 'snapchat.com'
      'snapchat'
    else
      # For other domains, check if it's a known social platform
      if social_media_domain?(domain)
        extract_social_platform(domain)
      else
        'other'
      end
    end
  end

  def development_domain?(domain)
    development_domains = [
      '127.0.0.1', '0.0.0.0', '::1',
      'carboncube-ke.com', 'www.carboncube-ke.com', # Your own domain
      'carboncube.com', 'www.carboncube.com'
    ]
    development_domains.any? { |dev_domain| domain.include?(dev_domain) }
  end

  def social_media_domain?(domain)
    social_domains = [
      'facebook', 'twitter', 'instagram', 'linkedin', 'whatsapp', 'telegram',
      'youtube', 'tiktok', 'snapchat', 'pinterest', 'reddit', 'discord',
      'slack', 'wechat', 'line', 'viber', 'skype', 'zoom'
    ]
    social_domains.any? { |social| domain.include?(social) }
  end

  def extract_social_platform(domain)
    case domain
    when /facebook/
      'facebook'
    when /twitter|t\.co/
      'twitter'
    when /instagram/
      'instagram'
    when /linkedin/
      'linkedin'
    when /whatsapp|wa\.me/
      'whatsapp'
    when /telegram|t\.me/
      'telegram'
    when /youtube/
      'youtube'
    when /tiktok/
      'tiktok'
    when /snapchat/
      'snapchat'
    when /pinterest/
      'pinterest'
    when /reddit/
      'reddit'
    else
      'other'
    end
  end

  def parse_utm_params
    {
      utm_source: sanitize_utm_param(@params[:utm_source]),
      utm_medium: sanitize_utm_medium(@params[:utm_medium]),
      utm_campaign: sanitize_utm_param(@params[:utm_campaign]),
      utm_content: sanitize_utm_param(@params[:utm_content]),
      utm_term: sanitize_utm_param(@params[:utm_term])
    }
  end

  def sanitize_utm_param(value)
    return nil if value.blank?
    
    # Handle duplicate parameters (e.g., "google,google" or "cpc,cpc")
    # Rails concatenates duplicate params with comma, so we split and take first
    sanitized = value.to_s.split(',').first&.strip
    return nil unless sanitized.present?
    
    # Normalize common source variations for consistency
    # This ensures variations like 'fb', 'face', 'facebbo' become 'facebook' to match source column normalization
    normalized = sanitized.downcase
    case normalized
    when 'fb', 'face', 'facebbo', 'facebook'
      'facebook'
    when 'ig', 'instagram'
      'instagram'
    when 'tw', 'x', 'twitter'
      'twitter'
    when 'li', 'linkedin'
      'linkedin'
    when 'yt', 'youtube'
      'youtube'
    when 'tt', 'tiktok'
      'tiktok'
    when 'sc', 'snapchat'
      'snapchat'
    else
      sanitized
    end
  end

  def sanitize_utm_medium(value)
    return nil if value.blank?
    
    # Handle duplicate parameters
    sanitized = value.to_s.split(',').first&.strip
    return nil unless sanitized.present?
    
    # Normalize UTM medium values: 'social' and 'paid_social' -> 'paid social'
    normalized = sanitized.downcase
    case normalized
    when 'social', 'paid_social', 'paid social'
      'paid social'
    else
      sanitized
    end
  end

  def parse_referrer
    return nil unless @referrer.present?
    
    # Extract domain from referrer
    domain = extract_domain(@referrer)
    
    # Map common domains to readable names
    case domain
    when 'facebook.com', 'm.facebook.com', 'www.facebook.com'
      'Facebook'
    when 'twitter.com', 'x.com', 'mobile.twitter.com'
      'Twitter'
    when 'instagram.com', 'www.instagram.com'
      'Instagram'
    when 'linkedin.com', 'www.linkedin.com'
      'LinkedIn'
    when 'whatsapp.com', 'web.whatsapp.com'
      'WhatsApp'
    when 'telegram.org', 't.me'
      'Telegram'
    when 'google.com', 'www.google.com'
      'Google'
    when 'bing.com', 'www.bing.com'
      'Bing'
    when 'yahoo.com', 'search.yahoo.com'
      'Yahoo'
    else
      domain
    end
  end

  def extract_domain(url)
    return nil unless url.present?
    
    begin
      uri = URI.parse(url)
      uri.host&.downcase
    rescue URI::InvalidURIError
      nil
    end
  end

  def parse_device_info
    return {} unless @user_agent.present?
    
    # Parse user agent to extract device and browser information
    user_agent = @user_agent.downcase
    
    device_info = {
      browser: detect_browser(user_agent),
      browser_version: detect_browser_version(user_agent),
      os: detect_os(user_agent),
      os_version: detect_os_version(user_agent),
      device_type: detect_device_type(user_agent),
      is_mobile: mobile_device?(user_agent),
      is_tablet: tablet_device?(user_agent),
      is_desktop: desktop_device?(user_agent)
    }
    
    device_info
  end

  def parse_location_info
    location_info = {
      ip_address: @ip_address,
      country: nil,
      city: nil,
      region: nil
    }
    
    # For now, we'll just store the IP address
    # In production, you could integrate with a geolocation service like:
    # - MaxMind GeoIP2
    # - IP2Location
    # - ipapi.co
    # - ipinfo.io
    
    location_info
  end

  def detect_browser(user_agent)
    case user_agent
    when /chrome/
      'Chrome'
    when /firefox/
      'Firefox'
    when /safari/
      'Safari'
    when /edge/
      'Edge'
    when /opera/
      'Opera'
    when /ie|trident/
      'Internet Explorer'
    else
      'Unknown'
    end
  end

  def detect_browser_version(user_agent)
    # Extract version number from user agent
    version_match = user_agent.match(/(chrome|firefox|safari|edge|opera)\/(\d+)/i)
    version_match ? version_match[2] : nil
  end

  def detect_os(user_agent)
    case user_agent
    when /windows/
      'Windows'
    when /mac os x/
      'macOS'
    when /android/
      'Android'
    when /iphone|ipad|ipod/
      'iOS'
    when /linux/
      'Linux'
    else
      'Unknown'
    end
  end

  def detect_os_version(user_agent)
    # Extract OS version
    case user_agent
    when /windows nt (\d+\.\d+)/
      "Windows #{$1}"
    when /mac os x (\d+[._]\d+[._]\d+)/
      "macOS #{$1.gsub('_', '.')}"
    when /android (\d+\.\d+)/
      "Android #{$1}"
    when /iphone os (\d+[._]\d+[._]\d+)/
      "iOS #{$1.gsub('_', '.')}"
    else
      nil
    end
  end

  def detect_device_type(user_agent)
    if mobile_device?(user_agent)
      'Mobile'
    elsif tablet_device?(user_agent)
      'Tablet'
    elsif desktop_device?(user_agent)
      'Desktop'
    else
      'Unknown'
    end
  end

  def mobile_device?(user_agent)
    user_agent.match?(/mobile|android.*mobile|iphone|ipod|blackberry|windows phone/i)
  end

  def tablet_device?(user_agent)
    user_agent.match?(/ipad|android(?!.*mobile)|tablet/i)
  end

  def desktop_device?(user_agent)
    !mobile_device?(user_agent) && !tablet_device?(user_agent)
  end

  def self.sanitize_source(source)
    return 'direct' unless source.present?
    
    # Handle duplicate parameters (e.g., "google,google")
    # Rails concatenates duplicate params with comma, so we split and take first
    source_value = source.to_s.split(',').first&.strip
    return 'direct' unless source_value.present?
    
    # Sanitize and normalize source names
    sanitized = source_value.downcase
    
    result = case sanitized
    when 'fb', 'face', 'facebbo', 'facebook'
      'facebook'
    when 'ig', 'instagram'
      'instagram'
    when 'tw', 'twitter', 'x'
      'twitter'
    when 'wa', 'whatsapp'
      'whatsapp'
    when 'tg', 'telegram'
      'telegram'
    when 'li', 'linkedin'
      'linkedin'
    when 'yt', 'youtube'
      'youtube'
    when 'tt', 'tiktok'
      'tiktok'
    when 'sc', 'snapchat'
      'snapchat'
    when 'pin', 'pinterest'
      'pinterest'
    when 'reddit', 'rd'
      'reddit'
    when 'google', 'g'
      'google'
    when 'bing', 'b'
      'bing'
    when 'yahoo', 'y'
      'yahoo'
    when '127.0.0.1', 'carboncube-ke.com', 'carboncube.com'
      'direct'
    else
      sanitized
    end
    
    result
  end
end
