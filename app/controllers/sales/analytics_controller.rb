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
    
    
    all_ads = Ad.where(deleted: false)
    all_reviews = Review.all
    # Filter wishlists to exclude deleted/blocked buyers, blocked/deleted sellers, and deleted ads
    all_wishlists = WishList.joins(:buyer, ad: :seller)
                            .where(buyers: { deleted: false })
                            .where(sellers: { deleted: false, blocked: false, flagged: false })
                            .where(ads: { deleted: false })
    
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
    
    # Get contact interaction events (copy, whatsapp, call, location views after reveal)
    # These are clicks where users interacted with seller contact info after revealing it
    all_contact_interactions = ClickEvent
      .excluding_internal_users
      .excluding_seller_own_clicks(device_hash: device_hash, seller_id: nil)
      .where(event_type: 'Reveal-Seller-Details')
      .where("metadata->>'action' = ?", 'seller_contact_interaction')
      .left_joins(:buyer)
      .joins(:ad) # Use inner join to exclude clicks without ads
      .where("buyers.id IS NULL OR buyers.deleted = ?", false) # Include guest clicks (buyer_id IS NULL) or non-deleted buyers
      .where(ads: { deleted: false }) # Exclude clicks with deleted ads
    
    # OPTIMIZATION: Limit timestamp queries to recent data only (last 2 years)
    # Convert timestamps to ISO 8601 format for proper JavaScript Date parsing
    sellers_with_timestamps = all_sellers.where('created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    buyers_with_timestamps = all_buyers.where('created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    ads_with_timestamps = all_ads.where('created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    reviews_with_timestamps = all_reviews.where('created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    wishlists_with_timestamps = all_wishlists.where('wish_lists.created_at >= ?', timestamp_limit_date).pluck('wish_lists.created_at').map { |ts| ts&.iso8601 }
    
    # OPTIMIZATION: Get click events with timestamps (limited to recent, remove duplicates)
    ad_clicks_with_timestamps = all_ad_clicks.where('click_events.created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    # Remove duplicate - buyer_ad_clicks uses same data
    buyer_ad_clicks_with_timestamps = ad_clicks_with_timestamps
    
    # OPTIMIZATION: Get reveal clicks with timestamps (limited to recent, remove duplicates)
    reveal_clicks_with_timestamps = all_reveal_clicks.where('click_events.created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    # Remove duplicate - buyer_reveal_clicks uses same data
    buyer_reveal_clicks_with_timestamps = reveal_clicks_with_timestamps
    
    # OPTIMIZATION: Get contact interactions with timestamps (limited to recent)
    contact_interactions_with_timestamps = all_contact_interactions.where('click_events.created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    
    # Get callback request events (excluding internal users, deleted buyers, and seller own clicks)
    all_callback_requests = ClickEvent
      .excluding_internal_users
      .excluding_seller_own_clicks(device_hash: device_hash, seller_id: nil)
      .where(event_type: 'Callback-Request')
      .left_joins(:buyer)
      .joins(:ad) # Use inner join to exclude clicks without ads
      .where("buyers.id IS NULL OR buyers.deleted = ?", false) # Include guest clicks (buyer_id IS NULL) or non-deleted buyers
      .where(ads: { deleted: false }) # Exclude clicks with deleted ads
    
    # OPTIMIZATION: Get callback requests with timestamps (limited to recent)
    callback_requests_with_timestamps = all_callback_requests.where('click_events.created_at >= ?', timestamp_limit_date).pluck(:created_at).map { |ts| ts&.iso8601 }
    
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
      ad_clicks_with_timestamps: ad_clicks_with_timestamps,
      buyer_ad_clicks_with_timestamps: buyer_ad_clicks_with_timestamps,
      buyer_reveal_clicks_with_timestamps: buyer_reveal_clicks_with_timestamps,
      reveal_clicks_with_timestamps: reveal_clicks_with_timestamps,
      contact_interactions_with_timestamps: contact_interactions_with_timestamps,
      callback_requests_with_timestamps: callback_requests_with_timestamps,
      
      # OPTIMIZATION: Pre-calculated totals for initial display (all time)
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
      total_contact_interactions: all_contact_interactions.count,
      total_callback_requests: all_callback_requests.count
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
          device_types_time_series: [],
          browsers_time_series: [],
          operating_systems_time_series: [],
          total_devices: 0
        }
      }
    end
  end

  def sources
    # Get source analytics only - optimized endpoint for sources page
    begin
      source_analytics = get_source_analytics
      render json: source_analytics
    rescue => e
      Rails.logger.error "Error getting source analytics: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Return minimal structure on error to prevent blocking
      render json: {
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
  end

  def categories
    # Get category click events only - optimized endpoint for categories page
    begin
      # Get device_hash from params or headers if available for excluding seller own clicks
      device_hash = params[:device_hash] || request.headers['X-Device-Hash']
      
      # Use unified service for category click events
      click_events_service = ClickEventsAnalyticsService.new(
        filters: {},
        device_hash: device_hash
      )
      category_click_events = click_events_service.category_click_events
      subcategory_click_events = click_events_service.subcategory_click_events
      
      render json: {
        category_click_events: category_click_events,
        subcategory_click_events: subcategory_click_events
      }
    rescue => e
      Rails.logger.error "Error getting category analytics: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        category_click_events: [],
        subcategory_click_events: []
      }
    end
  end

  def searches
    # Get search analytics from Redis
    analytics_data = SearchRedisService.analytics

    # Get popular searches for different timeframes
    popular_searches = {
      all_time: SearchRedisService.popular_searches(20, :all),
      daily: SearchRedisService.popular_searches(15, :daily),
      weekly: SearchRedisService.popular_searches(15, :weekly),
      monthly: SearchRedisService.popular_searches(15, :monthly)
    }

    # Get search history with pagination (limited for sales users)
    page = params[:page].to_i.positive? ? params[:page].to_i : 1
    per_page = [params[:per_page].to_i, 100].select(&:positive?).min || 50  # Max 100 per page for sales

    # Build filters from params
    filters = {}
    filters[:search_term] = params[:search_term] if params[:search_term].present?
    filters[:buyer_id] = params[:buyer_id] if params[:buyer_id].present?
    filters[:start_date] = params[:start_date] if params[:start_date].present?
    filters[:end_date] = params[:end_date] if params[:end_date].present?

    # Get search history from Redis
    search_history = SearchRedisService.search_history(
      page: page,
      per_page: per_page,
      filters: filters
    )

    # Format response
    formatted_searches = search_history[:searches].map do |search|
      {
        id: search[:id],
        search_term: search[:search_term],
        buyer_id: search[:buyer_id],
        timestamp: search[:timestamp],
        created_at: search[:timestamp],
        device_hash: search[:device_hash],
        user_agent: search[:user_agent]&.truncate(100),  # Limit user agent length
        ip_address: search[:ip_address]
      }
    end

    render json: {
      analytics: analytics_data,
      popular_searches: popular_searches,
      search_history: {
        searches: formatted_searches,
        meta: {
          current_page: search_history[:current_page],
          per_page: search_history[:per_page],
          total_count: search_history[:total_count],
          total_pages: search_history[:total_pages]
        }
      },
      data_retention: {
        individual_searches: '30 days',
        analytics_data: '90 days'
      }
    }, status: :ok
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
        # Count only wishlists for non-deleted ads from active sellers
        wishlist_count = buyer.wish_lists
                              .joins(ad: :seller)
                              .where(sellers: { deleted: false, blocked: false, flagged: false })
                              .where(ads: { deleted: false })
                              .count
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

  # GET /sales/analytics/ads/:id/stats
  # Get statistics for a specific ad
  def ad_stats
    ad_id = params[:id]
    
    begin
      ad = Ad.find_by(id: ad_id)
      unless ad
        render json: { error: 'Ad not found' }, status: :not_found
        return
      end
      
      # Get device_hash from params or headers if available
      device_hash = params[:device_hash] || request.headers['X-Device-Hash']
      
      # Get click event statistics
      click_stats = ClickEvent
        .excluding_internal_users
        .excluding_seller_own_clicks(device_hash: device_hash, seller_id: ad.seller_id)
        .where(ad_id: ad_id)
        .left_joins(:buyer)
        .where("buyers.id IS NULL OR buyers.deleted = ?", false)
        .group(:event_type)
        .count
      
      # Get contact interaction stats
      contact_interaction_events = ClickEvent
        .excluding_internal_users
        .excluding_seller_own_clicks(device_hash: device_hash, seller_id: ad.seller_id)
        .where(ad_id: ad_id, event_type: 'Reveal-Seller-Details')
        .where("metadata->>'action' = ?", 'seller_contact_interaction')
        .left_joins(:buyer)
        .where("buyers.id IS NULL OR buyers.deleted = ?", false)
      
      copy_clicks = contact_interaction_events
        .where("metadata->>'action_type' IN ('copy_phone', 'copy_email')")
        .count
      
      call_clicks = contact_interaction_events
        .where("metadata->>'action_type' = ?", 'call_phone')
        .count
      
      whatsapp_clicks = contact_interaction_events
        .where("metadata->>'action_type' = ?", 'whatsapp')
        .count
      
      location_clicks = contact_interaction_events
        .where("metadata->>'action_type' = ?", 'view_location')
        .count
      
      # Get wishlist count
      wishlist_count = WishList
        .joins(:ad)
        .where(ads: { id: ad_id, deleted: false })
        .count
      
      # Get guest vs authenticated reveals
      reveal_clicks = ClickEvent
        .excluding_internal_users
        .excluding_seller_own_clicks(device_hash: device_hash, seller_id: ad.seller_id)
        .where(ad_id: ad_id, event_type: 'Reveal-Seller-Details')
        .left_joins(:buyer)
        .where("buyers.id IS NULL OR buyers.deleted = ?", false)
      
      guest_reveals = reveal_clicks.where(buyer_id: nil).count
      authenticated_reveals = reveal_clicks.where.not(buyer_id: nil).count
      
      # Get conversions (guest users who revealed and then signed up)
      conversions = reveal_clicks
        .where(buyer_id: nil)
        .where("metadata->>'converted_from_guest' = ?", 'true')
        .count
      
      # Get callback request stats
      callback_requests = ClickEvent
        .excluding_internal_users
        .excluding_seller_own_clicks(device_hash: device_hash, seller_id: ad.seller_id)
        .where(ad_id: ad_id, event_type: 'Callback-Request')
        .left_joins(:buyer)
        .where("buyers.id IS NULL OR buyers.deleted = ?", false)
      
      callback_request_count = callback_requests.count
      
      # Get callback requests from alternative sellers
      alternative_callback_requests = callback_requests
        .where("metadata->>'is_alternative_seller' = ?", 'true')
        .count
      
      stats = {
        ad_id: ad.id,
        ad_title: ad.title,
        ad_clicks: click_stats['Ad-Click'] || 0,
        reveal_clicks: click_stats['Reveal-Seller-Details'] || 0,
        guest_reveals: guest_reveals,
        authenticated_reveals: authenticated_reveals,
        conversions: conversions,
        wishlist_count: wishlist_count,
        callback_requests: callback_request_count,
        alternative_callback_requests: alternative_callback_requests,
        contact_interactions: {
          copy_clicks: copy_clicks,
          call_clicks: call_clicks,
          whatsapp_clicks: whatsapp_clicks,
          location_clicks: location_clicks,
          total: copy_clicks + call_clicks + whatsapp_clicks + location_clicks
        }
      }
      
      render json: stats
    rescue => e
      Rails.logger.error "Ad stats error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'Internal server error', details: e.message }, status: 500
    end
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
    end
    
    # OPTIMIZATION: Cache base scope to avoid recalculating internal user exclusions
    # This is expensive, so we compute it once and reuse
    base_scope = if date_filter
      Analytic.excluding_internal_users.date_range(date_filter[:start_date], date_filter[:end_date])
    else
      # Limit to last 2 years for performance when no date filter
      two_years_ago = 2.years.ago
      Analytic.excluding_internal_users.where('created_at >= ?', two_years_ago)
    end
    
    # OPTIMIZATION: Run all distribution queries in parallel using threads or optimize queries
    # Get source tracking data with optional date filtering
    source_distribution = base_scope.group(
      Arel.sql(
        "CASE 
          WHEN source IS NOT NULL AND source != '' THEN source
          WHEN utm_source IS NOT NULL AND utm_source != '' AND utm_source NOT IN ('direct', 'other') THEN utm_source
          ELSE 'other'
        END"
      )
    ).count
    
    # OPTIMIZATION: Use single query with conditional aggregation for UTM distributions
    # Build base scope for UTM queries (records with complete UTM parameters)
    utm_base_scope = base_scope.where.not(utm_source: [nil, '', 'direct', 'other'])
                               .where.not(utm_medium: [nil, ''])
                               .where.not(utm_campaign: [nil, ''])
    
    # Get all UTM distributions in one pass using select with aggregations
    utm_source_distribution = utm_base_scope.group(:utm_source).count
    utm_medium_distribution = utm_base_scope.group(:utm_medium).count
    utm_campaign_distribution = utm_base_scope.group(:utm_campaign).count
    utm_content_distribution = utm_base_scope.where.not(utm_content: [nil, '']).group(:utm_content).count
    utm_term_distribution = utm_base_scope.where.not(utm_term: [nil, '']).group(:utm_term).count
    
    referrer_distribution = base_scope.where.not(referrer: [nil, '']).group(:referrer).count
    
    # OPTIMIZATION: Calculate visitor metrics more efficiently
    # Use single query with aggregations instead of multiple queries
    visitor_id_sql = "data->>'visitor_id'"
    visitor_scope = base_scope.where("#{visitor_id_sql} IS NOT NULL")
    
    total_visits = base_scope.count
    unique_visitors = visitor_scope.distinct.count(Arel.sql(visitor_id_sql))
    avg_visits_per_visitor = unique_visitors > 0 ? (total_visits.to_f / unique_visitors).round(2) : 0
    
    # OPTIMIZATION: Calculate returning/new visitors more efficiently
    # Only calculate if we have visitors and dataset is reasonable (skip for large datasets)
    # This calculation is expensive, so we limit it to smaller datasets
    returning_visitors = 0
    new_visitors = 0
    if unique_visitors > 0 && unique_visitors < 5000 && total_visits < 50000
      # Get unique visitor IDs from current scope (limit to first 5000 for performance)
      visitor_ids = visitor_scope.distinct.limit(5000).pluck(Arel.sql(visitor_id_sql)).compact
      
      if visitor_ids.any? && visitor_ids.size <= 5000
        # Get first visit dates for these visitors in a single optimized query
        first_visits = Analytic
          .where("#{visitor_id_sql} IN (?)", visitor_ids)
          .group(Arel.sql(visitor_id_sql))
          .minimum(:created_at)
        
        cutoff = 7.days.ago
        first_visits.each_value do |first_visit|
          if first_visit && first_visit < cutoff
            returning_visitors += 1
          else
            new_visitors += 1
          end
        end
      end
    end
    
    visitor_metrics = {
      total_visits: total_visits,
      unique_visitors: unique_visitors,
      returning_visitors: returning_visitors,
      new_visitors: new_visitors,
      avg_visits_per_visitor: avg_visits_per_visitor
    }
    
    # Get unique visitors by source with date filtering
    unique_visitors_by_source = visitor_scope.group(:utm_source).distinct.count(Arel.sql(visitor_id_sql))
    visits_by_source = base_scope.group(:utm_source).count
    
    # OPTIMIZATION: Get visits by day - use DATE() function for efficient grouping
    daily_visits = base_scope.group("DATE(created_at)")
                             .order("DATE(created_at)")
                             .count
    
    # OPTIMIZATION: Limit visit timestamps more aggressively for performance
    # Only fetch timestamps if date filter is provided or limit to last 6 months
    # Frontend can request specific date ranges via date filter params if needed
    visit_timestamps = if date_filter
      # If date filter provided, fetch all timestamps in range (but limit to 50k for safety)
      base_scope.select(:created_at)
                .limit(50000)
                                 .pluck(:created_at)
                                 .map { |ts| ts&.iso8601 }
    else
      # Limit to last 6 months for better performance (reduced from 1 year)
      # Frontend can use date filter params to get specific ranges
      six_months_ago = 6.months.ago
      base_scope.where('created_at >= ?', six_months_ago)
                .select(:created_at)
                .limit(50000)
                                 .pluck(:created_at)
                                 .map { |ts| ts&.iso8601 }
    end
    
    # OPTIMIZATION: Get unique visitors trend - use same visitor scope
    daily_unique_visitors = visitor_scope.group("DATE(created_at)")
                                         .order("DATE(created_at)")
                                         .distinct.count(Arel.sql(visitor_id_sql))
    
    # Get top sources and referrers (already computed, just sort)
    top_sources = source_distribution.sort_by { |_, count| -count }.first(10)
    top_referrers = referrer_distribution.sort_by { |_, count| -count }.first(10)
    
    # Calculate total_visits as sum of source_distribution to match frontend expectations
    total_visits_from_sources = source_distribution.values.sum
    
    # Note: "other" sources and "incomplete UTM" records have been removed via migration
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
    # OPTIMIZATION: Apply date filter first to reduce dataset size before exclusions
    # OPTIMIZATION: Cache base_query to avoid re-evaluating exclusions
    six_months_ago = 6.months.ago
    
    # Build base query with date filter first (reduces dataset before expensive exclusions)
    base_query = ClickEvent
      .where('click_events.created_at >= ?', six_months_ago)
      .where.not(metadata: nil)
      .left_joins(:ad)
      .where("ads.id IS NULL OR ads.deleted = ?", false)
      .excluding_internal_users
    
    # Note: Exclusion lists are now cached in ClickEvent.cached_exclusion_lists
    
    # Session identifier (device_hash or buyer_id)
    session_id_sql = "COALESCE(metadata->>'device_hash', buyer_id::text, 'unknown')"
    
    # All records now have user_agent_details stored, so no parsing needed
    query_with_ua = base_query.where("metadata->>'user_agent' IS NOT NULL OR metadata->'user_agent_details' IS NOT NULL")
    
    # Only track what's used by frontend: unique sessions and time-series
    device_types_sessions = Hash.new { |h, k| h[k] = Set.new }
    browsers_sessions = Hash.new { |h, k| h[k] = Set.new }
    operating_systems_sessions = Hash.new { |h, k| h[k] = Set.new }
    
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
      :created_at
    ).each do |user_agent_string, metadata_hash, session_id, created_at|
      next if session_id == 'unknown'
      
      # Fast path: Check if user_agent_details exists first (no parsing needed)
      # OPTIMIZATION: Skip parsing entirely - all records should have user_agent_details after backfill
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
      else
        # Skip records without user_agent_details (should be rare after backfill)
        # This avoids expensive UserAgentParser.parse() calls
        next
      end
      
      # Track unique sessions (only what's used by frontend)
        if session_id.present?
          device_types_sessions[device_type].add(session_id)
          browsers_sessions[browser].add(session_id)
          operating_systems_sessions[os].add(session_id)
        
        # Time-series data (last 90 days) - only if needed
        if created_at && created_at >= start_date
          date_key = created_at.to_date.iso8601
          device_types_by_date[date_key][device_type].add(session_id)
          browsers_by_date[date_key][browser].add(session_id)
          operating_systems_by_date[date_key][os].add(session_id)
        end
        end
      end
    
    # Convert Sets to counts (only what's used by frontend)
    device_types_unique_sessions = device_types_sessions.transform_values(&:size)
    browsers_unique_sessions = browsers_sessions.transform_values(&:size)
    operating_systems_unique_sessions = operating_systems_sessions.transform_values(&:size)
    
    # Count unique sessions for total_devices
    # OPTIMIZATION: Reuse the same base_query scope to avoid re-evaluating exclusions
    total_sessions_count = base_query
      .where("metadata->>'device_hash' IS NOT NULL OR buyer_id IS NOT NULL")
      .distinct
      .count(Arel.sql("#{session_id_sql}"))
    
    # Generate time-series arrays (only what's used by frontend)
    device_types_time_series = build_time_series(device_types_by_date, device_types_unique_sessions.keys, start_date)
    browsers_time_series = build_time_series(browsers_by_date, browsers_unique_sessions.keys, start_date)
    operating_systems_time_series = build_time_series(operating_systems_by_date, operating_systems_unique_sessions.keys, start_date)
    
    {
      # Unique sessions (primary metric - one per session)
      device_types: device_types_unique_sessions,
      browsers: browsers_unique_sessions,
      operating_systems: operating_systems_unique_sessions,
      
      # Time-series data for area charts (last 90 days)
      device_types_time_series: device_types_time_series,
      browsers_time_series: browsers_time_series,
      operating_systems_time_series: operating_systems_time_series,
      
      # Summary stats
      total_devices: total_sessions_count
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
