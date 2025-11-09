class ClickEventsAnalyticsService
  attr_reader :base_query, :filters

  def initialize(filters: {})
    @filters = filters || {}
    @base_query = build_base_query
  end

  # Main method to get all click events analytics
  def analytics
    {
      # Totals
      totals: totals,
      
      # Timestamps for frontend filtering
      timestamps: timestamps,
      
      # Breakdowns
      breakdowns: breakdowns,
      
      # Top performing ads
      top_ads: top_ads_by_reveals,
      
      # Recent click events (paginated)
      recent_events: recent_click_events,
      
      # Trends (for seller-specific analytics)
      trends: click_event_trends,
      
      # Demographics (for seller-specific analytics)
      demographics: demographics_stats
    }
  end

  # Get totals
  def totals
    {
      total_click_events: base_query.count,
      total_reveal_events: base_query.where(event_type: 'Reveal-Seller-Details').count,
      total_ad_clicks: base_query.where(event_type: 'Ad-Click').count,
      guest_reveals: base_query.where(event_type: 'Reveal-Seller-Details', buyer_id: nil).count,
      authenticated_reveals: base_query.where(event_type: 'Reveal-Seller-Details').where.not(buyer_id: nil).count,
      conversion_count: conversion_events.count,
      conversion_rate: calculate_conversion_rate,
      post_login_reveal_count: post_login_reveals.count,
      guest_login_attempt_count: guest_login_attempts.count
    }
  end

  # Get timestamps for frontend filtering
  def timestamps
    {
      click_events_timestamps: base_query.pluck(:created_at).map { |ts| ts&.iso8601 },
      reveal_events_timestamps: base_query.where(event_type: 'Reveal-Seller-Details').pluck(:created_at).map { |ts| ts&.iso8601 },
      ad_clicks_timestamps: base_query.where(event_type: 'Ad-Click').pluck(:created_at).map { |ts| ts&.iso8601 },
      guest_reveal_timestamps: base_query.where(event_type: 'Reveal-Seller-Details', buyer_id: nil).pluck(:created_at).map { |ts| ts&.iso8601 },
      authenticated_reveal_timestamps: base_query.where(event_type: 'Reveal-Seller-Details').where.not(buyer_id: nil).pluck(:created_at).map { |ts| ts&.iso8601 },
      conversion_timestamps: conversion_events.pluck(:created_at).map { |ts| ts&.iso8601 },
      post_login_reveal_timestamps: post_login_reveals.pluck(:created_at).map { |ts| ts&.iso8601 },
      guest_login_attempt_timestamps: guest_login_attempts.pluck(:created_at).map { |ts| ts&.iso8601 }
    }
  end

  # Get breakdowns
  def breakdowns
    {
      guest_vs_authenticated: {
        guest: base_query.where(buyer_id: nil).count,
        authenticated: base_query.where.not(buyer_id: nil).count
      },
      by_event_type: base_query.group(:event_type).count,
      by_category: category_click_events,
      by_subcategory: subcategory_click_events
    }
  end

  # Get top ads by reveals
  def top_ads_by_reveals(limit: 10)
    reveal_counts_by_ad = base_query
      .where(event_type: 'Reveal-Seller-Details')
      .group(:ad_id)
      .count
    
    top_ad_ids = reveal_counts_by_ad
      .sort_by { |_ad_id, count| -count }
      .first(limit)
      .map { |ad_id, _count| ad_id }
    
    top_ad_ids.map do |ad_id|
      ad = Ad.find_by(id: ad_id)
      next nil unless ad
      
      ad_click_events = base_query.where(ad_id: ad_id)
      ad_clicks = ad_click_events.where(event_type: 'Ad-Click').count
      reveal_clicks = ad_click_events.where(event_type: 'Reveal-Seller-Details').count
      
      guest_reveals_for_ad = ad_click_events
        .where(event_type: 'Reveal-Seller-Details')
        .where(buyer_id: nil)
        .count
      authenticated_reveals_for_ad = ad_click_events
        .where(event_type: 'Reveal-Seller-Details')
        .where.not(buyer_id: nil)
        .count
      
      conversions_for_ad = ad_click_events
        .where(event_type: 'Reveal-Seller-Details')
        .where("metadata->>'converted_from_guest' = 'true'")
        .count
      
      click_to_reveal_rate = ad_clicks > 0 ? 
        (reveal_clicks.to_f / ad_clicks * 100).round(2) : 0.0
      
      seller = ad.seller
      seller_name = seller&.enterprise_name || seller&.fullname || 'Unknown Seller'
      
      {
        ad_id: ad_id,
        ad_title: ad.title || 'Unknown Ad',
        ad_image_url: ad.first_media_url,
        category_name: ad.category&.name || 'Uncategorized',
        seller_name: seller_name,
        seller_id: ad.seller_id,
        total_click_events: ad_click_events.count,
        ad_clicks: ad_clicks,
        reveal_clicks: reveal_clicks,
        guest_reveals: guest_reveals_for_ad,
        authenticated_reveals: authenticated_reveals_for_ad,
        conversions: conversions_for_ad,
        click_to_reveal_rate: click_to_reveal_rate
      }
    end.compact
  end

  # Get recent click events with pagination
  def recent_click_events(page: 1, per_page: 50)
    page = [page.to_i, 1].max
    per_page = [[per_page.to_i, 1].max, 100].min
    
    filtered_query = apply_filters(base_query)
    total_events_count = filtered_query.count
    total_pages = (total_events_count.to_f / per_page).ceil
    offset = (page - 1) * per_page
    
    events = filtered_query
      .order(created_at: :desc)
      .offset(offset)
      .limit(per_page)
      .includes(:buyer, :ad)
      .map { |event| format_click_event(event) }
    
    {
      events: events,
      pagination: {
        page: page,
        per_page: per_page,
        total_count: total_events_count,
        total_pages: total_pages,
        has_next_page: page < total_pages,
        has_prev_page: page > 1
      }
    }
  end

  # Get click event trends (for seller-specific analytics)
  def click_event_trends(months: 5)
    return [] unless filters[:seller_id].present?
    
    end_date = Date.today.end_of_month
    start_date = (end_date - (months - 1).months).beginning_of_month
    
    ad_ids = Ad.where(seller_id: filters[:seller_id]).pluck(:id)
    return empty_trends(months) if ad_ids.empty?
    
    click_events = base_query
      .where(ad_id: ad_ids)
      .where('click_events.created_at BETWEEN ? AND ?', start_date, end_date)
      .group(Arel.sql("DATE_TRUNC('month', click_events.created_at)"), :event_type)
      .count
    
    (0..(months - 1)).map do |i|
      month_date = (end_date - i.months).beginning_of_month
      
      ad_clicks = click_events.select { |(date, event), _| date && date.to_date == month_date.to_date && event == 'Ad-Click' }.values.sum || 0
      add_to_wish_list = click_events.select { |(date, event), _| date && date.to_date == month_date.to_date && event == 'Add-to-Wish-List' }.values.sum || 0
      reveal_seller_details = click_events.select { |(date, event), _| date && date.to_date == month_date.to_date && event == 'Reveal-Seller-Details' }.values.sum || 0
      
      {
        month: month_date.strftime('%B %Y'),
        ad_clicks: ad_clicks,
        add_to_wish_list: add_to_wish_list,
        reveal_seller_details: reveal_seller_details
      }
    end.reverse
  end

  # Get demographics stats (for seller-specific analytics)
  def demographics_stats
    return {} unless filters[:seller_id].present?
    
    {
      top_age_group_clicks: top_clicks_by_demographic(:age_group),
      top_income_range_clicks: top_clicks_by_demographic(:income_range),
      top_education_level_clicks: top_clicks_by_demographic(:education_level),
      top_employment_status_clicks: top_clicks_by_demographic(:employment_status),
      top_sector_clicks: top_clicks_by_demographic(:sector)
    }
  end

  # Get category click events
  def category_click_events
    # Use base_query subquery to ensure consistency with dashboard totals
    # base_query already uses ClickEvent.excluding_internal_users (centralized exclusion logic)
    category_query = Category
      .joins(ads: :click_events)
      .where(ads: { deleted: false })
      .where(click_events: { id: base_query.select(:id) })
    
    # Filter by seller_id if provided
    if filters[:seller_id].present?
      ad_ids = Ad.where(seller_id: filters[:seller_id]).pluck(:id)
      category_query = category_query.where(click_events: { ad_id: ad_ids })
    end
    
    category_query
      .select('categories.name AS category_name, 
              click_events.event_type,
              click_events.created_at')
      .order('categories.name')
      .to_a
      .group_by(&:category_name)
      .transform_values do |records|
        {
          ad_clicks: records.count { |r| r.event_type == 'Ad-Click' },
          wish_list_clicks: records.count { |r| r.event_type == 'Add-to-Wish-List' },
          reveal_clicks: records.count { |r| r.event_type == 'Reveal-Seller-Details' },
          timestamps: records.map { |r| r.created_at&.iso8601 }
        }
      end
      .map do |category_name, data|
        {
          category_name: category_name,
          ad_clicks: data[:ad_clicks],
          wish_list_clicks: data[:wish_list_clicks],
          reveal_clicks: data[:reveal_clicks],
          timestamps: data[:timestamps]
        }
      end
  end

  # Get subcategory click events
  def subcategory_click_events
    # Use base_query subquery to ensure consistency with dashboard totals
    # base_query already uses ClickEvent.excluding_internal_users (centralized exclusion logic)
    subcategory_query = Subcategory
      .joins(:category)
      .joins('INNER JOIN ads ON ads.subcategory_id = subcategories.id')
      .joins('INNER JOIN click_events ON click_events.ad_id = ads.id')
      .where('ads.deleted = ?', false)
      .where(click_events: { id: base_query.select(:id) })
    
    # Filter by seller_id if provided
    if filters[:seller_id].present?
      ad_ids = Ad.where(seller_id: filters[:seller_id]).pluck(:id)
      subcategory_query = subcategory_query.where(click_events: { ad_id: ad_ids })
    end
    
    subcategory_query
      .select('subcategories.id AS subcategory_id,
              subcategories.name AS subcategory_name,
              categories.id AS category_id,
              categories.name AS category_name,
              click_events.event_type,
              click_events.created_at')
      .order('categories.name, subcategories.name')
      .to_a
      .group_by { |r| "#{r.category_name}::#{r.subcategory_name}" }
      .transform_values do |records|
        {
          category_name: records.first.category_name,
          subcategory_name: records.first.subcategory_name,
          ad_clicks: records.count { |r| r.event_type == 'Ad-Click' },
          wish_list_clicks: records.count { |r| r.event_type == 'Add-to-Wish-List' },
          reveal_clicks: records.count { |r| r.event_type == 'Reveal-Seller-Details' },
          timestamps: records.map { |r| r.created_at&.iso8601 }
        }
      end
      .values
      .map do |data|
        {
          category_name: data[:category_name],
          subcategory_name: data[:subcategory_name],
          ads_count: Subcategory.joins(:ads).where(name: data[:subcategory_name], ads: { deleted: false }).count,
          ad_clicks: data[:ad_clicks],
          wish_list_clicks: data[:wish_list_clicks],
          reveal_clicks: data[:reveal_clicks],
          timestamps: data[:timestamps]
        }
      end
  end

  private

  def build_base_query
    # Use ClickEvent.excluding_internal_users which now handles:
    # - Sales members (checks SalesUser emails)
    # - Deleted users (buyers.deleted = false)
    # - @example.com domain emails
    # - Denis emails (checks if they exist first)
    # - Timothy Juma emails (checks if they exist first)
    # - All other internal user exclusions
    query = ClickEvent.excluding_internal_users
    
    # Filter by seller_id if provided
    if filters[:seller_id].present?
      ad_ids = Ad.where(seller_id: filters[:seller_id]).pluck(:id)
      query = query.where(ad_id: ad_ids)
    end
    
    query
  end

  def apply_filters(query)
    filtered = query
    
    # Filter by event type
    if filters[:event_type].present?
      filtered = filtered.where(event_type: filters[:event_type])
    end
    
    # Filter by user status
    if filters[:user_status] == 'guest'
      filtered = filtered.where(buyer_id: nil)
    elsif filters[:user_status] == 'authenticated'
      filtered = filtered.where.not(buyer_id: nil)
    end
    
    # Filter by date range
    if filters[:start_date].present?
      start_date = Time.parse(filters[:start_date]) rescue nil
      filtered = filtered.where('created_at >= ?', start_date) if start_date
    end
    
    if filters[:end_date].present?
      end_date = Time.parse(filters[:end_date]) rescue nil
      filtered = filtered.where('created_at <= ?', end_date) if end_date
    end
    
    filtered
  end

  def conversion_events
    base_query
      .where(event_type: 'Reveal-Seller-Details')
      .where("metadata->>'converted_from_guest' = 'true'")
  end

  def post_login_reveals
    base_query
      .where(event_type: 'Reveal-Seller-Details')
      .where("metadata->>'post_login_reveal' = 'true'")
  end

  def guest_login_attempts
    base_query
      .where(event_type: 'Reveal-Seller-Details')
      .where(buyer_id: nil)
      .where("metadata->>'triggered_login_modal' = 'true'")
  end

  def calculate_conversion_rate
    guest_attempts = guest_login_attempts.count
    conversions = conversion_events.count
    guest_attempts > 0 ? (conversions.to_f / guest_attempts * 100).round(2) : 0.0
  end

  def top_clicks_by_demographic(demographic_type)
    query = base_query
    
    # Join with ads if seller_id filter is present (to ensure we only get clicks for seller's ads)
    if filters[:seller_id].present?
      query = query.joins(:ad).where(ads: { seller_id: filters[:seller_id] })
    end
    
    case demographic_type
    when :age_group
      clicks = query.joins(buyer: :age_group)
                    .group('age_groups.name', :event_type)
                    .count
    when :income_range
      clicks = query.joins(buyer: :income)
                    .group("incomes.range", :event_type)
                    .count
    when :education_level
      clicks = query.joins(buyer: :education)
                    .group("educations.level", :event_type)
                    .count
    when :employment_status
      clicks = query.joins(buyer: :employment)
                    .group("employments.status", :event_type)
                    .count
    when :sector
      clicks = query.joins(buyer: :sector)
                    .group("sectors.name", :event_type)
                    .count
    else
      return nil
    end
    
    get_top_clicks(clicks, demographic_type)
  end

  def get_top_clicks(clicks, group_key)
    # Handle both array keys (from group queries) and hash keys
    top_ad_click = clicks.select { |k, _| 
      (k.is_a?(Array) && k[1] == 'Ad-Click') || 
      (k.is_a?(Hash) && k[:event_type] == 'Ad-Click') ||
      (k.is_a?(Hash) && k['event_type'] == 'Ad-Click')
    }.max_by { |_, count| count }
    
    top_wishlist = clicks.select { |k, _| 
      (k.is_a?(Array) && k[1] == 'Add-to-Wish-List') || 
      (k.is_a?(Hash) && k[:event_type] == 'Add-to-Wish-List') ||
      (k.is_a?(Hash) && k['event_type'] == 'Add-to-Wish-List')
    }.max_by { |_, count| count }
    
    top_reveal = clicks.select { |k, _| 
      (k.is_a?(Array) && k[1] == 'Reveal-Seller-Details') || 
      (k.is_a?(Hash) && k[:event_type] == 'Reveal-Seller-Details') ||
      (k.is_a?(Hash) && k['event_type'] == 'Reveal-Seller-Details')
    }.max_by { |_, count| count }
    
    {
      top_ad_click: format_top_click(top_ad_click, group_key),
      top_wishlist: format_top_click(top_wishlist, group_key),
      top_reveal: format_top_click(top_reveal, group_key)
    }
  end

  def format_top_click(click_data, group_key)
    return nil unless click_data
    
    key, count = click_data
    demographic_value = if key.is_a?(Array)
      key[0]
    elsif key.is_a?(Hash)
      key[group_key] || key[group_key.to_s]
    else
      key
    end
    
    {
      group_key => demographic_value,
      clicks: count
    }
  end

  def format_click_event(event)
    metadata = event.metadata || {}
    device_fingerprint = metadata['device_fingerprint'] || metadata[:device_fingerprint] || {}
    
    buyer_info = nil
    if event.buyer_id && event.buyer
      buyer = event.buyer
      buyer_info = {
        id: buyer.id,
        name: buyer.fullname,
        email: buyer.email,
        username: buyer.username,
        phone: buyer.phone_number
      }
    end
    
    user_info_from_metadata = nil
    if metadata['user_id'] || metadata[:user_id]
      user_info_from_metadata = {
        id: metadata['user_id'] || metadata[:user_id],
        role: metadata['user_role'] || metadata[:user_role],
        email: metadata['user_email'] || metadata[:user_email],
        username: metadata['user_username'] || metadata[:user_username]
      }
    end
    
    {
      id: event.id,
      event_type: event.event_type,
      ad_id: event.ad_id,
      ad_title: event.ad&.title || 'Unknown Ad',
      ad_image_url: event.ad&.first_media_url,
      created_at: event.created_at&.iso8601,
      buyer_id: event.buyer_id,
      buyer_info: buyer_info,
      user_info: user_info_from_metadata,
      was_authenticated: metadata['was_authenticated'] || metadata[:was_authenticated] || false,
      is_guest: metadata['is_guest'] || metadata[:is_guest] || !event.buyer_id,
      device_hash: metadata['device_hash'] || metadata[:device_hash],
      user_agent: metadata['user_agent'] || metadata[:user_agent],
      platform: device_fingerprint['platform'] || device_fingerprint[:platform],
      screen_size: format_screen_size(device_fingerprint),
      language: device_fingerprint['language'] || device_fingerprint[:language],
      timezone: device_fingerprint['timezone'] || device_fingerprint[:timezone],
      converted_from_guest: metadata['converted_from_guest'] || metadata[:converted_from_guest] || false,
      post_login_reveal: metadata['post_login_reveal'] || metadata[:post_login_reveal] || false,
      triggered_login_modal: metadata['triggered_login_modal'] || metadata[:triggered_login_modal] || false,
      source: metadata['source'] || metadata[:source]
    }
  end

  def format_screen_size(device_fingerprint)
    width = device_fingerprint['screen_width'] || device_fingerprint[:screen_width]
    height = device_fingerprint['screen_height'] || device_fingerprint[:screen_height]
    width && height ? "#{width}x#{height}" : nil
  end

  def apply_exclusion_conditions(query, excluded_device_hashes, excluded_email_domains, excluded_user_agents)
    return query if excluded_device_hashes.empty? && excluded_email_domains.empty? && excluded_user_agents.empty?
    
    excluded_device_hashes.each do |hash|
      query = query.where(
        "COALESCE(click_events.metadata->>'device_hash', '') NOT LIKE ? AND COALESCE(click_events.metadata->>'device_hash', '') != ?",
        "#{hash}%", hash
      )
    end
    
    excluded_email_domains.each do |email_pattern|
      email_pattern_lower = email_pattern.downcase
      query = query.where(
        "(buyers.email IS NULL OR LOWER(buyers.email) != ?) AND (click_events.metadata->>'user_email' IS NULL OR LOWER(click_events.metadata->>'user_email') != ?)",
        email_pattern_lower, email_pattern_lower
      )
      if email_pattern.include?('@')
        domain = email_pattern.split('@').last&.downcase
        if domain.present?
          query = query.where(
            "(buyers.email IS NULL OR LOWER(buyers.email) NOT LIKE ?) AND (click_events.metadata->>'user_email' IS NULL OR LOWER(click_events.metadata->>'user_email') NOT LIKE ?)",
            "%@#{domain}", "%@#{domain}"
          )
        end
      else
        query = query.where(
          "(buyers.email IS NULL OR LOWER(buyers.email) NOT LIKE ?) AND (click_events.metadata->>'user_email' IS NULL OR LOWER(click_events.metadata->>'user_email') NOT LIKE ?)",
          "%@#{email_pattern_lower}", "%@#{email_pattern_lower}"
        )
      end
    end
    
    excluded_user_agents.each do |pattern|
      query = query.where(
        "click_events.metadata->>'user_agent' IS NULL OR click_events.metadata->>'user_agent' !~* ?",
        pattern
      )
    end
    
    query
  end

  def empty_trends(months)
    end_date = Date.today.end_of_month
    (0..(months - 1)).map do |i|
      month_date = end_date - i.months
      {
        month: month_date.strftime('%B %Y'),
        ad_clicks: 0,
        add_to_wish_list: 0,
        reveal_seller_details: 0
      }
    end.reverse
  end
end

