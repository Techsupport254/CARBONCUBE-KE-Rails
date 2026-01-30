class SourceTrackingService
  # Rails ParamsWrapper may nest JSON body under controller name (e.g. :source_tracking).
  # We read from both root and wrapped params so all UTM params are captured.
  WRAPPER_KEY = :source_tracking

  def initialize(request)
    @request = request
    @params = request.params
    @referrer = request.referrer
    @user_agent = request.user_agent
    @ip_address = request.remote_ip
  end

  # Get param from root or from wrapped hash (Rails ParamsWrapper)
  def param_value(key)
    val = @params[key].presence
    val = @params.dig(WRAPPER_KEY, key) if val.blank? && @params[WRAPPER_KEY].present?
    val
  end

  def track_visit
    # Check for duplicate session tracking - only track once per session
    session_id = param_value(:session_id)
    if session_id.present?
      # Check if this session_id has already been tracked
      existing_tracking = Analytic.where("data->>'session_id' = ?", session_id)
                                   .where('created_at >= ?', 1.hour.ago) # Only check recent records
                                   .first
      
      if existing_tracking
        Rails.logger.info "Session #{session_id} already tracked, skipping duplicate"
        return existing_tracking
      end
    end
    
    # Parse source from URL parameters
    source = parse_source_from_params
    
    # Get the actual page URL early (needed for UTM fallback from URL)
    actual_page_url = param_value(:url).presence || @request.url
    actual_page_path = param_value(:path).presence || @request.path

    # Parse UTM parameters (reads from root and wrapped params)
    utm_params = parse_utm_params(actual_page_url)

    # Fill in utm_content/utm_term from URL if missing from params (e.g. ParamsWrapper or truncated client URL)
    utm_params = merge_utm_from_url(utm_params, actual_page_url)

    # If no UTM source but source is determined from referrer/click ID,
    # set utm_source to match source for data consistency
    # This ensures External Sources matches UTM Source Distribution
    # EXCEPT for 'direct' and 'other' which shouldn't be in UTM Source Distribution
    final_utm_source = utm_params[:utm_source]
    if final_utm_source.blank? && source.present? && source != 'direct' && source != 'other'
      # Only set utm_source if source is a valid UTM source name
      # Exclude 'direct' and 'other' since they represent traffic classifications, not UTM-tracked traffic
      # This maintains data integrity while ensuring consistency
      final_utm_source = source
    end
    
    # Ensure utm_source is never 'direct' or 'other' (these are invalid UTM values)
    # If somehow we get these values, set to nil
    final_utm_source = nil if final_utm_source.present? && (final_utm_source.downcase == 'direct' || final_utm_source.downcase == 'other')
    
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
          full_url: actual_page_url, # Use actual page URL from frontend, not tracking endpoint
          path: actual_page_path, # Use actual page path from frontend
          method: @request.method,
          timestamp: Time.current,
          device: device_info,
          location: location_info,
          screen_resolution: param_value(:screen_resolution),
          language: param_value(:language).presence || @request.headers['Accept-Language'],
          timezone: param_value(:timezone),
          session_duration: param_value(:session_duration),
          page_load_time: param_value(:page_load_time),
          device_fingerprint: param_value(:device_fingerprint),
          session_id: param_value(:session_id),
          visitor_id: param_value(:visitor_id),
          is_unique_visit: param_value(:is_unique_visit) == 'true',
          visit_count: param_value(:visit_count),
          # Platform click IDs for SEO and paid ads tracking
          gclid: param_value(:gclid), # Google Click ID
          fbclid: param_value(:fbclid), # Facebook Click ID
          msclkid: param_value(:msclkid) # Microsoft Click ID
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
    utm_source = param_value(:utm_source)
    if utm_source.present?
      source = self.class.sanitize_source(utm_source)
      return source
    end

    # Priority 2: Check for platform click IDs (Google, Facebook, etc.)
    # These indicate paid advertising campaigns from specific platforms
    if param_value(:gclid).present?
      return 'google' # Google Ads click
    end
    if param_value(:fbclid).present?
      return 'facebook' # Facebook click
    end
    if param_value(:msclkid).present?
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

  def parse_utm_params(_page_url = nil)
    {
      utm_source: sanitize_utm_param(param_value(:utm_source)),
      utm_medium: sanitize_utm_medium(param_value(:utm_medium)),
      utm_campaign: sanitize_utm_param(param_value(:utm_campaign)),
      utm_content: sanitize_utm_param(param_value(:utm_content)),
      utm_term: sanitize_utm_param(param_value(:utm_term))
    }
  end

  # When utm_content or utm_term are missing (e.g. ParamsWrapper or truncated URL), parse from page URL
  def merge_utm_from_url(utm_params, page_url)
    return utm_params if page_url.blank?

    begin
      uri = URI.parse(page_url)
      query = uri.query
      return utm_params if query.blank?

      parsed = URI.decode_www_form(query).to_h
      result = utm_params.dup
      result[:utm_content] = sanitize_utm_param(parsed['utm_content']) if result[:utm_content].blank? && parsed['utm_content'].present?
      result[:utm_term] = sanitize_utm_param(parsed['utm_term']) if result[:utm_term].blank? && parsed['utm_term'].present?
      result
    rescue URI::InvalidURIError, ArgumentError
      utm_params
    end
  end

  def sanitize_utm_param(value)
    return nil if value.blank?
    
    # Handle duplicate parameters (e.g., "google,google" or "cpc,cpc")
    # Rails concatenates duplicate params with comma, so we split and take first
    sanitized = value.to_s.split(',').first&.strip
    return nil unless sanitized.present?
    
    # Reject invalid UTM source values
    # 'direct' and 'other' are not valid UTM sources - they are source classifications, not UTM parameters
    normalized = sanitized.downcase
    return nil if normalized == 'direct' || normalized == 'other'
    
    # Reject invalid UTM source values that are actions, not sources
    # 'copy' is not a traffic source - it's an action (copying a link)
    return nil if normalized == 'copy'
    
    # Reject 'social_media' - this is a medium, not a source
    # People incorrectly use utm_source=social_media when they should use utm_source=facebook&utm_medium=social
    return nil if normalized == 'social_media' || normalized == 'social-media'
    
    # Normalize common source variations for consistency
    # This ensures variations like 'fb', 'face', 'facebbo' become 'facebook' to match source column normalization
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
    
    # Normalize UTM medium values
    # 'social' = unpaid/organic social media (keep as is)
    # 'paid_social' or 'paid social' = paid social media ads (normalize to 'paid social')
    normalized = sanitized.downcase
    case normalized
    when 'paid_social', 'paid social'
      'paid social'
    when 'social'
      'social' # Keep unpaid/organic social as 'social'
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
    
    # Try using user_agent_parser gem first for better detection
    device_info = {}
    
    begin
      require 'user_agent_parser'
      parser = UserAgentParser.parse(@user_agent)
      
      # Extract browser information
      browser_name = parser.family
      browser_version = parser.version&.to_s
      
      # Extract OS information
      os_family = parser.os&.family
      os_version = parser.os&.version&.to_s
      
      # Normalize browser names
      browser = normalize_browser_name(browser_name)
      
      # Normalize OS names
      os = normalize_os_name(os_family)
      
      # Detect device type
      user_agent_lower = @user_agent.downcase
      device_type = detect_device_type(user_agent_lower)
      
      device_info = {
        browser: browser || 'Unknown',
        browser_version: browser_version,
        os: os || 'Unknown',
        os_version: os_version,
        device_type: device_type,
        is_mobile: mobile_device?(user_agent_lower),
        is_tablet: tablet_device?(user_agent_lower),
        is_desktop: desktop_device?(user_agent_lower)
      }
    rescue LoadError, StandardError => e
      # Fallback to regex-based detection if gem is not available or fails
      Rails.logger.warn "User agent parser failed, using fallback: #{e.message}"
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
    end
    
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

  def normalize_browser_name(browser_name)
    return 'Unknown' unless browser_name.present?
    
    browser_lower = browser_name.downcase
    case browser_lower
    when /chrome|crios/
      'Chrome'
    when /firefox|fxios/
      'Firefox'
    when /safari|mobile safari/
      'Safari'
    when /edge|edgios|edg/
      'Edge'
    when /opera|opr|opios/
      'Opera'
    when /ie|trident|msie/
      'Internet Explorer'
    when /samsungbrowser|samsung internet/
      'Samsung Internet'
    when /ucbrowser|uc browser/
      'UC Browser'
    when /yandex|yabrowser/
      'Yandex Browser'
    when /brave/
      'Brave'
    when /vivaldi/
      'Vivaldi'
    else
      browser_name # Return original if not recognized
    end
  end

  def detect_browser(user_agent)
    case user_agent
    when /chrome|crios|chromium/i
      'Chrome'
    when /firefox|fxios/i
      'Firefox'
    when /safari/i
      # Make sure it's not Chrome (Chrome includes Safari in UA)
      user_agent.include?('chrome') ? 'Chrome' : 'Safari'
    when /edge|edgios|edg/i
      'Edge'
    when /opera|opr|opios/i
      'Opera'
    when /ie|trident|msie/i
      'Internet Explorer'
    when /samsungbrowser|samsung internet/i
      'Samsung Internet'
    when /ucbrowser|uc browser/i
      'UC Browser'
    when /yandex|yabrowser/i
      'Yandex Browser'
    when /brave/i
      'Brave'
    when /vivaldi/i
      'Vivaldi'
    else
      'Unknown'
    end
  end

  def detect_browser_version(user_agent)
    # Extract version number from user agent
    version_match = user_agent.match(/(chrome|firefox|safari|edge|opera)\/(\d+)/i)
    version_match ? version_match[2] : nil
  end

  def normalize_os_name(os_name)
    return 'Unknown' unless os_name.present?
    
    os_lower = os_name.downcase
    case os_lower
    when /windows/
      'Windows'
    when /mac|macos|darwin/
      'macOS'
    when /android/
      'Android'
    when /ios|iphone os|ipad os/
      'iOS'
    when /linux/
      'Linux'
    when /ubuntu/
      'Linux'
    when /fedora/
      'Linux'
    when /debian/
      'Linux'
    when /centos/
      'Linux'
    else
      os_name # Return original if not recognized
    end
  end

  def detect_os(user_agent)
    case user_agent
    when /windows nt|win32|win64|windows phone|windows mobile/i
      'Windows'
    when /mac os x|macintosh|darwin/i
      'macOS'
    when /android/i
      'Android'
    when /iphone os|ipad os|ipod|ios/i
      'iOS'
    when /linux|ubuntu|fedora|debian|centos/i
      'Linux'
    when /cros/i
      'Chrome OS'
    when /blackberry/i
      'BlackBerry'
    when /symbian/i
      'Symbian'
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
    # More comprehensive device type detection
    if mobile_device?(user_agent)
      'Phone'
    elsif tablet_device?(user_agent)
      'Tablet'
    elsif desktop_device?(user_agent)
      'Desktop'
    else
      'Unknown'
    end
  end

  def mobile_device?(user_agent)
    # Enhanced mobile detection patterns
    user_agent.match?(/mobile|android.*mobile|iphone|ipod|blackberry|windows phone|windows mobile|iemobile|mobile safari|fennec|opera mini|opera mobi|ucweb|ucbrowser|samsung.*mobile|huawei.*mobile|xiaomi.*mobile|oppo|vivo|oneplus|realme|redmi/i)
  end

  def tablet_device?(user_agent)
    # Enhanced tablet detection - must check before mobile since tablets often include "mobile" in UA
    user_agent.match?(/ipad|android(?!.*mobile)|tablet|playbook|kindle|silk|gt-p|gt-n|sm-t|nexus.*tablet|xoom|sch-i800|a100|a101|a200|a210|a211|a500|a501|a510|a511|a700|a701|b9700|b9710|b9730|b9740|b9750|b9760|b9770|b9780|b9790|b9800|b9810|b9820|b9830|b9840|b9850|b9860|b9870|b9880|b9890|b9900|b9910|b9920|b9930|b9940|b9950|b9960|b9970|b9980|b9990/i)
  end

  def desktop_device?(user_agent)
    # Desktop if not mobile and not tablet
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
