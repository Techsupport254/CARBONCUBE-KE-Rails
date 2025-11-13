class VisitorTrackingService
  def initialize(request)
    @request = request
    @params = request.params
  end

  def track_visitor
    visitor_id = extract_visitor_id
    return nil unless visitor_id.present?

    return nil if internal_user_excluded?

    visitor = Visitor.find_or_create_visitor(visitor_id, visitor_attributes)
    return nil unless visitor

    visitor.update_visit!(visit_attributes)
    visitor
  rescue StandardError => e
    Rails.logger.error "Visitor tracking failed for #{visitor_id}: #{e.message}"
    nil
  end

  def record_ad_click(visitor_id, ad_data = {})
    return false unless visitor_id.present?

    visitor = Visitor.find_by(visitor_id: visitor_id)
    return false unless visitor

    visitor.record_ad_click!(ad_data)
  rescue StandardError => e
    Rails.logger.error "Ad click tracking failed for visitor #{visitor_id}: #{e.message}"
    false
  end

  def associate_user_with_visitor(user, visitor_id)
    return false unless user && visitor_id.present?

    visitor = Visitor.find_by(visitor_id: visitor_id)
    return false unless visitor

    visitor.associate_user(user)
  rescue StandardError => e
    Rails.logger.error "User association failed for visitor #{visitor_id}: #{e.message}"
    false
  end

  private

  def extract_visitor_id
    @params[:visitor_id].presence ||
    @params[:device_fingerprint].presence ||
    generate_fallback_id
  end

  def generate_fallback_id
    return nil unless @request.user_agent.present?

    Digest::SHA256.hexdigest(@request.user_agent + @request.remote_ip)[0..31]
  rescue StandardError
    nil
  end

  def visitor_attributes
    {
      device_fingerprint_hash: @params[:device_fingerprint],
      first_source: determine_source,
      first_referrer: safe_referrer,
      first_utm_source: sanitize_utm_param(@params[:utm_source]),
      first_utm_medium: sanitize_utm_param(@params[:utm_medium]),
      first_utm_campaign: sanitize_utm_param(@params[:utm_campaign]),
      first_utm_content: sanitize_utm_param(@params[:utm_content]),
      first_utm_term: sanitize_utm_param(@params[:utm_term]),
      ip_address: safe_ip_address,
      user_agent: safe_user_agent,
      device_info: extract_device_info,
      timezone: sanitize_param(@params[:timezone]),
      first_visit_at: Time.current,
      last_visit_at: Time.current
    }.compact
  end

  def visit_attributes
    {
      ip_address: safe_ip_address,
      timezone: sanitize_param(@params[:timezone])
    }.compact
  end

  def determine_source
    return sanitize_utm_param(@params[:utm_source]) if @params[:utm_source].present?

    return 'google' if @params[:gclid].present?
    return 'facebook' if @params[:fbclid].present?
    return 'microsoft' if @params[:msclkid].present?

    parse_referrer_source || 'direct'
  end

  def parse_referrer_source
    return nil unless safe_referrer.present?

    domain = extract_domain(safe_referrer)
    return nil unless domain.present?

    return nil if development_domain?(domain)

    case domain
    when /facebook\.com/ then 'facebook'
    when /twitter\.com|x\.com/ then 'twitter'
    when /instagram\.com/ then 'instagram'
    when /linkedin\.com/ then 'linkedin'
    when /google\.com/ then 'google'
    when /bing\.com/ then 'bing'
    when /yahoo\.com/ then 'yahoo'
    else 'other'
    end
  rescue StandardError
    nil
  end

  def extract_domain(url)
    return nil unless url.present?

    begin
      URI.parse(url).host&.downcase
    rescue URI::InvalidURIError
      nil
    end
  end

  def development_domain?(domain)
    return false unless domain.present?

    ['127.0.0.1', '0.0.0.0', '::1', 'localhost', 'carboncube-ke.com', 'carboncube.com'].any? do |dev_domain|
      domain.include?(dev_domain)
    end
  end

  def safe_referrer
    @request.referrer.presence
  rescue StandardError
    nil
  end

  def safe_ip_address
    @request.remote_ip.presence
  rescue StandardError
    nil
  end

  def safe_user_agent
    @request.user_agent.presence
  rescue StandardError
    nil
  end

  def extract_device_info
    {
      screen_resolution: sanitize_param(@params[:screen_resolution]),
      language: sanitize_param(@params[:language]) || safe_accept_language,
      platform: sanitize_param(@params[:platform]),
      path: sanitize_param(@params[:path]),
      url: sanitize_param(@params[:url])
    }.compact
  rescue StandardError
    {}
  end

  def safe_accept_language
    @request.headers['Accept-Language'].presence
  rescue StandardError
    nil
  end

  def sanitize_utm_param(value)
    return nil unless value.present?

    sanitized = value.to_s.split(',').first&.strip
    return nil unless sanitized.present?

    normalized = sanitized.downcase
    return nil if normalized == 'direct' || normalized == 'other'

    sanitized
  end

  def sanitize_param(value)
    return nil unless value.present?

    value.to_s.strip.presence
  rescue StandardError
    nil
  end

  def internal_user_excluded?
    device_hash = extract_visitor_id
    user_agent = safe_user_agent
    ip_address = safe_ip_address

    InternalUserExclusion.should_exclude?(
      device_hash: device_hash,
      user_agent: user_agent,
      ip_address: ip_address
    )
  rescue StandardError => e
    Rails.logger.error "Internal user check failed: #{e.message}"
    false
  end
end
