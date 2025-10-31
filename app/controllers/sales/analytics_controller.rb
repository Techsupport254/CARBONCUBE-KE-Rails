# app/controllers/sales/analytics_controller.rb
class Sales::AnalyticsController < ApplicationController
  before_action :authenticate_sales_user

  def index
    # Get list of excluded emails for filtering
    excluded_emails = InternalUserExclusion.active
                                           .by_type('email_domain')
                                           .pluck(:identifier_value)
    
    # Get all data without time filtering for totals
    all_sellers = Seller.where(deleted: false)
    all_buyers = excluded_emails.any? ? 
      Buyer.where(deleted: false).where.not('LOWER(email) IN (?)', excluded_emails.map(&:downcase)) :
      Buyer.where(deleted: false)
    
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
    
    # Get click events without time filtering for totals (excluding internal users)
    all_ad_clicks = ClickEvent.where(event_type: 'Ad-Click')
    all_buyer_ad_clicks = ClickEvent
      .joins(:buyer)
      .where(event_type: 'Ad-Click')
      .where(buyers: { deleted: false })
      .where.not('LOWER(buyers.email) IN (?)', excluded_emails.map(&:downcase)) # Exclude internal users
    all_buyer_reveal_clicks = ClickEvent
      .joins(:buyer)
      .where(event_type: 'Reveal-Seller-Details')
      .where(buyers: { deleted: false })
      .where.not('LOWER(buyers.email) IN (?)', excluded_emails.map(&:downcase)) # Exclude internal users
    all_reveal_clicks = ClickEvent.where(event_type: 'Reveal-Seller-Details')
    
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
    
    # Get click events with timestamps
    ad_clicks_with_timestamps = all_ad_clicks.pluck(:created_at).map { |ts| ts&.iso8601 }
    
    buyer_ad_clicks_with_timestamps = all_buyer_ad_clicks
      .pluck('click_events.created_at')
      .map { |ts| ts&.iso8601 }
    
    buyer_reveal_clicks_with_timestamps = all_buyer_reveal_clicks
      .pluck('click_events.created_at')
      .map { |ts| ts&.iso8601 }
    
    # Get reveal clicks with timestamps (include both authenticated and unauthenticated users)
    reveal_clicks_with_timestamps = all_reveal_clicks.pluck(:created_at).map { |ts| ts&.iso8601 }
    
    # Get category click events with timestamps (include all data)
    category_click_events_with_timestamps = Category.joins(ads: :click_events)
      .where(ads: { deleted: false })
      .select('categories.name AS category_name, 
              click_events.event_type,
              click_events.created_at')
      .order('categories.name')
    
    # Process category data
    category_data = {}
    category_click_events_with_timestamps.each do |record|
      category_name = record.category_name
      category_data[category_name] ||= { ad_clicks: 0, wish_list_clicks: 0, reveal_clicks: 0, timestamps: [] }
      
      case record.event_type
      when 'Ad-Click'
        category_data[category_name][:ad_clicks] += 1
      when 'Add-to-Wish-List'
        category_data[category_name][:wish_list_clicks] += 1
      when 'Reveal-Seller-Details'
        category_data[category_name][:reveal_clicks] += 1
      end
      
      category_data[category_name][:timestamps] << record.created_at&.iso8601
    end
    
    # Convert to array format
    category_click_events = category_data.map do |category_name, data|
      {
        category_name: category_name,
        ad_clicks: data[:ad_clicks],
        wish_list_clicks: data[:wish_list_clicks],
        reveal_clicks: data[:reveal_clicks],
        timestamps: data[:timestamps]
      }
    end

    # Get subcategory click events with timestamps (include all data)
    subcategory_click_events_with_timestamps = Subcategory
      .joins(:category)
      .joins('INNER JOIN ads ON ads.subcategory_id = subcategories.id')
      .joins('INNER JOIN click_events ON click_events.ad_id = ads.id')
      .where('ads.deleted = ?', false)
      .select('subcategories.id AS subcategory_id,
              subcategories.name AS subcategory_name,
              categories.id AS category_id,
              categories.name AS category_name,
              click_events.event_type,
              click_events.created_at')
      .order('categories.name, subcategories.name')
    
    # Process subcategory data grouped by category
    subcategory_data = {}
    subcategory_click_events_with_timestamps.each do |record|
      category_name = record.category_name
      subcategory_name = record.subcategory_name
      key = "#{category_name}::#{subcategory_name}"
      
      subcategory_data[key] ||= { 
        category_name: category_name,
        subcategory_name: subcategory_name,
        ad_clicks: 0, 
        wish_list_clicks: 0, 
        reveal_clicks: 0, 
        timestamps: [] 
      }
      
      case record.event_type
      when 'Ad-Click'
        subcategory_data[key][:ad_clicks] += 1
      when 'Add-to-Wish-List'
        subcategory_data[key][:wish_list_clicks] += 1
      when 'Reveal-Seller-Details'
        subcategory_data[key][:reveal_clicks] += 1
      end
      
      subcategory_data[key][:timestamps] << record.created_at&.iso8601
    end
    
    # Get ads count for each subcategory
    subcategory_ads_counts = Subcategory
      .joins(:category)
      .joins(:ads)
      .where(ads: { deleted: false })
      .group('subcategories.id, subcategories.name, subcategories.category_id, categories.id, categories.name')
      .select('subcategories.id AS subcategory_id,
              subcategories.name AS subcategory_name,
              categories.name AS category_name,
              COUNT(ads.id) AS ads_count')
      .each_with_object({}) do |record, hash|
        key = "#{record.category_name}::#{record.subcategory_name}"
        hash[key] = record.ads_count.to_i
      end
    
    # Convert to array format with ads_count
    subcategory_click_events = subcategory_data.values.map do |data|
      key = "#{data[:category_name]}::#{data[:subcategory_name]}"
      {
        category_name: data[:category_name],
        subcategory_name: data[:subcategory_name],
        ads_count: subcategory_ads_counts[key] || 0,
        ad_clicks: data[:ad_clicks],
        wish_list_clicks: data[:wish_list_clicks],
        reveal_clicks: data[:reveal_clicks],
        timestamps: data[:timestamps]
      }
    end

    # Get source tracking analytics
    source_analytics = get_source_analytics
    
    # Get device analytics
    device_analytics = get_device_analytics
    
    # Analytics data prepared successfully
    
    response_data = {
      # Raw data with timestamps for frontend filtering (ALL data, no time restriction)
      sellers_with_timestamps: sellers_with_timestamps,
      buyers_with_timestamps: buyers_with_timestamps,
      ads_with_timestamps: ads_with_timestamps,
      reviews_with_timestamps: reviews_with_timestamps,
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
      buyer_ad_clicks: all_buyer_ad_clicks.count,
      buyer_reveal_clicks: all_buyer_reveal_clicks.count,
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
      
      # Get list of excluded emails for filtering
      excluded_emails = InternalUserExclusion.active
                                             .by_type('email_domain')
                                             .pluck(:identifier_value)
      
      # Filter out excluded buyers
      users = users.where.not('LOWER(buyers.email) IN (?)', excluded_emails.map(&:downcase)) if excluded_emails.any?
      
      users_data = users.map do |buyer|
        clicks_count = buyer.click_events.where(event_type: 'Ad-Click').count
        reveals_count = buyer.click_events.where(event_type: 'Reveal-Seller-Details').count
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
    referrer_distribution = Analytic.referrer_distribution(date_filter)
    
    # Get visitor engagement metrics with date filtering
    visitor_metrics = Analytic.visitor_engagement_metrics(date_filter)
    
    # Get unique visitors by source with date filtering
    unique_visitors_by_source = Analytic.unique_visitors_by_source(date_filter)
    visits_by_source = Analytic.visits_by_source(date_filter)
    
    # Get visits by day with date filtering
    if date_filter
      daily_visits = Analytic.date_range(date_filter[:start_date], date_filter[:end_date])
                             .group("DATE(created_at)")
                             .order("DATE(created_at)")
                             .count
    else
      daily_visits = Analytic.all
                             .group("DATE(created_at)")
                             .order("DATE(created_at)")
                             .count
    end
    
    # Get visit timestamps with date filtering
    if date_filter
      visit_timestamps = Analytic.date_range(date_filter[:start_date], date_filter[:end_date])
                                 .pluck(:created_at)
                                 .map { |ts| ts&.iso8601 }
    else
      visit_timestamps = Analytic.all.pluck(:created_at).map { |ts| ts&.iso8601 }
    end
    
    # Get unique visitors trend with date filtering
    daily_unique_visitors = Analytic.unique_visitors_trend(date_filter)
    
    # Get top sources and referrers
    top_sources = source_distribution.sort_by { |_, count| -count }.first(10)
    top_referrers = referrer_distribution.sort_by { |_, count| -count }.first(10)
    
    {
      total_visits: visitor_metrics[:total_visits],
      unique_visitors: visitor_metrics[:unique_visitors],
      returning_visitors: visitor_metrics[:returning_visitors],
      new_visitors: visitor_metrics[:new_visitors],
      avg_visits_per_visitor: visitor_metrics[:avg_visits_per_visitor],
      source_distribution: source_distribution,
      unique_visitors_by_source: unique_visitors_by_source,
      visits_by_source: visits_by_source,
      utm_source_distribution: utm_source_distribution,
      utm_medium_distribution: utm_medium_distribution,
      utm_campaign_distribution: utm_campaign_distribution,
      referrer_distribution: referrer_distribution,
      daily_visits: daily_visits,
      visit_timestamps: visit_timestamps,
      daily_unique_visitors: daily_unique_visitors,
      top_sources: top_sources,
      top_referrers: top_referrers
    }
  end

  def get_device_analytics
    # Get device analytics for ALL time (no 30-day restriction)
    all_analytics = Analytic.all
    
    # Device type distribution
    device_types = {}
    browsers = {}
    operating_systems = {}
    screen_resolutions = {}
    
    all_analytics.each do |analytic|
      next unless analytic.data && analytic.data['device']
      
      device_data = analytic.data['device']
      
      # Count device types
      device_type = device_data['device_type'] || 'Unknown'
      device_types[device_type] = (device_types[device_type] || 0) + 1
      
      # Count browsers
      browser = device_data['browser'] || 'Unknown'
      browsers[browser] = (browsers[browser] || 0) + 1
      
      # Count operating systems
      os = device_data['os'] || 'Unknown'
      operating_systems[os] = (operating_systems[os] || 0) + 1
      
      # Count screen resolutions
      if analytic.data['screen_resolution']
        resolution = analytic.data['screen_resolution']
        screen_resolutions[resolution] = (screen_resolutions[resolution] || 0) + 1
      end
    end
    
    {
      device_types: device_types,
      browsers: browsers,
      operating_systems: operating_systems,
      screen_resolutions: screen_resolutions,
      total_devices: all_analytics.count
    }
  end
end
