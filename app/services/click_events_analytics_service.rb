class ClickEventsAnalyticsService
  attr_reader :base_query, :filters

  def initialize(filters: {}, device_hash: nil)
    @filters = filters || {}
    @device_hash = device_hash
    @base_query = build_base_query
  end

  # Main method to get all click events analytics
  # Options: include_timestamps (default: true), include_breakdowns (default: true), include_top_ads (default: true)
  def analytics(options: {})
    include_timestamps = options.fetch(:include_timestamps, true)
    include_breakdowns = options.fetch(:include_breakdowns, true)
    include_top_ads = options.fetch(:include_top_ads, true)
    
    result = {
      # Totals (always needed)
      totals: totals,
    }
    
    # Only include timestamps if requested (they can be expensive)
    # Wrap in begin/rescue to ensure we always return a value even if there's an error
    if include_timestamps
      begin
        result[:timestamps] = timestamps
      rescue => e
        Rails.logger.error "Error fetching timestamps: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        # Return empty timestamps structure to prevent nil errors in controller
        result[:timestamps] = {
          click_events_timestamps: [],
          reveal_events_timestamps: [],
          ad_clicks_timestamps: [],
          callback_requests_timestamps: [],
          guest_reveal_timestamps: [],
          authenticated_reveal_timestamps: [],
          conversion_timestamps: [],
          post_login_reveal_timestamps: [],
          guest_login_attempt_timestamps: []
        }
      end
    end

    # Include contact counts per ad (always include since it's needed for UI)
    begin
      result[:contact_counts] = contact_counts_by_ad
    rescue => e
      Rails.logger.error "Error fetching contact counts: #{e.message}"
      result[:contact_counts] = {}
    end

    # Only include breakdowns if requested
    if include_breakdowns
      begin
        result[:breakdowns] = breakdowns
      rescue => e
        Rails.logger.error "Error fetching breakdowns: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        result[:breakdowns] = default_breakdowns
      end
    end
    
    # Only include top ads if requested
    if include_top_ads
      begin
        result[:top_ads] = top_ads_by_reveals
      rescue => e
        Rails.logger.error "Error fetching top ads: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        result[:top_ads] = []
      end
    end
    
    # Recent events, trends, and demographics are typically not needed for main analytics
    # They should be fetched separately when needed
    
    result
  end

  # Get totals - optimized to use a single query with conditional aggregation
  def totals
    # Use a single query with conditional aggregation instead of multiple count queries
    # Use .take instead of .first to avoid ORDER BY clauses that conflict with aggregate functions
    stats = base_query.reorder(nil).select(
      "COUNT(*) as total_click_events",
      "COUNT(*) FILTER (WHERE event_type = 'Reveal-Seller-Details') as total_reveal_events",
      "COUNT(*) FILTER (WHERE event_type = 'Ad-Click') as total_ad_clicks",
      "COUNT(*) FILTER (WHERE event_type = 'Callback-Request') as total_callback_requests",
      "COUNT(*) FILTER (WHERE event_type = 'Reveal-Seller-Details' AND buyer_id IS NULL) as guest_reveals",
      "COUNT(*) FILTER (WHERE event_type = 'Reveal-Seller-Details' AND buyer_id IS NOT NULL) as authenticated_reveals",
      "COUNT(*) FILTER (WHERE event_type = 'Reveal-Seller-Details' AND metadata->>'converted_from_guest' = 'true') as conversion_count",
      "COUNT(*) FILTER (WHERE event_type = 'Reveal-Seller-Details' AND metadata->>'post_login_reveal' = 'true') as post_login_reveal_count",
      "COUNT(*) FILTER (WHERE event_type = 'Reveal-Seller-Details' AND buyer_id IS NULL AND metadata->>'triggered_login_modal' = 'true') as guest_login_attempt_count"
    ).take
    
    # Aggregate queries always return at least one row, but handle nil for safety
    return default_totals if stats.nil?
    
    guest_attempts = stats.guest_login_attempt_count.to_i
    conversions = stats.conversion_count.to_i
    conversion_rate = guest_attempts > 0 ? (conversions.to_f / guest_attempts * 100).round(2) : 0.0
    
    {
      total_click_events: stats.total_click_events.to_i,
      total_reveal_events: stats.total_reveal_events.to_i,
      total_ad_clicks: stats.total_ad_clicks.to_i,
      total_callback_requests: stats.total_callback_requests.to_i,
      guest_reveals: stats.guest_reveals.to_i,
      authenticated_reveals: stats.authenticated_reveals.to_i,
      conversion_count: conversions,
      conversion_rate: conversion_rate,
      post_login_reveal_count: stats.post_login_reveal_count.to_i,
      guest_login_attempt_count: guest_attempts
    }
  end

  # Get timestamps for frontend filtering - optimized to use SQL aggregations instead of loading all into memory
  # This is much faster for large datasets as it uses database-level aggregations
  # OPTIMIZATION: Limit to last 2 years by default to improve performance
  def timestamps(limit: 10000, date_limit: 2.years.ago)
    # Build base query with ordering - each event type will use a fresh copy
    base_ordered_query = base_query.order("click_events.created_at DESC")
    
    # Apply date limit if provided (for performance optimization)
    if date_limit.present?
      base_ordered_query = base_ordered_query.where('click_events.created_at >= ?', date_limit)
    end
    
    # Apply limit only if provided (nil means no limit - return all records)
    if limit.present?
      base_ordered_query = base_ordered_query.limit(limit)
    end
    
    # Get timestamps using direct pluck - pluck returns Time objects which we convert to ISO8601
    # Use qualified column name to avoid ambiguity
    # Get all click events timestamps
    click_events_timestamps = base_ordered_query.pluck(Arel.sql("click_events.created_at"))
      .map { |ts| ts&.iso8601 }.compact
    
    # Get reveal events timestamps - build fresh query from base
    reveal_events_query = base_query
      .where(event_type: 'Reveal-Seller-Details')
      .order("click_events.created_at DESC")
    reveal_events_query = reveal_events_query.where('click_events.created_at >= ?', date_limit) if date_limit.present?
    reveal_events_query = reveal_events_query.limit(limit) if limit.present?
    reveal_events_timestamps = reveal_events_query.pluck(Arel.sql("click_events.created_at"))
      .map { |ts| ts&.iso8601 }.compact
    
    # Get ad clicks timestamps - build fresh query from base
    ad_clicks_query = base_query
      .where(event_type: 'Ad-Click')
      .order("click_events.created_at DESC")
    ad_clicks_query = ad_clicks_query.where('click_events.created_at >= ?', date_limit) if date_limit.present?
    ad_clicks_query = ad_clicks_query.limit(limit) if limit.present?
    ad_clicks_timestamps = ad_clicks_query.pluck(Arel.sql("click_events.created_at"))
      .map { |ts| ts&.iso8601 }.compact
    
    # Get guest reveal timestamps
    guest_reveals_query = base_query
      .where(event_type: 'Reveal-Seller-Details', buyer_id: nil)
      .order("click_events.created_at DESC")
    guest_reveals_query = guest_reveals_query.where('click_events.created_at >= ?', date_limit) if date_limit.present?
    guest_reveals_query = guest_reveals_query.limit(limit) if limit.present?
    guest_reveal_timestamps = guest_reveals_query.pluck(Arel.sql("click_events.created_at"))
      .map { |ts| ts&.iso8601 }.compact
    
    # Get authenticated reveal timestamps
    authenticated_reveals_query = base_query
      .where(event_type: 'Reveal-Seller-Details')
      .where.not(buyer_id: nil)
      .order("click_events.created_at DESC")
    authenticated_reveals_query = authenticated_reveals_query.where('click_events.created_at >= ?', date_limit) if date_limit.present?
    authenticated_reveals_query = authenticated_reveals_query.limit(limit) if limit.present?
    authenticated_reveal_timestamps = authenticated_reveals_query.pluck(Arel.sql("click_events.created_at"))
      .map { |ts| ts&.iso8601 }.compact
    
    # Get conversion timestamps (using JSONB query with index)
    conversions_query = base_query
      .where(event_type: 'Reveal-Seller-Details')
      .where("metadata->>'converted_from_guest' = ?", 'true')
      .order("click_events.created_at DESC")
    conversions_query = conversions_query.where('click_events.created_at >= ?', date_limit) if date_limit.present?
    conversions_query = conversions_query.limit(limit) if limit.present?
    conversion_timestamps = conversions_query.pluck(Arel.sql("click_events.created_at"))
      .map { |ts| ts&.iso8601 }.compact
    
    # Get post-login reveal timestamps
    post_login_reveals_query = base_query
      .where(event_type: 'Reveal-Seller-Details')
      .where("metadata->>'post_login_reveal' = ?", 'true')
      .order("click_events.created_at DESC")
    post_login_reveals_query = post_login_reveals_query.where('click_events.created_at >= ?', date_limit) if date_limit.present?
    post_login_reveals_query = post_login_reveals_query.limit(limit) if limit.present?
    post_login_reveal_timestamps = post_login_reveals_query.pluck(Arel.sql("click_events.created_at"))
      .map { |ts| ts&.iso8601 }.compact
    
    # Get guest login attempt timestamps
    guest_login_attempts_query = base_query
      .where(event_type: 'Reveal-Seller-Details', buyer_id: nil)
      .where("metadata->>'triggered_login_modal' = ?", 'true')
      .order("click_events.created_at DESC")
    guest_login_attempts_query = guest_login_attempts_query.where('click_events.created_at >= ?', date_limit) if date_limit.present?
    guest_login_attempts_query = guest_login_attempts_query.limit(limit) if limit.present?
    guest_login_attempt_timestamps = guest_login_attempts_query.pluck(Arel.sql("click_events.created_at"))
      .map { |ts| ts&.iso8601 }.compact
    
    # Get callback request timestamps
    callback_requests_query = base_query
      .where(event_type: 'Callback-Request')
      .order("click_events.created_at DESC")
    callback_requests_query = callback_requests_query.where('click_events.created_at >= ?', date_limit) if date_limit.present?
    callback_requests_query = callback_requests_query.limit(limit) if limit.present?
    callback_requests_timestamps = callback_requests_query.pluck(Arel.sql("click_events.created_at"))
      .map { |ts| ts&.iso8601 }.compact
    
    {
      click_events_timestamps: click_events_timestamps,
      reveal_events_timestamps: reveal_events_timestamps,
      ad_clicks_timestamps: ad_clicks_timestamps,
      callback_requests_timestamps: callback_requests_timestamps,
      guest_reveal_timestamps: guest_reveal_timestamps,
      authenticated_reveal_timestamps: authenticated_reveal_timestamps,
      conversion_timestamps: conversion_timestamps,
      post_login_reveal_timestamps: post_login_reveal_timestamps,
      guest_login_attempt_timestamps: guest_login_attempt_timestamps
    }
  end

  # Get breakdowns - optimized to use single queries
  def breakdowns
    # Use a single query with conditional aggregation for guest vs authenticated
    # Use .take instead of .first to avoid ORDER BY clauses that conflict with aggregate functions
    guest_auth_stats = base_query.reorder(nil).select(
      "COUNT(*) FILTER (WHERE buyer_id IS NULL) as guest_count",
      "COUNT(*) FILTER (WHERE buyer_id IS NOT NULL) as authenticated_count"
    ).take
    
    # Aggregate queries always return at least one row, but handle nil for safety
    return default_breakdowns if guest_auth_stats.nil?
    
    {
      guest_vs_authenticated: {
        guest: guest_auth_stats.guest_count.to_i,
        authenticated: guest_auth_stats.authenticated_count.to_i
      },
      by_event_type: base_query.group(:event_type).count,
      by_category: category_click_events,
      by_subcategory: subcategory_click_events
    }
  end

  # Get top ads by reveals - optimized to use a single SQL query with aggregations
  def top_ads_by_reveals(limit: 10)
    # Use a single query with aggregations to get all stats for top ads
    # This eliminates N+1 queries by fetching all data in one go
    top_ads_data = base_query
      .joins("INNER JOIN ads ON ads.id = click_events.ad_id")
      .joins("LEFT JOIN categories ON categories.id = ads.category_id")
      .joins("LEFT JOIN sellers ON sellers.id = ads.seller_id")
      .where("ads.deleted = ?", false)
      .group("ads.id", "ads.title", "ads.media", "ads.seller_id", "categories.name", 
              "sellers.enterprise_name", "sellers.fullname")
      .select(
        "ads.id as ad_id",
        "ads.title as ad_title",
        "CASE WHEN ads.media IS NOT NULL AND ads.media != '' THEN (ads.media::json->>0) ELSE NULL END as ad_image_url",
        "ads.seller_id as seller_id",
        "categories.name as category_name",
        "sellers.enterprise_name as seller_enterprise_name",
        "sellers.fullname as seller_fullname",
        "COUNT(*) as total_click_events",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Ad-Click') as ad_clicks",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Reveal-Seller-Details') as reveal_clicks",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Reveal-Seller-Details' AND click_events.buyer_id IS NULL) as guest_reveals",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Reveal-Seller-Details' AND click_events.buyer_id IS NOT NULL) as authenticated_reveals",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Reveal-Seller-Details' AND click_events.metadata->>'converted_from_guest' = 'true') as conversions",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Reveal-Seller-Details' AND click_events.metadata->>'action' = 'seller_contact_interaction' AND click_events.metadata->>'action_type' IN ('copy_phone', 'copy_email')) as copy_clicks",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Reveal-Seller-Details' AND click_events.metadata->>'action' = 'seller_contact_interaction' AND click_events.metadata->>'action_type' = 'call_phone') as call_clicks",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Reveal-Seller-Details' AND click_events.metadata->>'action' = 'seller_contact_interaction' AND click_events.metadata->>'action_type' = 'whatsapp') as whatsapp_clicks",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Reveal-Seller-Details' AND click_events.metadata->>'action' = 'seller_contact_interaction' AND click_events.metadata->>'action_type' = 'view_location') as location_clicks"
      )
      .having(Arel.sql("COUNT(*) FILTER (WHERE click_events.event_type = 'Reveal-Seller-Details') > 0"))
      .order(Arel.sql("COUNT(*) FILTER (WHERE click_events.event_type = 'Reveal-Seller-Details') DESC"))
      .limit(limit)
      .to_a
    
    top_ads_data.map do |row|
      ad_clicks = row.ad_clicks.to_i
      reveal_clicks = row.reveal_clicks.to_i
      click_to_reveal_rate = ad_clicks > 0 ? (reveal_clicks.to_f / ad_clicks * 100).round(2) : 0.0
      
      seller_name = row.seller_enterprise_name.presence || row.seller_fullname.presence || 'Unknown Seller'
      
      {
        ad_id: row.ad_id,
        ad_title: row.ad_title || 'Unknown Ad',
        ad_image_url: row.ad_image_url,
        category_name: row.category_name || 'Uncategorized',
        seller_name: seller_name,
        seller_id: row.seller_id,
        total_click_events: row.total_click_events.to_i,
        ad_clicks: ad_clicks,
        reveal_clicks: reveal_clicks,
        guest_reveals: row.guest_reveals.to_i,
        authenticated_reveals: row.authenticated_reveals.to_i,
        conversions: row.conversions.to_i,
        click_to_reveal_rate: click_to_reveal_rate,
        copy_clicks: row.copy_clicks.to_i,
        call_clicks: row.call_clicks.to_i,
        whatsapp_clicks: row.whatsapp_clicks.to_i,
        location_clicks: row.location_clicks.to_i,
        total_contact_interactions: row.copy_clicks.to_i + row.call_clicks.to_i + row.whatsapp_clicks.to_i + row.location_clicks.to_i
      }
    end
  end

  # Get recent click events with pagination
  # Options: parse_user_agent (default: false) - set to true only if user agent details are needed
  def recent_click_events(page: 1, per_page: 50, parse_user_agent: false)
    page = [page.to_i, 1].max
    # Increased limit to 500 to support grouped data display (need more events to get enough groups)
    per_page = [[per_page.to_i, 1].max, 500].min
    
    filtered_query = apply_filters(base_query)
    
    # OPTIMIZATION: Use fast count estimation for large datasets
    # For pagination, we only need to know if there are more pages, not exact count
    # Check if there are more records than we need for current page
    offset = (page - 1) * per_page
    # Check if there's at least one more record after the current page
    has_more = filtered_query.offset(offset + per_page).limit(1).exists?
    
    # For exact count, only calculate if we're on early pages (where it matters for UI)
    # For later pages, use estimation based on whether there are more records
    total_events_count = if page <= 5
      # Calculate exact count for early pages (needed for accurate pagination UI)
      filtered_query.count
    else
      # For later pages, estimate: current page records + 1 if more exist
      has_more ? (offset + per_page + 1) : (offset + per_page)
    end
    total_pages = (total_events_count.to_f / per_page).ceil
    
    # Optimize query with proper includes and select only needed columns
    # Qualify created_at with table name to avoid ambiguity when joining with ads table
    events_query = filtered_query
      .order("click_events.created_at DESC")
      .offset(offset)
      .limit(per_page)
      .includes(:buyer, ad: [:category, :subcategory, :seller])
    
    # Map events with optional user agent parsing
    events = events_query.map { |event| format_click_event(event, parse_user_agent: parse_user_agent) }
    
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
  # months: nil means all-time data, otherwise returns last N months
  def click_event_trends(months: 5)
    return [] unless filters[:seller_id].present?
    
    ad_ids = Ad.where(seller_id: filters[:seller_id]).pluck(:id)
    return empty_trends(months || 1) if ad_ids.empty?
    
    # If months is nil, get all-time data
    if months.nil?
      # Get the first click event date for this seller to determine the start date
      first_event = base_query
        .where(ad_id: ad_ids)
        .order('click_events.created_at ASC')
        .limit(1)
        .pluck('click_events.created_at')
        .first
      
      return [] unless first_event
      
      # Calculate all months from first event to now
      start_date = first_event.to_date.beginning_of_month
      end_date = Date.today.end_of_month
      
      # Get all click events grouped by month (all-time, no date restriction in WHERE clause)
      click_events = base_query
        .where(ad_id: ad_ids)
        .group(Arel.sql("DATE_TRUNC('month', click_events.created_at)"), :event_type)
        .count
      
      # Build a list of all months from start to end
      months_list = []
      current_month = start_date
      while current_month <= end_date
        months_list << current_month
        current_month = current_month.next_month.beginning_of_month
      end
      
      # Build monthly data for all months
      months_list.map do |month_date|
        ad_clicks = click_events.select { |(date, event), _| date && date.to_date == month_date.to_date && event == 'Ad-Click' }.values.sum || 0
        add_to_wish_list = click_events.select { |(date, event), _| date && date.to_date == month_date.to_date && event == 'Add-to-Wish-List' }.values.sum || 0
        reveal_seller_details = click_events.select { |(date, event), _| date && date.to_date == month_date.to_date && event == 'Reveal-Seller-Details' }.values.sum || 0
        
        {
          month: month_date.strftime('%B %Y'),
          ad_clicks: ad_clicks,
          add_to_wish_list: add_to_wish_list,
          reveal_seller_details: reveal_seller_details
        }
      end
    else
      # Original logic for last N months
      end_date = Date.today.end_of_month
      start_date = (end_date - (months - 1).months).beginning_of_month
      
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

  # Get category click events - optimized to use SQL aggregations
  def category_click_events
    # Use base_query subquery to ensure consistency with dashboard totals
    # Optimize by using SQL aggregations instead of loading all records into memory
    # Use EXISTS subquery for better performance than IN with large datasets
    category_query = Category
      .joins("INNER JOIN ads ON ads.category_id = categories.id")
      .joins("INNER JOIN click_events ON click_events.ad_id = ads.id")
      .where(ads: { deleted: false })
      .where("click_events.id IN (#{base_query.select(:id).to_sql})")
    
    # Filter by seller_id if provided
    if filters[:seller_id].present?
      ad_ids = Ad.where(seller_id: filters[:seller_id]).pluck(:id)
      category_query = category_query.where(click_events: { ad_id: ad_ids })
    end
    
    # Use SQL aggregations to get counts - limit timestamps to recent events for performance
    # Only get timestamps for the most recent 1000 events per category to avoid memory issues
    category_query
      .group('categories.id', 'categories.name')
      .select(
        'categories.id AS category_id',
        'categories.name AS category_name',
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Ad-Click') as ad_clicks",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Add-to-Wish-List') as wish_list_clicks",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Reveal-Seller-Details') as reveal_clicks",
        "ARRAY_AGG(click_events.created_at ORDER BY click_events.created_at DESC) FILTER (WHERE click_events.created_at IS NOT NULL) as timestamps_array"
      )
      .order('categories.name')
      .map do |row|
        # Limit timestamps to most recent 1000 per category for performance
        timestamps = if row.respond_to?(:timestamps_array) && row.timestamps_array
          row.timestamps_array.first(1000).map { |ts| ts&.iso8601 }.compact
        else
          []
        end
        
        {
          category_name: row.category_name,
          ad_clicks: row.ad_clicks.to_i,
          wish_list_clicks: row.wish_list_clicks.to_i,
          reveal_clicks: row.reveal_clicks.to_i,
          timestamps: timestamps
        }
      end
  end

  # Get subcategory click events - optimized to use SQL aggregations
  def subcategory_click_events
    # Use base_query subquery to ensure consistency with dashboard totals
    # Optimize by using SQL aggregations instead of loading all records into memory
    subcategory_query = Subcategory
      .joins(:category)
      .joins('INNER JOIN ads ON ads.subcategory_id = subcategories.id')
      .joins('INNER JOIN click_events ON click_events.ad_id = ads.id')
      .where('ads.deleted = ?', false)
      .where("click_events.id IN (#{base_query.select(:id).to_sql})")
    
    # Filter by seller_id if provided
    if filters[:seller_id].present?
      ad_ids = Ad.where(seller_id: filters[:seller_id]).pluck(:id)
      subcategory_query = subcategory_query.where(click_events: { ad_id: ad_ids })
    end
    
    # Get ads_count for each subcategory in a single query - use subquery for better performance
    subcategory_ids = subcategory_query.distinct.pluck('subcategories.id')
    ads_counts = Subcategory
      .joins(:ads)
      .where(id: subcategory_ids, ads: { deleted: false })
      .group('subcategories.name')
      .count('ads.id')
    
    # Use SQL aggregations to get counts and timestamps in a single query
    # Limit timestamps to recent events for performance
    subcategory_query
      .group('subcategories.id', 'subcategories.name', 'categories.id', 'categories.name')
      .select(
        'subcategories.id AS subcategory_id',
        'subcategories.name AS subcategory_name',
        'categories.id AS category_id',
        'categories.name AS category_name',
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Ad-Click') as ad_clicks",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Add-to-Wish-List') as wish_list_clicks",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Reveal-Seller-Details') as reveal_clicks",
        "ARRAY_AGG(click_events.created_at ORDER BY click_events.created_at DESC) FILTER (WHERE click_events.created_at IS NOT NULL) as timestamps_array"
      )
      .order('categories.name, subcategories.name')
      .map do |row|
        # Limit timestamps to most recent 1000 per subcategory for performance
        timestamps = if row.respond_to?(:timestamps_array) && row.timestamps_array
          row.timestamps_array.first(1000).map { |ts| ts&.iso8601 }.compact
        else
          []
        end
        
        {
          category_name: row.category_name,
          subcategory_name: row.subcategory_name,
          ads_count: ads_counts[row.subcategory_name] || 0,
          ad_clicks: row.ad_clicks.to_i,
          wish_list_clicks: row.wish_list_clicks.to_i,
          reveal_clicks: row.reveal_clicks.to_i,
          timestamps: timestamps
        }
      end
  end

  private

  def build_base_query
    # OPTIMIZATION: Apply date filter first to reduce dataset size before expensive exclusions
    # Limit to last 2 years by default for better performance (can be overridden by date filters in apply_filters)
    # Only apply if no explicit date filters are provided
    query = if filters[:start_date].present? || filters[:end_date].present?
      # If date filters are provided, let apply_filters handle them
      ClickEvent.all
    else
      # Otherwise, limit to last 2 years for performance
      ClickEvent.where('click_events.created_at >= ?', 2.years.ago)
    end
    
    # Use ClickEvent.excluding_internal_users which now handles:
    # - Sales members (checks SalesUser emails) - now cached
    # - Deleted users (buyers.deleted = false)
    # - @example.com domain emails
    # - Denis emails (checks if they exist first)
    # - Timothy Juma emails (checks if they exist first)
    # - All other internal user exclusions
    query = query.excluding_internal_users
    
    # Exclude click events where sellers click their own ads
    # This excludes events where:
    # - metadata->>'user_role' = 'seller' AND metadata->>'user_id' matches the ad's seller_id
    #   (handles clicks from logged-in sellers)
    # - OR device_hash matches AND the ad's seller_id matches seller_id
    #   (handles guest clicks from sellers clicking their own ads before login)
    # Pass seller_id to the scope so it can exclude guest clicks for that specific seller
    query = query.excluding_seller_own_clicks(
      device_hash: @device_hash,
      seller_id: filters[:seller_id]
    )
    
    # Join with buyer to filter deleted buyers (matching dashboard logic)
    query = query.left_joins(:buyer)
    query = query.where("buyers.id IS NULL OR buyers.deleted = ?", false)
    
    # Join with ad to exclude clicks without ads and clicks with deleted ads (matching dashboard logic)
    query = query.joins(:ad)
    query = query.where(ads: { deleted: false })
    
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
      event_type = filters[:event_type]
      
      # Handle special contact interaction event types
      case event_type
      when 'Contact'
        # All contact interactions (any action_type)
        filtered = filtered.where(event_type: 'Reveal-Seller-Details')
          .where("metadata->>'action' = ?", 'seller_contact_interaction')
      when 'Copy'
        # Copy phone or email actions
        filtered = filtered.where(event_type: 'Reveal-Seller-Details')
          .where("metadata->>'action' = ?", 'seller_contact_interaction')
          .where("metadata->>'action_type' IN ('copy_phone', 'copy_email')")
      when 'Call'
        # Call phone action
        filtered = filtered.where(event_type: 'Reveal-Seller-Details')
          .where("metadata->>'action' = ?", 'seller_contact_interaction')
          .where("metadata->>'action_type' = ?", 'call_phone')
      when 'WhatsApp'
        # WhatsApp action
        filtered = filtered.where(event_type: 'Reveal-Seller-Details')
          .where("metadata->>'action' = ?", 'seller_contact_interaction')
          .where("metadata->>'action_type' = ?", 'whatsapp')
      when 'Location'
        # View location action
        filtered = filtered.where(event_type: 'Reveal-Seller-Details')
          .where("metadata->>'action' = ?", 'seller_contact_interaction')
          .where("metadata->>'action_type' = ?", 'view_location')
      else
        # Standard event type filter
        filtered = filtered.where(event_type: event_type)
      end
    end
    
    # Filter by user status
    if filters[:user_status] == 'guest'
      filtered = filtered.where(buyer_id: nil)
    elsif filters[:user_status] == 'authenticated'
      filtered = filtered.where.not(buyer_id: nil)
    end
    
    # Filter by date range
    # Qualify created_at with table name to avoid ambiguity when joining with ads table
    if filters[:start_date].present?
      start_date = Time.parse(filters[:start_date]) rescue nil
      filtered = filtered.where('click_events.created_at >= ?', start_date) if start_date
    end
    
    if filters[:end_date].present?
      end_date = Time.parse(filters[:end_date]) rescue nil
      filtered = filtered.where('click_events.created_at <= ?', end_date) if end_date
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

  def format_click_event(event, parse_user_agent: false)
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
    
    # Extract contact interaction details if this is a seller contact interaction
    contact_interaction = nil
    if metadata['action'] == 'seller_contact_interaction' || metadata[:action] == 'seller_contact_interaction'
      contact_interaction = {
        action_type: metadata['action_type'] || metadata[:action_type],
        contact_type: metadata['contact_type'] || metadata[:contact_type],
        phone_number: metadata['phone_number'] || metadata[:phone_number],
        location: metadata['location'] || metadata[:location]
      }
    end
    
    # Parse user agent only if requested (expensive operation)
    user_agent_raw = metadata['user_agent'] || metadata[:user_agent]
    user_agent_details = parse_user_agent ? parse_user_agent(user_agent_raw) : {}
    
    {
      id: event.id,
      event_type: event.event_type,
      ad_id: event.ad_id,
      ad_title: event.ad&.title || 'Unknown Ad',
      ad_image_url: event.ad&.first_media_url,
      ad_category_name: event.ad&.category&.name,
      ad_subcategory_name: event.ad&.subcategory&.name,
      seller_enterprise_name: event.ad&.seller&.enterprise_name || event.ad&.seller&.fullname,
      created_at: event.created_at&.iso8601,
      buyer_id: event.buyer_id,
      buyer_info: buyer_info,
      user_info: user_info_from_metadata,
      was_authenticated: metadata['was_authenticated'] || metadata[:was_authenticated] || false,
      is_guest: metadata['is_guest'] || metadata[:is_guest] || !event.buyer_id,
      device_hash: metadata['device_hash'] || metadata[:device_hash],
      user_agent: user_agent_raw,
      user_agent_details: user_agent_details,
      platform: device_fingerprint['platform'] || device_fingerprint[:platform],
      screen_size: format_screen_size(device_fingerprint),
      language: device_fingerprint['language'] || device_fingerprint[:language],
      timezone: device_fingerprint['timezone'] || device_fingerprint[:timezone],
      converted_from_guest: metadata['converted_from_guest'] || metadata[:converted_from_guest] || false,
      post_login_reveal: metadata['post_login_reveal'] || metadata[:post_login_reveal] || false,
      triggered_login_modal: metadata['triggered_login_modal'] || metadata[:triggered_login_modal] || false,
      source: metadata['source'] || metadata[:source],
      contact_interaction: contact_interaction
    }
  end

  def format_screen_size(device_fingerprint)
    width = device_fingerprint['screen_width'] || device_fingerprint[:screen_width]
    height = device_fingerprint['screen_height'] || device_fingerprint[:screen_height]
    width && height ? "#{width}x#{height}" : nil
  end

  def parse_user_agent(user_agent_string)
    return {} unless user_agent_string.present?
    
    begin
      require 'user_agent_parser'
      parser = UserAgentParser.parse(user_agent_string)
      
      # Extract browser information
      browser_name = parser.family
      browser_version = parser.version&.to_s
      
      # Extract OS information
      os_family = parser.os&.family
      os_version = parser.os&.version&.to_s
      
      # Detect device type
      user_agent_lower = user_agent_string.downcase
      device_type = detect_device_type(user_agent_lower)
      
      {
        browser: browser_name || 'Unknown',
        browser_version: browser_version,
        os: os_family || 'Unknown',
        os_version: os_version,
        device_type: device_type,
        is_mobile: mobile_device?(user_agent_lower),
        is_tablet: tablet_device?(user_agent_lower),
        is_desktop: desktop_device?(user_agent_lower)
      }
    rescue LoadError, StandardError => e
      # Fallback to basic detection if gem is not available or fails
      Rails.logger.warn "User agent parser failed for '#{user_agent_string}': #{e.message}"
      user_agent_lower = user_agent_string.downcase
      
      {
        browser: detect_browser_fallback(user_agent_lower),
        browser_version: nil,
        os: detect_os_fallback(user_agent_lower),
        os_version: nil,
        device_type: detect_device_type(user_agent_lower),
        is_mobile: mobile_device?(user_agent_lower),
        is_tablet: tablet_device?(user_agent_lower),
        is_desktop: desktop_device?(user_agent_lower)
      }
    end
  end

  def detect_device_type(user_agent_lower)
    return 'mobile' if mobile_device?(user_agent_lower)
    return 'tablet' if tablet_device?(user_agent_lower)
    return 'desktop' if desktop_device?(user_agent_lower)
    'unknown'
  end

  def mobile_device?(user_agent_lower)
    user_agent_lower.match?(/mobile|android|iphone|ipod|blackberry|opera mini|iemobile|wpdesktop/i)
  end

  def tablet_device?(user_agent_lower)
    user_agent_lower.match?(/tablet|ipad|playbook|silk/i) && !user_agent_lower.match?(/mobile/i)
  end

  def desktop_device?(user_agent_lower)
    !mobile_device?(user_agent_lower) && !tablet_device?(user_agent_lower)
  end

  def detect_browser_fallback(user_agent_lower)
    return 'Chrome' if user_agent_lower.include?('chrome') && !user_agent_lower.include?('edg')
    return 'Edge' if user_agent_lower.include?('edg')
    return 'Firefox' if user_agent_lower.include?('firefox')
    return 'Safari' if user_agent_lower.include?('safari') && !user_agent_lower.include?('chrome')
    return 'Opera' if user_agent_lower.include?('opera') || user_agent_lower.include?('opr')
    return 'Internet Explorer' if user_agent_lower.include?('msie') || user_agent_lower.include?('trident')
    'Unknown'
  end

  def detect_os_fallback(user_agent_lower)
    return 'Windows' if user_agent_lower.include?('windows')
    return 'macOS' if user_agent_lower.include?('mac os') || user_agent_lower.include?('macintosh')
    return 'Linux' if user_agent_lower.include?('linux') && !user_agent_lower.include?('android')
    return 'Android' if user_agent_lower.include?('android')
    return 'iOS' if user_agent_lower.include?('iphone') || user_agent_lower.include?('ipad') || user_agent_lower.include?('ipod')
    return 'Unix' if user_agent_lower.include?('unix')
    'Unknown'
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

  def default_totals
    {
      total_click_events: 0,
      total_reveal_events: 0,
      total_ad_clicks: 0,
      total_callback_requests: 0,
      guest_reveals: 0,
      authenticated_reveals: 0,
      conversion_count: 0,
      conversion_rate: 0.0,
      post_login_reveal_count: 0,
      guest_login_attempt_count: 0
    }
  end

  def default_breakdowns
    {
      guest_vs_authenticated: {
        guest: 0,
        authenticated: 0
      },
      by_event_type: {},
      by_category: [],
      by_subcategory: []
    }
  end

  # Get contact counts for all ads
  def contact_counts_by_ad
    apply_filters(base_query)
      .where(event_type: 'Reveal-Seller-Details')
      .where("metadata->>'action' = 'seller_contact_interaction'")
      .group(:ad_id)
      .count
  end

  # Get click events analytics aggregated by shop/seller
  def shop_click_analytics(page: 1, per_page: 50)
    page = [page.to_i, 1].max
    per_page = [[per_page.to_i, 1].max, 500].min

    offset = (page - 1) * per_page

    # Get seller stats with proper aggregation
    seller_stats_query = apply_filters(base_query)
      .joins(ad: :seller)
      .select(
        "sellers.id as seller_id",
        "COALESCE(sellers.enterprise_name, sellers.fullname) as seller_name",
        "COUNT(*) as total_events",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Ad-Click') as ad_clicks",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Reveal-Seller-Details') as reveal_events",
        "COUNT(*) FILTER (WHERE click_events.event_type = 'Reveal-Seller-Details' AND click_events.metadata->>'action' = 'seller_contact_interaction') as contact_events",
        "COUNT(DISTINCT click_events.ad_id) as ads_count",
        "MAX(click_events.created_at) as last_activity"
      )
      .group("sellers.id", "COALESCE(sellers.enterprise_name, sellers.fullname)")
      .order("total_events DESC")

    # Get total count for pagination
    total_shops = seller_stats_query.count.length

    # Apply pagination and map results
    shops = seller_stats_query.offset(offset).limit(per_page).map do |stat|
      {
        seller_id: stat.seller_id,
        seller_name: stat.seller_name,
        total_events: stat.total_events.to_i,
        ad_clicks: stat.ad_clicks.to_i,
        reveal_events: stat.reveal_events.to_i,
        contact_events: stat.contact_events.to_i,
        ads_count: stat.ads_count.to_i,
        last_activity: stat.last_activity&.iso8601,
        # Calculate rates
        reveal_rate: stat.total_events.to_i > 0 ? (stat.reveal_events.to_f / stat.total_events.to_f * 100).round(1) : 0.0,
        contact_rate: stat.reveal_events.to_i > 0 ? (stat.contact_events.to_f / stat.reveal_events.to_f * 100).round(1) : 0.0
      }
    end

    total_pages = (total_shops.to_f / per_page).ceil

    {
      shops: shops,
      pagination: {
        page: page,
        per_page: per_page,
        total_count: total_shops,
        total_pages: total_pages,
        has_next_page: page < total_pages,
        has_prev_page: page > 1
      },
      summary: {
        total_shops: total_shops,
        total_events: shops.sum { |s| s[:total_events] },
        total_contacts: shops.sum { |s| s[:contact_events] },
        avg_contact_rate: shops.any? ? (shops.sum { |s| s[:contact_rate] } / shops.length).round(1) : 0.0
      }
    }
  end
end

