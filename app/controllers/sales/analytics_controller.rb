# app/controllers/sales/analytics_controller.rb
require 'set'

class Sales::AnalyticsController < ApplicationController
  before_action :authenticate_sales_user

  def index
    # Get list of excluded emails/domains for filtering
    excluded_email_patterns = InternalUserExclusion.active
                                                    .by_type('email_domain')
                                                    .pluck(:identifier_value)
    
    # OPTIMIZATION: Limit timestamp queries to last 2 years for performance
    # Frontend can request older data if needed via date filters
    timestamp_limit_date = 2.years.ago
    
    # Get all data without time filtering for totals
    # Exclude sellers with excluded email domains
    all_sellers = exclude_emails_by_pattern(Seller.where(deleted: false), excluded_email_patterns)
    # Exclude buyers with excluded email domains
    all_buyers = exclude_emails_by_pattern(Buyer.where(deleted: false), excluded_email_patterns)
    
    # OPTIMIZATION: Use single query with conditional aggregation for signup method breakdowns
    buyers_signup_breakdown = all_buyers
      .reorder(nil) # Remove any existing ORDER BY clauses
      .select(
        "COUNT(*) as total",
        "COUNT(*) FILTER (WHERE provider IS NOT NULL AND provider != '') as google_oauth",
        "COUNT(*) FILTER (WHERE provider IS NULL OR provider = '') as regular"
      )
      .take
    
    sellers_signup_breakdown = all_sellers
      .reorder(nil) # Remove any existing ORDER BY clauses
      .select(
        "COUNT(*) as total",
        "COUNT(*) FILTER (WHERE provider IS NOT NULL AND provider != '') as google_oauth",
        "COUNT(*) FILTER (WHERE provider IS NULL OR provider = '') as regular"
      )
      .take
    
    # Separate buyers by signup method (Google OAuth vs Regular) - only for timestamps
    google_oauth_buyers = all_buyers.where.not(provider: nil).where("provider != ''")
    regular_buyers = all_buyers.where("provider IS NULL OR provider = ''")
    
    # Separate sellers by signup method (Google OAuth vs Regular) - only for timestamps
    google_oauth_sellers = all_sellers.where.not(provider: nil).where("provider != ''")
    regular_sellers = all_sellers.where("provider IS NULL OR provider = ''")
    
    all_ads = Ad.where(deleted: false)
    all_reviews = Review.all
    all_wishlists = WishList.all
    
    # Get seller tiers without time filtering for totals
    all_paid_seller_tiers = SellerTier
      .joins(:seller)
      .where(tier_id: [2, 3, 4], sellers: { deleted: false })
    
    all_unpaid_seller_tiers = SellerTier
      .joins(:seller)
      .where(tier_id: 1, sellers: { deleted: false })
    
    # Get device_hash from params or headers if available for excluding seller own clicks
    device_hash = params[:device_hash] || request.headers['X-Device-Hash']
    
    # Get click events without time filtering for totals (excluding internal users, deleted buyers, and seller own clicks)
    # Includes ALL clicks (guest + authenticated) for both "Total Ads Clicks" and "Buyer Engagement"
    # Guest clicks have buyer_id = nil, so they're included in the query
    # Exclude clicks with deleted ads or clicks without ads to match category analytics
    all_ad_clicks = ClickEvent
      .excluding_internal_users
      .excluding_seller_own_clicks(device_hash: device_hash, seller_id: nil)
      .where(event_type: 'Ad-Click')
      .left_joins(:buyer)
      .joins(:ad) # Use inner join to exclude clicks without ads
      .where("buyers.id IS NULL OR buyers.deleted = ?", false) # Include guest clicks (buyer_id IS NULL) or non-deleted buyers
      .where(ads: { deleted: false }) # Exclude clicks with deleted ads
    # Get reveal click events without time filtering for totals (excluding internal users, deleted buyers, and seller own clicks)
    # Includes ALL reveal clicks (guest + authenticated) for both "Total Click Reveals" and "Buyer Engagement"
    # Exclude clicks with deleted ads or clicks without ads to match category analytics
    all_reveal_clicks = ClickEvent
      .excluding_internal_users
      .excluding_seller_own_clicks(device_hash: device_hash, seller_id: nil)
      .where(event_type: 'Reveal-Seller-Details')
      .left_joins(:buyer)
      .joins(:ad) # Use inner join to exclude clicks without ads
      .where("buyers.id IS NULL OR buyers.deleted = ?", false) # Include guest clicks (buyer_id IS NULL) or non-deleted buyers
      .where(ads: { deleted: false }) # Exclude clicks with deleted ads
    
    # OPTIMIZATION: Limit timestamp queries to recent data only (last 2 years)
    # Convert timestamps to ISO 8601 format for proper JavaScript Date parsing
    sellers_with_timestamps = all_sellers.where('created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    buyers_with_timestamps = all_buyers.where('created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    
    # Separate timestamps by signup method for time-series tracking (limited to recent)
    google_oauth_buyers_with_timestamps = google_oauth_buyers.where('created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    regular_buyers_with_timestamps = regular_buyers.where('created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    google_oauth_sellers_with_timestamps = google_oauth_sellers.where('created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    regular_sellers_with_timestamps = regular_sellers.where('created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    
    ads_with_timestamps = all_ads.where('created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    reviews_with_timestamps = all_reviews.where('created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    wishlists_with_timestamps = all_wishlists.where('created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    
    # Get seller tiers with timestamps (limited to recent)
    paid_seller_tiers_with_timestamps = all_paid_seller_tiers
      .where('sellers.created_at >= ?', timestamp_limit_date)
      .pluck('sellers.created_at')
      .map { |ts| ts&.iso8601 }
    
    unpaid_seller_tiers_with_timestamps = all_unpaid_seller_tiers
      .where('sellers.created_at >= ?', timestamp_limit_date)
      .pluck('sellers.created_at')
      .map { |ts| ts&.iso8601 }
    
    # OPTIMIZATION: Get click events with timestamps (limited to recent, remove duplicates)
    ad_clicks_with_timestamps = all_ad_clicks.where('click_events.created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    # Remove duplicate - buyer_ad_clicks uses same data
    buyer_ad_clicks_with_timestamps = ad_clicks_with_timestamps
    
    # OPTIMIZATION: Get reveal clicks with timestamps (limited to recent, remove duplicates)
    reveal_clicks_with_timestamps = all_reveal_clicks.where('click_events.created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    # Remove duplicate - buyer_reveal_clicks uses same data
    buyer_reveal_clicks_with_timestamps = reveal_clicks_with_timestamps
    
    # Use unified service for category click events
    # device_hash already extracted above
    click_events_service = ClickEventsAnalyticsService.new(
      filters: {},
      device_hash: device_hash
    )
    category_click_events = click_events_service.category_click_events

    # Use unified service for subcategory click events
    subcategory_click_events = click_events_service.subcategory_click_events

    # Get source tracking analytics (with error handling)
    source_analytics = begin
      get_source_analytics
    rescue => e
      Rails.logger.error "Error getting source analytics: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Return minimal structure on error to prevent blocking
      {
        total_visits: 0,
        unique_visitors: 0,
        returning_visitors: 0,
        new_visitors: 0,
        avg_visits_per_visitor: 0,
        source_distribution: {},
        other_sources_count: 0,
        incomplete_utm_count: 0,
        unique_visitors_by_source: {},
        visits_by_source: {},
        utm_source_distribution: {},
        utm_medium_distribution: {},
        utm_campaign_distribution: {},
        utm_content_distribution: {},
        utm_term_distribution: {},
        referrer_distribution: {},
        daily_visits: {},
        visit_timestamps: [],
        daily_unique_visitors: {},
        top_sources: [],
        top_referrers: []
      }
    end
    
    # Get device analytics (with error handling)
    device_analytics = begin
      get_device_analytics
    rescue => e
      Rails.logger.error "Error getting device analytics: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Return empty device analytics on error to prevent blocking the entire response
      {
        device_types: {},
        browsers: {},
        operating_systems: {},
        screen_resolutions: {},
        device_types_visitors: {},
        browsers_visitors: {},
        operating_systems_visitors: {},
        device_types_total: {},
        browsers_total: {},
        operating_systems_total: {},
        screen_resolutions_total: {},
        device_types_time_series: [],
        browsers_time_series: [],
        operating_systems_time_series: [],
        total_devices: 0,
        total_sessions: 0,
        total_visitors: 0,
        total_records: 0
      }
    end
    
    # Analytics data prepared successfully
    
    # Get current quarter targets
    sellers_target = QuarterlyTarget.current_target_for('total_sellers')
    buyers_target = QuarterlyTarget.current_target_for('total_buyers')
    ads_target = QuarterlyTarget.current_target_for('total_ads')
    reveal_clicks_target = QuarterlyTarget.current_target_for('total_reveal_clicks')
    
    response_data = {
      # Raw data with timestamps for frontend filtering (ALL data, no time restriction)
      sellers_with_timestamps: sellers_with_timestamps,
      buyers_with_timestamps: buyers_with_timestamps,
      ads_with_timestamps: ads_with_timestamps,
      reviews_with_timestamps: reviews_with_timestamps,
      
      # Quarterly targets
      targets: {
        total_sellers: sellers_target ? {
          id: sellers_target.id,
          target_value: sellers_target.target_value,
          year: sellers_target.year,
          quarter: sellers_target.quarter,
          status: sellers_target.status,
          notes: sellers_target.notes
        } : nil,
        total_buyers: buyers_target ? {
          id: buyers_target.id,
          target_value: buyers_target.target_value,
          year: buyers_target.year,
          quarter: buyers_target.quarter,
          status: buyers_target.status,
          notes: buyers_target.notes
        } : nil,
        total_ads: ads_target ? {
          id: ads_target.id,
          target_value: ads_target.target_value,
          year: ads_target.year,
          quarter: ads_target.quarter,
          status: ads_target.status,
          notes: ads_target.notes
        } : nil,
        total_reveal_clicks: reveal_clicks_target ? {
          id: reveal_clicks_target.id,
          target_value: reveal_clicks_target.target_value,
          year: reveal_clicks_target.year,
          quarter: reveal_clicks_target.quarter,
          status: reveal_clicks_target.status,
          notes: reveal_clicks_target.notes
        } : nil
      },
      wishlists_with_timestamps: wishlists_with_timestamps,
      paid_seller_tiers_with_timestamps: paid_seller_tiers_with_timestamps,
      unpaid_seller_tiers_with_timestamps: unpaid_seller_tiers_with_timestamps,
      ad_clicks_with_timestamps: ad_clicks_with_timestamps,
      buyer_ad_clicks_with_timestamps: buyer_ad_clicks_with_timestamps,
      buyer_reveal_clicks_with_timestamps: buyer_reveal_clicks_with_timestamps,
      reveal_clicks_with_timestamps: reveal_clicks_with_timestamps,
      category_click_events: category_click_events,
      subcategory_click_events: subcategory_click_events,
      
      # Signup method breakdown timestamps (for time-series tracking)
      google_oauth_buyers_with_timestamps: google_oauth_buyers_with_timestamps,
      regular_buyers_with_timestamps: regular_buyers_with_timestamps,
      google_oauth_sellers_with_timestamps: google_oauth_sellers_with_timestamps,
      regular_sellers_with_timestamps: regular_sellers_with_timestamps,
      
      # OPTIMIZATION: Pre-calculated totals for initial display (all time)
      # Use cached counts from signup breakdown queries where possible
      total_sellers: sellers_signup_breakdown&.total.to_i || all_sellers.count,
      total_buyers: buyers_signup_breakdown&.total.to_i || all_buyers.count,
      total_ads: all_ads.count,
      total_reviews: all_reviews.count,
      total_ads_wish_listed: all_wishlists.count,
      subscription_countdowns: all_paid_seller_tiers.count,
      without_subscription: all_unpaid_seller_tiers.count,
      total_ads_clicks: all_ad_clicks.count,
      buyer_ad_clicks: all_ad_clicks.count, # Same as total_ads_clicks - both use the same query
      buyer_reveal_clicks: all_reveal_clicks.count, # Same as total_reveal_clicks - both use the same query
      total_reveal_clicks: all_reveal_clicks.count,
      
      # OPTIMIZATION: Signup method breakdown totals (from single aggregated query)
      signup_method_breakdown: {
        buyers: {
          google_oauth: buyers_signup_breakdown&.google_oauth.to_i || 0,
          regular: buyers_signup_breakdown&.regular.to_i || 0,
          total: buyers_signup_breakdown&.total.to_i || all_buyers.count
        },
        sellers: {
          google_oauth: sellers_signup_breakdown&.google_oauth.to_i || 0,
          regular: sellers_signup_breakdown&.regular.to_i || 0,
          total: sellers_signup_breakdown&.total.to_i || all_sellers.count
        }
      },
      
      # Source tracking analytics
      source_analytics: source_analytics,
      
      # Device analytics
      device_analytics: device_analytics
    }
    
    render json: response_data
  end

  def devices
    # Get device analytics only - much faster than full analytics endpoint
    begin
      device_analytics = get_device_analytics
      render json: { device_analytics: device_analytics }
    rescue => e
      Rails.logger.error "Error getting device analytics: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { 
        device_analytics: {
          device_types: {},
          browsers: {},
          operating_systems: {},
          screen_resolutions: {},
          device_types_visitors: {},
          browsers_visitors: {},
          operating_systems_visitors: {},
          device_types_total: {},
          browsers_total: {},
          operating_systems_total: {},
          screen_resolutions_total: {},
          device_types_time_series: [],
          browsers_time_series: [],
          operating_systems_time_series: [],
          total_devices: 0,
          total_sessions: 0,
          total_visitors: 0,
          total_records: 0
        }
      }
    end
  end

  def recent_users
    user_type = params[:type] || 'buyers' # Default to buyers
    limit = params[:limit]&.to_i || 10
    
    if user_type == 'sellers'
      users = Seller.where(deleted: false)
                    .includes(:seller_tier, :tier, :ads, :reviews)
                    .order(created_at: :desc)
                    .limit(limit)
      
      # Get list of excluded email patterns for filtering (include hardcoded exclusions)
      hardcoded_excluded_emails = ['sales@example.com', 'shangwejunior5@gmail.com']
      hardcoded_excluded_domains = ['example.com']
      excluded_email_patterns = (hardcoded_excluded_emails + hardcoded_excluded_domains + InternalUserExclusion.active
                                                     .by_type('email_domain')
                                                     .pluck(:identifier_value)).uniq
      
      # Filter out excluded sellers (by exact email or domain)
      users = exclude_emails_by_pattern(users, excluded_email_patterns) if excluded_email_patterns.any?
      
      users_data = users.map do |seller|
        active_ads = seller.ads.where(deleted: false).count
        total_reviews = seller.reviews.count
        avg_rating = seller.calculate_mean_rating
        tier_name = seller.seller_tier&.tier&.name || 'Free'
        signup_method = seller.oauth_user? ? 'google_oauth' : 'regular'
        
        {
          id: seller.id,
          name: seller.fullname,
          enterprise_name: seller.enterprise_name,
          email: seller.email,
          phone: seller.phone_number,
          location: seller.location,
          profile_picture: seller.profile_picture,
          created_at: seller.created_at&.iso8601,
          type: 'seller',
          signup_method: signup_method,
          stats: {
            ads_count: active_ads,
            reviews_count: total_reviews,
            avg_rating: avg_rating.round(1),
            tier: tier_name
          }
        }
      end
    else
      users = Buyer.where(deleted: false)
                   .includes(:click_events, :wish_lists, :reviews)
                   .order(created_at: :desc)
                   .limit(limit)
      
      # Get list of excluded email patterns for filtering (include hardcoded exclusions)
      hardcoded_excluded_emails = ['sales@example.com', 'shangwejunior5@gmail.com']
      hardcoded_excluded_domains = ['example.com']
      excluded_email_patterns = (hardcoded_excluded_emails + hardcoded_excluded_domains + InternalUserExclusion.active
                                                     .by_type('email_domain')
                                                     .pluck(:identifier_value)).uniq
      
      # Filter out excluded buyers (by exact email or domain)
      users = exclude_emails_by_pattern(users, excluded_email_patterns) if excluded_email_patterns.any?
      
      users_data = users.map do |buyer|
        # Count clicks directly associated with buyer
        direct_clicks = buyer.click_events.where(event_type: 'Ad-Click').count
        
        # Also count guest clicks for ads the buyer has messaged about
        # This handles cases where buyer clicked as guest before authenticating
        conversation_ad_ids = Conversation.where(buyer_id: buyer.id).where.not(ad_id: nil).pluck(:ad_id).uniq
        guest_clicks_for_ads = ClickEvent
          .where(ad_id: conversation_ad_ids)
          .where(buyer_id: nil, event_type: 'Ad-Click')
          .where('created_at <= ?', buyer.created_at + 24.hours) # Within 24 hours of account creation
          .count
        
        clicks_count = direct_clicks + guest_clicks_for_ads
        
        # Same for reveals
        direct_reveals = buyer.click_events.where(event_type: 'Reveal-Seller-Details').count
        guest_reveals_for_ads = ClickEvent
          .where(ad_id: conversation_ad_ids)
          .where(buyer_id: nil, event_type: 'Reveal-Seller-Details')
          .where('created_at <= ?', buyer.created_at + 24.hours)
          .count
        
        reveals_count = direct_reveals + guest_reveals_for_ads
        wishlist_count = buyer.wish_lists.count
        reviews_count = buyer.reviews.count
        signup_method = buyer.oauth_user? ? 'google_oauth' : 'regular'
        
        {
          id: buyer.id,
          name: buyer.fullname,
          email: buyer.email,
          phone: buyer.phone_number,
          location: buyer.location,
          profile_picture: buyer.profile_picture,
          created_at: buyer.created_at&.iso8601,
          type: 'buyer',
          signup_method: signup_method,
          stats: {
            clicks_count: clicks_count,
            reveals_count: reveals_count,
            wishlist_count: wishlist_count,
            reviews_count: reviews_count
          }
        }
      end
    end
    
    render json: { users: users_data, type: user_type, count: users_data.count }
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def get_source_analytics
    # Get date parameters for filtering
    start_date = params[:start_date]
    end_date = params[:end_date]
    
    
    # Build date filter
    date_filter = nil
    if start_date && end_date
      date_filter = { start_date: start_date, end_date: end_date }
    else
    end
    
    # Get source tracking data with optional date filtering
    source_distribution = Analytic.source_distribution(date_filter)
    utm_source_distribution = Analytic.utm_source_distribution(date_filter)
    utm_medium_distribution = Analytic.utm_medium_distribution(date_filter)
    utm_campaign_distribution = Analytic.utm_campaign_distribution(date_filter)
    utm_content_distribution = Analytic.utm_content_distribution(date_filter)
    utm_term_distribution = Analytic.utm_term_distribution(date_filter)
    referrer_distribution = Analytic.referrer_distribution(date_filter)
    
    # Get visitor engagement metrics with date filtering
    visitor_metrics = Analytic.visitor_engagement_metrics(date_filter)
    
    # Get unique visitors by source with date filtering
    unique_visitors_by_source = Analytic.unique_visitors_by_source(date_filter)
    visits_by_source = Analytic.visits_by_source(date_filter)
    
    # Get visits by day with date filtering (excluding internal users)
    if date_filter
      daily_visits = Analytic.excluding_internal_users.date_range(date_filter[:start_date], date_filter[:end_date])
                             .group("DATE(created_at)")
                             .order("DATE(created_at)")
                             .count
    else
      daily_visits = Analytic.excluding_internal_users
                             .group("DATE(created_at)")
                             .order("DATE(created_at)")
                             .count
    end
    
    # OPTIMIZATION: Get visit timestamps with date filtering (excluding internal users)
    # Limit to last 2 years if no date filter specified for performance
    if date_filter
      visit_timestamps = Analytic.excluding_internal_users.date_range(date_filter[:start_date], date_filter[:end_date])
                                 .pluck(:created_at)
                                 .map { |ts| ts&.iso8601 }
    else
      # Limit to last 2 years for performance
      two_years_ago = 2.years.ago
      visit_timestamps = Analytic.excluding_internal_users
                                 .where('created_at >= ?', two_years_ago)
                                 .pluck(:created_at)
                                 .map { |ts| ts&.iso8601 }
    end
    
    # Get unique visitors trend with date filtering
    daily_unique_visitors = Analytic.unique_visitors_trend(date_filter)
    
    # Get top sources and referrers
    top_sources = source_distribution.sort_by { |_, count| -count }.first(10)
    top_referrers = referrer_distribution.sort_by { |_, count| -count }.first(10)
    
    # Calculate total_visits as sum of source_distribution to match frontend expectations
    # This ensures consistency: total_visits = sum of all source_distribution values
    total_visits_from_sources = source_distribution.values.sum
    
    # Note: "other" sources and "incomplete UTM" records have been removed via migration
    # These categories were misleading and have been cleaned up
    other_sources_count = 0
    incomplete_utm_count = 0
    
    {
      total_visits: total_visits_from_sources,
      unique_visitors: visitor_metrics[:unique_visitors],
      returning_visitors: visitor_metrics[:returning_visitors],
      new_visitors: visitor_metrics[:new_visitors],
      avg_visits_per_visitor: visitor_metrics[:avg_visits_per_visitor],
      source_distribution: source_distribution,
      other_sources_count: other_sources_count,
      incomplete_utm_count: incomplete_utm_count,
      unique_visitors_by_source: unique_visitors_by_source,
      visits_by_source: visits_by_source,
      utm_source_distribution: utm_source_distribution,
      utm_medium_distribution: utm_medium_distribution,
      utm_campaign_distribution: utm_campaign_distribution,
      utm_content_distribution: utm_content_distribution,
      utm_term_distribution: utm_term_distribution,
      referrer_distribution: referrer_distribution,
      daily_visits: daily_visits,
      visit_timestamps: visit_timestamps,
      daily_unique_visitors: daily_unique_visitors,
      top_sources: top_sources,
      top_referrers: top_referrers
    }
  end

  def get_device_analytics
    # Optimized: Parse unique user agents only once, use SQL aggregations where possible
    # Limit to recent records for performance (last 6 months)
    six_months_ago = 6.months.ago
    base_query = ClickEvent.excluding_internal_users
      .left_joins(:ad)
      .where("ads.id IS NULL OR ads.deleted = ?", false)
      .where.not(metadata: nil)
      .where('click_events.created_at >= ?', six_months_ago)
    
    # Session identifier (device_hash or buyer_id)
    session_id_sql = "COALESCE(metadata->>'device_hash', buyer_id::text, 'unknown')"
    visitor_id_sql = "COALESCE(buyer_id::text, metadata->>'device_hash', 'unknown')"
    
    # All records now have user_agent_details stored, so no parsing needed
    query_with_ua = base_query.where("metadata->>'user_agent' IS NOT NULL OR metadata->'user_agent_details' IS NOT NULL")
    
    device_types_sessions = Hash.new { |h, k| h[k] = Set.new }
    browsers_sessions = Hash.new { |h, k| h[k] = Set.new }
    operating_systems_sessions = Hash.new { |h, k| h[k] = Set.new }
    screen_resolutions_sessions = Hash.new { |h, k| h[k] = Set.new }
    
    device_types_visitors = Hash.new { |h, k| h[k] = Set.new }
    browsers_visitors = Hash.new { |h, k| h[k] = Set.new }
    operating_systems_visitors = Hash.new { |h, k| h[k] = Set.new }
    
    device_types_total = Hash.new(0)
    browsers_total = Hash.new(0)
    operating_systems_total = Hash.new(0)
    screen_resolutions_total = Hash.new(0)
    
    # Time-series data (last 90 days)
    start_date = 90.days.ago.beginning_of_day
    device_types_by_date = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = Set.new } }
    browsers_by_date = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = Set.new } }
    operating_systems_by_date = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = Set.new } }
    
    # Use pluck for faster data access (avoids ActiveRecord object overhead)
    query_with_ua.pluck(
      Arel.sql("metadata->>'user_agent'"),
      :metadata,
      Arel.sql("#{session_id_sql}"),
      Arel.sql("#{visitor_id_sql}"),
      :created_at
    ).each do |user_agent_string, metadata_hash, session_id, visitor_id, created_at|
      next if session_id == 'unknown' && visitor_id == 'unknown'
      
      # Fast path: Check if user_agent_details exists first (no parsing needed)
      user_agent_details = metadata_hash['user_agent_details'] || metadata_hash[:user_agent_details]
      
      if user_agent_details && (user_agent_details['browser'] || user_agent_details[:browser])
        # Use existing parsed data - fastest path (no parsing)
        browser = user_agent_details['browser'] || user_agent_details[:browser] || 'Unknown'
        os = user_agent_details['os'] || user_agent_details[:os] || 'Unknown'
        device_type_raw = user_agent_details['device_type'] || user_agent_details[:device_type]
        device_type = if device_type_raw
          normalize_device_type(device_type_raw)
        elsif user_agent_details['is_mobile'] || user_agent_details[:is_mobile]
          'Phone'
        elsif user_agent_details['is_tablet'] || user_agent_details[:is_tablet]
          'Tablet'
        elsif user_agent_details['is_desktop'] || user_agent_details[:is_desktop]
          'Desktop'
        else
          'Desktop'
        end
      elsif user_agent_string.present?
        # Fallback: Parse on-the-fly if user_agent_details is missing (shouldn't happen after backfill)
        parsed_ua = parse_user_agent_for_analytics(user_agent_string, {})
        browser = parsed_ua[:browser] || 'Unknown'
        os = parsed_ua[:os] || 'Unknown'
        device_type = normalize_device_type(parsed_ua[:device_type])
      else
        # No user agent data
        browser = 'Unknown'
        os = 'Unknown'
        device_type = 'Desktop'
      end
      
      # Screen resolution from device_fingerprint (optimized hash access)
      device_fingerprint = metadata_hash['device_fingerprint'] || metadata_hash[:device_fingerprint]
      if device_fingerprint
        screen_width = device_fingerprint['screen_width'] || device_fingerprint[:screen_width]
        screen_height = device_fingerprint['screen_height'] || device_fingerprint[:screen_height]
        resolution = (screen_width && screen_height) ? "#{screen_width}x#{screen_height}" : nil
      else
        resolution = nil
      end
        
        # Track unique sessions (optimized - single conditional check)
        if session_id.present?
          device_types_sessions[device_type].add(session_id)
          browsers_sessions[browser].add(session_id)
          operating_systems_sessions[os].add(session_id)
          screen_resolutions_sessions[resolution].add(session_id) if resolution.present?
        end
        
        # Track unique visitors
        if visitor_id.present?
          device_types_visitors[device_type].add(visitor_id)
          browsers_visitors[browser].add(visitor_id)
          operating_systems_visitors[os].add(visitor_id)
        end
        
        # Track total counts
        device_types_total[device_type] += 1
        browsers_total[browser] += 1
        operating_systems_total[os] += 1
        screen_resolutions_total[resolution] += 1 if resolution.present?
        
        # Time-series data (last 90 days) - only if needed
        if created_at && created_at >= start_date && session_id.present?
          date_key = created_at.to_date.iso8601
          device_types_by_date[date_key][device_type].add(session_id)
          browsers_by_date[date_key][browser].add(session_id)
          operating_systems_by_date[date_key][os].add(session_id)
        end
      end
    
    # Convert Sets to counts
    device_types_unique_sessions = device_types_sessions.transform_values(&:size)
    browsers_unique_sessions = browsers_sessions.transform_values(&:size)
    operating_systems_unique_sessions = operating_systems_sessions.transform_values(&:size)
    screen_resolutions_unique_sessions = screen_resolutions_sessions.transform_values(&:size)
    
    device_types_unique_visitors = device_types_visitors.transform_values(&:size)
    browsers_unique_visitors = browsers_visitors.transform_values(&:size)
    operating_systems_unique_visitors = operating_systems_visitors.transform_values(&:size)
    
    # Count unique sessions
    total_sessions_count = base_query
      .where("metadata->>'device_hash' IS NOT NULL OR buyer_id IS NOT NULL")
      .distinct
      .count(Arel.sql("#{session_id_sql}"))
    
    # Generate time-series arrays
    device_types_time_series = build_time_series(device_types_by_date, device_types_unique_sessions.keys, start_date)
    browsers_time_series = build_time_series(browsers_by_date, browsers_unique_sessions.keys, start_date)
    operating_systems_time_series = build_time_series(operating_systems_by_date, operating_systems_unique_sessions.keys, start_date)
    
    {
      # Unique sessions (primary metric - one per session)
      device_types: device_types_unique_sessions,
      browsers: browsers_unique_sessions,
      operating_systems: operating_systems_unique_sessions,
      screen_resolutions: screen_resolutions_unique_sessions,
      
      # Unique visitors (alternative metric - one per visitor across all sessions)
      device_types_visitors: device_types_unique_visitors,
      browsers_visitors: browsers_unique_visitors,
      operating_systems_visitors: operating_systems_unique_visitors,
      
      # Total counts (for reference)
      device_types_total: device_types_total,
      browsers_total: browsers_total,
      operating_systems_total: operating_systems_total,
      screen_resolutions_total: screen_resolutions_total.reject { |k, v| k.nil? },
      
      # Time-series data for area charts (last 90 days)
      device_types_time_series: device_types_time_series,
      browsers_time_series: browsers_time_series,
      operating_systems_time_series: operating_systems_time_series,
      
      # Summary stats
      total_devices: total_sessions_count, # Total unique device sessions (for frontend compatibility)
      total_sessions: total_sessions_count,
      total_visitors: base_query.where("buyer_id IS NOT NULL OR metadata->>'device_hash' IS NOT NULL")
        .distinct
        .count(Arel.sql("#{visitor_id_sql}")),
      total_records: base_query.count
    }
  end

  # Build time-series data from pre-grouped hash
  def build_time_series(date_hash, unique_categories, start_date)
    return [] if unique_categories.empty?
    
    time_series = []
    (start_date.to_date..Date.today).each do |date|
      date_str = date.iso8601
      data_point = { date: date_str }
      unique_categories.each do |category|
        data_point[category] = date_hash[date_str][category]&.size || 0
      end
      time_series << data_point
    end
    
    time_series
  end
  
  # Normalize device type to match frontend expectations (optimized)
  def normalize_device_type(device_type)
    return 'Desktop' unless device_type
    
    case device_type.to_s.downcase
    when 'mobile' then 'Phone'
    when 'tablet' then 'Tablet'
    when 'desktop' then 'Desktop'
    else device_type.to_s.capitalize
    end
  end

  # Parse user agent using user_agent_parser gem (reuses logic from ClickEventsAnalyticsService)
  def parse_user_agent_for_analytics(user_agent_string, metadata_hash = {})
    # First check if user_agent_details already exists in metadata
    user_agent_details = metadata_hash['user_agent_details'] || metadata_hash[:user_agent_details] || {}
    
    if user_agent_details.present? && (user_agent_details['browser'] || user_agent_details[:browser])
      # Use existing parsed data
      device_type = user_agent_details['device_type'] || user_agent_details[:device_type] ||
                   (user_agent_details['is_mobile'] || user_agent_details[:is_mobile] ? 'mobile' :
                    user_agent_details['is_tablet'] || user_agent_details[:is_tablet] ? 'tablet' :
                    user_agent_details['is_desktop'] || user_agent_details[:is_desktop] ? 'desktop' : 'unknown')
      
      return {
        browser: user_agent_details['browser'] || user_agent_details[:browser] || 'Unknown',
        os: user_agent_details['os'] || user_agent_details[:os] || 'Unknown',
        device_type: device_type
      }
    end
    
    # Parse user_agent string using gem
    return { browser: 'Unknown', os: 'Unknown', device_type: 'unknown' } unless user_agent_string.present?
    
    begin
      require 'user_agent_parser'
      parser = UserAgentParser.parse(user_agent_string)
      
      browser_name = parser.family || 'Unknown'
      os_family = parser.os&.family || 'Unknown'
      
      # Detect device type
      user_agent_lower = user_agent_string.downcase
      device_type = if user_agent_lower.match?(/mobile|android|iphone|ipod|blackberry|opera mini|iemobile|wpdesktop/i)
        'mobile'
      elsif user_agent_lower.match?(/tablet|ipad|playbook|silk/i) && !user_agent_lower.match?(/mobile/i)
        'tablet'
      else
        'desktop'
      end
      
      {
        browser: browser_name,
        os: os_family,
        device_type: device_type
      }
    rescue LoadError, StandardError => e
      # Fallback to basic detection if gem fails
      Rails.logger.warn "User agent parser failed for '#{user_agent_string}': #{e.message}"
      user_agent_lower = user_agent_string.downcase
      
      browser = if user_agent_lower.include?('chrome') && !user_agent_lower.include?('edg')
        'Chrome'
      elsif user_agent_lower.include?('edg')
        'Edge'
      elsif user_agent_lower.include?('firefox')
        'Firefox'
      elsif user_agent_lower.include?('safari') && !user_agent_lower.include?('chrome')
        'Safari'
      elsif user_agent_lower.include?('opera') || user_agent_lower.include?('opr')
        'Opera'
      elsif user_agent_lower.include?('msie') || user_agent_lower.include?('trident')
        'Internet Explorer'
      else
        'Unknown'
      end
      
      os = if user_agent_lower.include?('windows')
        'Windows'
      elsif user_agent_lower.include?('mac os') || user_agent_lower.include?('macintosh')
        'macOS'
      elsif user_agent_lower.include?('linux') && !user_agent_lower.include?('android')
        'Linux'
      elsif user_agent_lower.include?('android')
        'Android'
      elsif user_agent_lower.include?('iphone') || user_agent_lower.include?('ipad') || user_agent_lower.include?('ipod')
        'iOS'
      else
        'Unknown'
      end
      
      device_type = if user_agent_lower.match?(/mobile|android|iphone|ipod|blackberry|opera mini|iemobile|wpdesktop/i)
        'mobile'
      elsif user_agent_lower.match?(/tablet|ipad|playbook|silk/i) && !user_agent_lower.match?(/mobile/i)
        'tablet'
      else
        'desktop'
      end
      
      {
        browser: browser,
        os: os,
        device_type: device_type
      }
    end
  end

  # Helper method to exclude emails by pattern (exact match or domain match)
  def exclude_emails_by_pattern(scope, email_patterns)
    return scope if email_patterns.empty?
    
    query = scope
    email_patterns.each do |pattern|
      pattern_lower = pattern.downcase
      
      if pattern.include?('@')
        # This is an exact email pattern (e.g., "sales@example.com")
        # Only exclude this exact email, NOT all emails from that domain
        query = query.where.not('LOWER(email) = ?', pattern_lower)
      else
        # This is a domain-only pattern (e.g., "example.com")
        # Exclude all emails from this domain
        query = query.where.not('LOWER(email) LIKE ?', "%@#{pattern_lower}")
      end
    end
    
    query
  end
end
