# app/controllers/sales/analytics_controller.rb
require 'set'

class Sales::AnalyticsController < ApplicationController
  before_action :authenticate_sales_user

  def index
    # Get list of excluded emails/domains for filtering
    excluded_email_patterns = InternalUserExclusion.active
                                                    .by_type('email_domain')
                                                    .pluck(:identifier_value)
    
    # Get all data without time filtering for totals
    # Exclude sellers with excluded email domains
    all_sellers = exclude_emails_by_pattern(Seller.where(deleted: false), excluded_email_patterns)
    # Exclude buyers with excluded email domains
    all_buyers = exclude_emails_by_pattern(Buyer.where(deleted: false), excluded_email_patterns)
    
    # Separate buyers by signup method (Google OAuth vs Regular)
    # Google OAuth users have a provider value (typically 'google')
    google_oauth_buyers = all_buyers.where.not(provider: nil).where("provider != ''")
    # Regular users have no provider (nil or empty string)
    regular_buyers = all_buyers.where("provider IS NULL OR provider = ''")
    
    # Separate sellers by signup method (Google OAuth vs Regular)
    # Google OAuth users have a provider value (typically 'google')
    google_oauth_sellers = all_sellers.where.not(provider: nil).where("provider != ''")
    # Regular users have no provider (nil or empty string)
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
    
    # Get click events without time filtering for totals (excluding internal users and deleted buyers)
    # Includes ALL clicks (guest + authenticated) for both "Total Ads Clicks" and "Buyer Engagement"
    # Guest clicks have buyer_id = nil, so they're included in the query
    # Exclude clicks with deleted ads or clicks without ads to match category analytics
    all_ad_clicks = ClickEvent
      .excluding_internal_users
      .where(event_type: 'Ad-Click')
      .left_joins(:buyer)
      .joins(:ad) # Use inner join to exclude clicks without ads
      .where("buyers.id IS NULL OR buyers.deleted = ?", false) # Include guest clicks (buyer_id IS NULL) or non-deleted buyers
      .where(ads: { deleted: false }) # Exclude clicks with deleted ads
    # Get reveal click events without time filtering for totals (excluding internal users and deleted buyers)
    # Includes ALL reveal clicks (guest + authenticated) for both "Total Click Reveals" and "Buyer Engagement"
    # Exclude clicks with deleted ads or clicks without ads to match category analytics
    all_reveal_clicks = ClickEvent
      .excluding_internal_users
      .where(event_type: 'Reveal-Seller-Details')
      .left_joins(:buyer)
      .joins(:ad) # Use inner join to exclude clicks without ads
      .where("buyers.id IS NULL OR buyers.deleted = ?", false) # Include guest clicks (buyer_id IS NULL) or non-deleted buyers
      .where(ads: { deleted: false }) # Exclude clicks with deleted ads
    
    # Convert all timestamps to ISO 8601 format for proper JavaScript Date parsing
    sellers_with_timestamps = all_sellers.pluck(:created_at).map { |ts| ts&.iso8601 }
    buyers_with_timestamps = all_buyers.pluck(:created_at).map { |ts| ts&.iso8601 }
    
    # Separate timestamps by signup method for time-series tracking
    google_oauth_buyers_with_timestamps = google_oauth_buyers.pluck(:created_at).map { |ts| ts&.iso8601 }
    regular_buyers_with_timestamps = regular_buyers.pluck(:created_at).map { |ts| ts&.iso8601 }
    google_oauth_sellers_with_timestamps = google_oauth_sellers.pluck(:created_at).map { |ts| ts&.iso8601 }
    regular_sellers_with_timestamps = regular_sellers.pluck(:created_at).map { |ts| ts&.iso8601 }
    
    ads_with_timestamps = all_ads.pluck(:created_at).map { |ts| ts&.iso8601 }
    reviews_with_timestamps = all_reviews.pluck(:created_at).map { |ts| ts&.iso8601 }
    wishlists_with_timestamps = all_wishlists.pluck(:created_at).map { |ts| ts&.iso8601 }
    
    # Get seller tiers with timestamps
    paid_seller_tiers_with_timestamps = all_paid_seller_tiers
      .pluck('sellers.created_at')
      .map { |ts| ts&.iso8601 }
    
    unpaid_seller_tiers_with_timestamps = all_unpaid_seller_tiers
      .pluck('sellers.created_at')
      .map { |ts| ts&.iso8601 }
    
    # Get click events with timestamps (used for both "Total Ads Clicks" and "Buyer Engagement")
    ad_clicks_with_timestamps = all_ad_clicks.pluck(:created_at).map { |ts| ts&.iso8601 }
    buyer_ad_clicks_with_timestamps = all_ad_clicks.pluck(:created_at).map { |ts| ts&.iso8601 }
    
    # Get reveal clicks with timestamps (used for both "Total Click Reveals" and "Buyer Engagement")
    reveal_clicks_with_timestamps = all_reveal_clicks.pluck(:created_at).map { |ts| ts&.iso8601 }
    buyer_reveal_clicks_with_timestamps = all_reveal_clicks.pluck(:created_at).map { |ts| ts&.iso8601 }
    
    # Use unified service for category click events
    click_events_service = ClickEventsAnalyticsService.new(filters: {})
    category_click_events = click_events_service.category_click_events

    # Use unified service for subcategory click events
    subcategory_click_events = click_events_service.subcategory_click_events

    # Get source tracking analytics
    source_analytics = get_source_analytics
    
    # Get device analytics
    device_analytics = get_device_analytics
    
    # Analytics data prepared successfully
    
    # Get current quarter targets
    sellers_target = QuarterlyTarget.current_target_for('total_sellers')
    buyers_target = QuarterlyTarget.current_target_for('total_buyers')
    
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
      
      # Pre-calculated totals for initial display (all time)
      total_sellers: all_sellers.count,
      total_buyers: all_buyers.count,
      total_ads: all_ads.count,
      total_reviews: all_reviews.count,
      total_ads_wish_listed: all_wishlists.count,
      subscription_countdowns: all_paid_seller_tiers.count,
      without_subscription: all_unpaid_seller_tiers.count,
      total_ads_clicks: all_ad_clicks.count,
      buyer_ad_clicks: all_ad_clicks.count, # Same as total_ads_clicks - both use the same query
      buyer_reveal_clicks: all_reveal_clicks.count, # Same as total_reveal_clicks - both use the same query
      total_reveal_clicks: all_reveal_clicks.count,
      
      # Signup method breakdown totals
      signup_method_breakdown: {
        buyers: {
          google_oauth: google_oauth_buyers.count,
          regular: regular_buyers.count,
          total: all_buyers.count
        },
        sellers: {
          google_oauth: google_oauth_sellers.count,
          regular: regular_sellers.count,
          total: all_sellers.count
        }
      },
      
      # Source tracking analytics
      source_analytics: source_analytics,
      
      # Device analytics
      device_analytics: device_analytics
    }
    
    render json: response_data
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
    
    # Get visit timestamps with date filtering (excluding internal users)
    if date_filter
      visit_timestamps = Analytic.excluding_internal_users.date_range(date_filter[:start_date], date_filter[:end_date])
                                 .pluck(:created_at)
                                 .map { |ts| ts&.iso8601 }
    else
      visit_timestamps = Analytic.excluding_internal_users.pluck(:created_at).map { |ts| ts&.iso8601 }
    end
    
    # Get unique visitors trend with date filtering
    daily_unique_visitors = Analytic.unique_visitors_trend(date_filter)
    
    # Get top sources and referrers
    top_sources = source_distribution.sort_by { |_, count| -count }.first(10)
    top_referrers = referrer_distribution.sort_by { |_, count| -count }.first(10)
    
    # Calculate total_visits as sum of source_distribution to match frontend expectations
    # This ensures consistency: total_visits = sum of all source_distribution values
    total_visits_from_sources = source_distribution.values.sum
    
    # Calculate "other" sources count (incomplete UTM - records with source='other')
    other_sources_count = source_distribution['other'] || 0
    
    {
      total_visits: total_visits_from_sources,
      unique_visitors: visitor_metrics[:unique_visitors],
      returning_visitors: visitor_metrics[:returning_visitors],
      new_visitors: visitor_metrics[:new_visitors],
      avg_visits_per_visitor: visitor_metrics[:avg_visits_per_visitor],
      source_distribution: source_distribution,
      other_sources_count: other_sources_count,
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
    # Get device analytics for ALL time (no 30-day restriction), excluding internal users
    all_analytics = Analytic.excluding_internal_users
    
    # Hash to track unique sessions per device/browser/OS
    device_type_sessions = Hash.new { |h, k| h[k] = Set.new }
    browser_sessions = Hash.new { |h, k| h[k] = Set.new }
    os_sessions = Hash.new { |h, k| h[k] = Set.new }
    resolution_sessions = Hash.new { |h, k| h[k] = Set.new }
    
    # Hash to track unique visitors per device/browser/OS
    device_type_visitors = Hash.new { |h, k| h[k] = Set.new }
    browser_visitors = Hash.new { |h, k| h[k] = Set.new }
    os_visitors = Hash.new { |h, k| h[k] = Set.new }
    
    # Total counts (for comparison)
    device_types_total = {}
    browsers_total = {}
    operating_systems_total = {}
    screen_resolutions_total = {}
    
    all_analytics.each do |analytic|
      next unless analytic.data && analytic.data['device']
      
      device_data = analytic.data['device']
      session_id = analytic.data['session_id']
      visitor_id = analytic.data['visitor_id']
      
      # Normalize device type (old "Mobile" to "Phone")
      device_type = device_data['device_type'] || 'Unknown'
      device_type = 'Phone' if device_type == 'Mobile'
      
      browser = device_data['browser'] || 'Unknown'
      os = device_data['os'] || 'Unknown'
      resolution = analytic.data['screen_resolution']
      
      # Track unique sessions
      device_type_sessions[device_type].add(session_id) if session_id.present?
      browser_sessions[browser].add(session_id) if session_id.present?
      os_sessions[os].add(session_id) if session_id.present?
      resolution_sessions[resolution].add(session_id) if resolution.present? && session_id.present?
      
      # Track unique visitors
      device_type_visitors[device_type].add(visitor_id) if visitor_id.present?
      browser_visitors[browser].add(visitor_id) if visitor_id.present?
      os_visitors[os].add(visitor_id) if visitor_id.present?
      
      # Track total counts
      device_types_total[device_type] = (device_types_total[device_type] || 0) + 1
      browsers_total[browser] = (browsers_total[browser] || 0) + 1
      operating_systems_total[os] = (operating_systems_total[os] || 0) + 1
      screen_resolutions_total[resolution] = (screen_resolutions_total[resolution] || 0) + 1 if resolution.present?
    end
    
    # Convert Sets to counts
    device_types_unique_sessions = device_type_sessions.transform_values(&:size)
    browsers_unique_sessions = browser_sessions.transform_values(&:size)
    operating_systems_unique_sessions = os_sessions.transform_values(&:size)
    screen_resolutions_unique_sessions = resolution_sessions.transform_values(&:size)
    
    device_types_unique_visitors = device_type_visitors.transform_values(&:size)
    browsers_unique_visitors = browser_visitors.transform_values(&:size)
    operating_systems_unique_visitors = os_visitors.transform_values(&:size)
    
    total_sessions_count = all_analytics.where("data->>'session_id' IS NOT NULL").distinct.count("data->>'session_id'")
    
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
      
      # Total counts (for reference - should match unique sessions now with session-based tracking)
      device_types_total: device_types_total,
      browsers_total: browsers_total,
      operating_systems_total: operating_systems_total,
      screen_resolutions_total: screen_resolutions_total,
      
      # Summary stats
      total_devices: total_sessions_count, # Total unique device sessions (for frontend compatibility)
      total_sessions: total_sessions_count,
      total_visitors: all_analytics.where("data->>'visitor_id' IS NOT NULL").distinct.count("data->>'visitor_id'"),
      total_records: all_analytics.count
    }
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
