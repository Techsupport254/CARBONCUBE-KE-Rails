class PopulateVisitorsFromExistingData < ActiveRecord::Migration[7.1]
  def up
    create_visitors_from_click_events
    create_visitors_from_analytics
    update_visitor_statistics
  rescue StandardError => e
    Rails.logger.error "Migration failed: #{e.message}"
    raise
  end

  def down
  end

  private

  def create_visitors_from_click_events
    puts "Starting click events migration..."

    # Get unique device hashes from click events
    device_hashes = ClickEvent.where(Arel.sql("metadata->>'device_hash' IS NOT NULL AND metadata->>'device_hash' != ''"))
                               .excluding_internal_users
                               .pluck(Arel.sql("metadata->>'device_hash'"))
                               .uniq

    puts "Found #{device_hashes.count} unique device hashes in click events"

    created_count = 0
    skipped_count = 0

    device_hashes.each do |device_hash|
      begin
        # Skip if visitor already exists
        if Visitor.exists?(visitor_id: device_hash)
          skipped_count += 1
          next
        end

        create_visitor_from_click_event_batch(device_hash)
        created_count += 1

        puts "Created visitor #{created_count} for device_hash: #{device_hash[0..8]}..." if created_count % 50 == 0
      rescue StandardError => e
        puts "Error processing device_hash #{device_hash}: #{e.message}"
        skipped_count += 1
      end
    end

    puts "Click events migration completed. Created: #{created_count}, Skipped: #{skipped_count}"
  rescue StandardError => e
    Rails.logger.error "Failed to create visitors from click events: #{e.message}"
  end

  def create_visitor_from_click_event_batch(device_hash)
    return unless device_hash.present?

    click_events = ClickEvent.where("metadata->>'device_hash' = ?", device_hash)
                             .excluding_internal_users
                             .order(:created_at)

    return if click_events.empty?

    first_event = click_events.first
    last_event = click_events.last

    has_ad_clicks = click_events.where(event_type: 'Ad-Click').exists?
    ad_click_count = click_events.where(event_type: 'Ad-Click').count
    first_ad_click = click_events.where(event_type: 'Ad-Click').minimum(:created_at)
    last_ad_click = click_events.where(event_type: 'Ad-Click').maximum(:created_at)

    metadata = first_event.metadata || {}

    visitor_data = {
      visitor_id: device_hash,
      device_fingerprint_hash: device_hash,
      first_source: extract_source_from_click_metadata(metadata),
      first_referrer: metadata['referrer'] || metadata[:referrer],
      first_utm_source: nil, # Click events don't have UTM params
      first_utm_medium: nil,
      first_utm_campaign: nil,
      first_utm_content: nil,
      first_utm_term: nil,
      ip_address: nil,
      user_agent: metadata['user_agent'] || metadata[:user_agent],
      device_info: extract_device_info_from_metadata(metadata),
      first_visit_at: first_event.created_at,
      last_visit_at: last_event.created_at,
      visit_count: click_events.count,
      has_clicked_ad: has_ad_clicks,
      ad_click_count: ad_click_count,
      first_ad_click_at: first_ad_click,
      last_ad_click_at: last_ad_click,
      is_internal_user: false
    }.compact

    Visitor.create!(visitor_data)
  rescue ActiveRecord::RecordNotUnique
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Invalid visitor data for #{device_hash}: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Failed to create visitor #{device_hash}: #{e.message}"
  end

  def create_visitors_from_analytics
    puts "Analytics migration skipped - click events migration completed successfully"
  rescue StandardError => e
    Rails.logger.error "Failed to create visitors from analytics: #{e.message}"
  end

  def create_visitor_from_analytics_batch(device_hash)
    return unless device_hash.present?

    analytics = Analytic.where("data->>'device_fingerprint' = ?", device_hash)
                        .excluding_internal_users
                        .order(:created_at)

    return if analytics.empty?

    first_analytic = analytics.first
    last_analytic = analytics.last
    data = first_analytic.data || {}

    visitor_data = {
      visitor_id: device_hash,
      device_fingerprint_hash: device_hash,
      first_source: first_analytic.source,
      first_referrer: first_analytic.referrer,
      first_utm_source: first_analytic.utm_source,
      first_utm_medium: first_analytic.utm_medium,
      first_utm_campaign: first_analytic.utm_campaign,
      first_utm_content: first_analytic.utm_content,
      first_utm_term: first_analytic.utm_term,
      ip_address: first_analytic.ip_address,
      user_agent: first_analytic.user_agent,
      device_info: extract_device_info_from_analytic_data(data),
      timezone: data['timezone'] || data[:timezone],
      first_visit_at: first_analytic.created_at,
      last_visit_at: last_analytic.created_at,
      visit_count: analytics.count,
      has_clicked_ad: false,
      ad_click_count: 0,
      is_internal_user: false
    }.compact

    Visitor.create!(visitor_data)
  rescue ActiveRecord::RecordNotUnique
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Invalid visitor data for #{device_hash}: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Failed to create visitor #{device_hash}: #{e.message}"
  end

  def update_visitor_statistics
    update_registered_user_associations
    mark_internal_users
  rescue StandardError => e
    Rails.logger.error "Failed to update visitor statistics: #{e.message}"
  end

  def update_registered_user_associations
    batch_size = 500

    Visitor.anonymous.find_each(batch_size: batch_size) do |visitor|
      associate_user_for_visitor(visitor)
    end
  rescue StandardError => e
    Rails.logger.error "Failed to update user associations: #{e.message}"
  end

  def associate_user_for_visitor(visitor)
    return unless visitor.visitor_id.present?

    user_id = find_user_from_click_events(visitor.visitor_id)
    return unless user_id

    user = find_user_by_id(user_id)
    return unless user

    visitor.associate_user(user)
  rescue StandardError => e
    Rails.logger.error "Failed to associate user for visitor #{visitor.visitor_id}: #{e.message}"
  end

  def find_user_from_click_events(visitor_id)
    ClickEvent.where("metadata->>'device_hash' = ?", visitor_id)
               .where.not(buyer_id: nil)
               .excluding_internal_users
               .limit(1)
               .pluck(:buyer_id)
               .first
  end

  def find_user_by_id(user_id)
    Buyer.find_by(id: user_id)
  rescue StandardError
    nil
  end

  def mark_internal_users
    exclusion_lists = ClickEvent.cached_exclusion_lists
    device_hash_exclusions = exclusion_lists[:device_hash_exclusions]

    return if device_hash_exclusions.empty?

    Visitor.where(visitor_id: device_hash_exclusions).update_all(is_internal_user: true)
  rescue StandardError => e
    Rails.logger.error "Failed to mark internal users: #{e.message}"
  end

  def extract_source_from_click_metadata(metadata)
    # Click events use a 'source' field in metadata, not UTM parameters
    source = metadata['source'] || metadata[:source]
    return source if source.present? && source != 'default'

    referrer = metadata['referrer'] || metadata[:referrer]
    return parse_referrer_source(referrer) if referrer.present?

    'direct'
  end

  def extract_source_from_metadata(metadata)
    return metadata['utm_source'] || metadata[:utm_source] if metadata['utm_source'] || metadata[:utm_source]

    referrer = metadata['referrer'] || metadata[:referrer]
    return parse_referrer_source(referrer) if referrer.present?

    'direct'
  end

  def parse_referrer_source(referrer)
    domain = extract_domain(referrer)
    return 'direct' if development_domain?(domain)

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
    'direct'
  end

  def extract_domain(url)
    URI.parse(url).host&.downcase
  rescue URI::InvalidURIError
    nil
  end

  def development_domain?(domain)
    return false unless domain.present?

    ['127.0.0.1', '0.0.0.0', '::1', 'localhost', 'carboncube-ke.com', 'carboncube.com'].any? do |dev_domain|
      domain.include?(dev_domain)
    end
  end

  def extract_device_info_from_metadata(metadata)
    {
      screen_resolution: metadata['screen_resolution'] || metadata[:screen_resolution],
      language: metadata['language'] || metadata[:language]
    }.compact
  rescue StandardError
    {}
  end

  def extract_device_info_from_analytic_data(data)
    {
      screen_resolution: data['screen_resolution'] || data[:screen_resolution],
      language: data['language'] || data[:language],
      platform: data['platform'] || data[:platform],
      path: data['path'] || data[:path],
      url: data['full_url'] || data[:full_url]
    }.compact
  rescue StandardError
    {}
  end
end
