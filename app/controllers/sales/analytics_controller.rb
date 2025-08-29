# app/controllers/sales/analytics_controller.rb
class Sales::AnalyticsController < ApplicationController
  before_action :authenticate_sales_user

  def index
    # Limit analytics window to last 30 days to reduce payload
    window_start = 30.days.ago
    # Get all data with timestamps for frontend filtering
    sellers_with_timestamps = Seller.where(deleted: false).where('created_at >= ?', window_start).pluck(:created_at)
    buyers_with_timestamps = Buyer.where(deleted: false).where('created_at >= ?', window_start).pluck(:created_at)
    ads_with_timestamps = Ad.where(deleted: false).where('created_at >= ?', window_start).pluck(:created_at)
    reviews_with_timestamps = Review.where('created_at >= ?', window_start).pluck(:created_at)
    wishlists_with_timestamps = WishList.where('created_at >= ?', window_start).pluck(:created_at)
    
    # Get seller tiers with timestamps
    paid_seller_tiers_with_timestamps = SellerTier
      .joins(:seller)
      .where(tier_id: [2, 3, 4], sellers: { deleted: false })
      .where('sellers.created_at >= ?', window_start)
      .pluck('sellers.created_at')
    
    unpaid_seller_tiers_with_timestamps = SellerTier
      .joins(:seller)
      .where(tier_id: 1, sellers: { deleted: false })
      .where('sellers.created_at >= ?', window_start)
      .pluck('sellers.created_at')
    
    # Get click events with timestamps
    ad_clicks_with_timestamps = ClickEvent.where(event_type: 'Ad-Click').where('created_at >= ?', window_start).pluck(:created_at)
    
    buyer_ad_clicks_with_timestamps = ClickEvent
      .joins(:buyer)
      .where(event_type: 'Ad-Click')
      .where(buyers: { deleted: false })
      .where('click_events.created_at >= ?', window_start)
      .pluck('click_events.created_at')
    
    # Get reveal clicks with timestamps (include both authenticated and unauthenticated users)
    reveal_clicks_with_timestamps = ClickEvent.where(event_type: 'Reveal-Seller-Details').where('created_at >= ?', window_start).pluck(:created_at)
    
    # Get category click events with timestamps (include both authenticated and unauthenticated users)
    category_click_events_with_timestamps = Category.joins(ads: :click_events)
      .select('categories.name AS category_name, 
              click_events.event_type,
              click_events.created_at')
      .where('click_events.created_at >= ?', window_start)
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
      
      category_data[category_name][:timestamps] << record.created_at
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

    # Get source tracking analytics
    source_analytics = get_source_analytics
    
    # Get device analytics
    device_analytics = get_device_analytics
    
    # Analytics data prepared successfully
    
    response_data = {
      # Raw data with timestamps for frontend filtering
      sellers_with_timestamps: sellers_with_timestamps,
      buyers_with_timestamps: buyers_with_timestamps,
      ads_with_timestamps: ads_with_timestamps,
      reviews_with_timestamps: reviews_with_timestamps,
      wishlists_with_timestamps: wishlists_with_timestamps,
      paid_seller_tiers_with_timestamps: paid_seller_tiers_with_timestamps,
      unpaid_seller_tiers_with_timestamps: unpaid_seller_tiers_with_timestamps,
      ad_clicks_with_timestamps: ad_clicks_with_timestamps,
      buyer_ad_clicks_with_timestamps: buyer_ad_clicks_with_timestamps,
      reveal_clicks_with_timestamps: reveal_clicks_with_timestamps,
      category_click_events: category_click_events,
      
      # Pre-calculated totals for initial display
      total_sellers: sellers_with_timestamps.count,
      total_buyers: buyers_with_timestamps.count,
      total_ads: ads_with_timestamps.count,
      total_reviews: reviews_with_timestamps.count,
      total_ads_wish_listed: wishlists_with_timestamps.count,
      subscription_countdowns: paid_seller_tiers_with_timestamps.count,
      without_subscription: unpaid_seller_tiers_with_timestamps.count,
      total_ads_clicks: ad_clicks_with_timestamps.count,
      buyer_ad_clicks: buyer_ad_clicks_with_timestamps.count,
      total_reveal_clicks: reveal_clicks_with_timestamps.count,
      
      # Source tracking analytics
      source_analytics: source_analytics,
      
      # Device analytics
      device_analytics: device_analytics
    }
    
    render json: response_data
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def get_source_analytics
    # Get source tracking data for the last 30 days
    days = 30
    
    source_distribution = Analytic.source_distribution(days)
    utm_source_distribution = Analytic.utm_source_distribution(days)
    utm_medium_distribution = Analytic.utm_medium_distribution(days)
    utm_campaign_distribution = Analytic.utm_campaign_distribution(days)
    referrer_distribution = Analytic.referrer_distribution(days)
    
    # Get visitor engagement metrics
    visitor_metrics = Analytic.visitor_engagement_metrics(days)
    
    # Get unique visitors by source
    unique_visitors_by_source = Analytic.unique_visitors_by_source(days)
    visits_by_source = Analytic.visits_by_source(days)
    
    # Get visits by day for the last 30 days
    daily_visits = Analytic.recent(days)
                           .group("DATE(created_at)")
                           .order("DATE(created_at)")
                           .count
    
    # Get unique visitors trend
    daily_unique_visitors = Analytic.unique_visitors_trend(days)
    
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
      daily_unique_visitors: daily_unique_visitors,
      top_sources: top_sources,
      top_referrers: top_referrers
    }
  end

  def get_device_analytics
    # Get device analytics for the last 30 days
    days = 30
    recent_analytics = Analytic.recent(days)
    
    # Device type distribution
    device_types = {}
    browsers = {}
    operating_systems = {}
    screen_resolutions = {}
    
    recent_analytics.each do |analytic|
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
      total_devices: recent_analytics.count
    }
  end
end
