class Seller::AnalyticsController < ApplicationController
  before_action :authenticate_seller

  def index
    begin
      # Get seller's tier_id
      tier_id = current_seller.seller_tier&.tier_id || 1

      Rails.logger.info "Analytics request for seller #{current_seller.id} with tier #{tier_id}"

      # Base response data - only include tier_id (other fields removed as unused on audience page)
      response_data = {
        tier_id: tier_id
      }

      # Add more data based on the seller's tier
      # OPTIMIZATION: Only return data actually used on the overview page
      device_hash = params[:device_hash] || request.headers['X-Device-Hash']
      click_events_service = ClickEventsAnalyticsService.new(
        filters: { seller_id: current_seller.id },
        device_hash: device_hash
      )
      
      case tier_id
      when 1 # Free tier
        # Free tier already has base data above
      when 2 # Basic tier
        # Get all timestamps for Basic tier (all time, no limits)
        timestamps = click_events_service.timestamps(limit: nil, date_limit: nil)
        
        # Get all add-to-wishlist click event timestamps (all time, no limits)
        add_to_wishlist_timestamps = click_events_service.base_query
                                                          .where(event_type: 'Add-to-Wish-List')
                                                          .order('click_events.created_at DESC')
                                                          .pluck(Arel.sql("click_events.created_at"))
                                                          .map { |ts| ts&.iso8601 }
        
        Rails.logger.info "Basic tier timestamps - ad_clicks: #{timestamps[:ad_clicks_timestamps]&.length || 0}, reveals: #{timestamps[:reveal_events_timestamps]&.length || 0}, wishlist: #{add_to_wishlist_timestamps&.length || 0}"
        
        response_data.merge!(
          # Add timestamps for dynamic filtering (all time)
          ad_clicks_timestamps: timestamps[:ad_clicks_timestamps],
          reveal_events_timestamps: timestamps[:reveal_events_timestamps],
          add_to_wishlist_timestamps: add_to_wishlist_timestamps
        )
      when 3 # Standard tier
        # Get all timestamps for Standard tier (all time, no limits)
        timestamps = click_events_service.timestamps(limit: nil, date_limit: nil)
        
        # Get all add-to-wishlist click event timestamps (all time, no limits)
        add_to_wishlist_timestamps = click_events_service.base_query
                                                          .where(event_type: 'Add-to-Wish-List')
                                                          .order('click_events.created_at DESC')
                                                          .pluck(Arel.sql("click_events.created_at"))
                                                          .map { |ts| ts&.iso8601 }
        
        # Get category for competitor stats (from params or primary category)
        competitor_category_id = get_competitor_category_id
        primary_category_id = competitor_category_id || get_primary_category_id
        
        Rails.logger.info "Standard tier timestamps - ad_clicks: #{timestamps[:ad_clicks_timestamps]&.length || 0}, reveals: #{timestamps[:reveal_events_timestamps]&.length || 0}, wishlist: #{add_to_wishlist_timestamps&.length || 0}"
        
        response_data.merge!(
          # Add timestamps for dynamic filtering (all time)
          ad_clicks_timestamps: timestamps[:ad_clicks_timestamps],
          reveal_events_timestamps: timestamps[:reveal_events_timestamps],
          add_to_wishlist_timestamps: add_to_wishlist_timestamps,
          # Add demographics stats for audience page (tier 3+)
          click_events_stats: top_click_event_stats,
          wishlist_stats: top_wishlist_stats,
          competitor_stats: primary_category_id ? calculate_competitor_stats(primary_category_id) : {
            revenue_share: { seller_revenue: 0, total_category_revenue: 0, revenue_share: 0 },
            top_competitor_ads: [],
            competitor_average_price: 0
          }
        )
      when 4 # Premium tier
        # OPTIMIZATION: Cache common data to avoid repeated queries
        @cached_seller_ad_ids = seller_ad_ids
        @cached_device_hash = device_hash
        
        # Get all timestamps for Premium tier (all time, no limits)
        timestamps = click_events_service.timestamps(limit: nil, date_limit: nil)
        
        # Get all wishlist timestamps (all time, no limits)
        wishlist_timestamps = WishList.joins(:ad)
                                      .where(ads: { seller_id: current_seller.id, deleted: false })
                                      .order('wish_lists.created_at DESC')
                                      .pluck(:created_at)
                                      .map { |ts| ts&.iso8601 }
        
        # Get all add-to-wishlist click event timestamps (all time, no limits)
        add_to_wishlist_timestamps = click_events_service.base_query
                                                          .where(event_type: 'Add-to-Wish-List')
                                                          .order('click_events.created_at DESC')
                                                          .pluck(Arel.sql("click_events.created_at"))
                                                          .map { |ts| ts&.iso8601 }
        
        # Get category for competitor stats (from params or primary category)
        competitor_category_id = get_competitor_category_id
        primary_category_id = competitor_category_id || get_primary_category_id
        
        # OPTIMIZATION: Pre-load common data used by multiple methods
        preload_common_data_for_premium
        
        Rails.logger.info "Premium tier timestamps - ad_clicks: #{timestamps[:ad_clicks_timestamps]&.length || 0}, reveals: #{timestamps[:reveal_events_timestamps]&.length || 0}, wishlist: #{add_to_wishlist_timestamps&.length || 0}"
        
        # Calculate all advanced metrics for premium tier (used on advanced analytics page)
        response_data.merge!(
          # Timestamps for audience page (tier 2+)
          ad_clicks_timestamps: timestamps[:ad_clicks_timestamps],
          reveal_events_timestamps: timestamps[:reveal_events_timestamps],
          add_to_wishlist_timestamps: add_to_wishlist_timestamps,
          wishlist_timestamps: wishlist_timestamps,
          # Demographics stats for audience page (tier 3+)
          click_events_stats: top_click_event_stats,
          wishlist_stats: top_wishlist_stats,
          competitor_stats: primary_category_id ? calculate_competitor_stats(primary_category_id) : {
            revenue_share: { seller_revenue: 0, total_category_revenue: 0, revenue_share: 0 },
            top_competitor_ads: [],
            competitor_average_price: 0
          },
          # Advanced metrics for /seller/analytics/advanced page
          conversion_funnel_metrics: calculate_conversion_funnel_metrics(device_hash),
          product_health_indicators: calculate_product_health_indicators_optimized,
          engagement_quality_metrics: calculate_engagement_quality_metrics(device_hash),
          temporal_analytics: calculate_temporal_analytics,
          category_performance: calculate_category_performance,
          customer_insights: calculate_customer_insights(device_hash),
          operational_metrics: calculate_operational_metrics,
          competitive_intelligence: primary_category_id ? calculate_competitive_intelligence(primary_category_id) : empty_competitive_intelligence,
          advanced_engagement_metrics: calculate_advanced_engagement_metrics(device_hash),
          review_reputation_metrics: calculate_review_reputation_metrics,
          offer_promotion_analytics: calculate_offer_promotion_analytics
        )
      else
        render json: { error: 'Invalid tier' }, status: 400
        return
      end

      render json: response_data
    rescue => e
      Rails.logger.error "Analytics error for seller #{current_seller&.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'Internal server error', details: e.message }, status: 500
    end
  end





  private





  # Data for Free tier
  def calculate_free_tier_data
    {
      total_orders: calculate_total_orders,
      total_ads: calculate_total_ads,
      average_rating: calculate_average_rating
    }
  end

  # Data for Basic tier
  def calculate_basic_tier_data
    {
      total_revenue: calculate_total_revenue
    }
  end

  # Data for Standard tier
  def calculate_standard_tier_data
    {
      total_revenue: calculate_total_revenue
    }
  end

  # Data for Premium tier
  def calculate_premium_tier_data
    {
      total_revenue: calculate_total_revenue
    }
  end

#================================================= COMBINE ALL WISHLIST STATS =================================================#
  def top_wishlist_stats
    stats = {
      top_age_group: top_age_group,
      top_income_range: top_income_range,
      top_education_level: top_education_level,
      top_employment_status: top_employment_status,
      top_sector: top_sector
    }

    # Rails.logger.info "Final Wishlist Stats: #{stats}"
    stats
  end

  def basic_wishlist_stats
    {
      wishlist_trends: wishlist_trends,
      top_wishlisted_ads: top_wishlisted_ads
    }
  end


#================================================= COMBINE ALL TOP CLICK EVENT STATS =================================================#
  def top_click_event_stats
    # Use unified service for click events demographics
    # Pass device_hash if available to exclude seller's own clicks from their device
    device_hash = params[:device_hash] || request.headers['X-Device-Hash']
    click_events_service = ClickEventsAnalyticsService.new(
      filters: { seller_id: current_seller.id },
      device_hash: device_hash
    )
    click_events_service.demographics_stats
  end

  def basic_click_event_stats
    # Use unified service for click events trends
    # Pass device_hash if available to exclude seller's own clicks from their device
    device_hash = params[:device_hash] || request.headers['X-Device-Hash']
    click_events_service = ClickEventsAnalyticsService.new(
      filters: { seller_id: current_seller.id },
      device_hash: device_hash
    )
    {
      click_event_trends: click_events_service.click_event_trends
    }
  end

#================================================= CLICK EVENTS PURCHASER DEMOGRAPHICS =================================================#

  # Group clicks by age groups
  def group_clicks_by_age
    clicks = ClickEvent.joins(buyer: :age_group)
                      .includes(:ad)
                      .where(ads: { seller_id: current_seller.id })
                      .group('age_groups.name', :event_type)
                      .count

    clicks.transform_keys do |(age_group_name, event_type)|
      { age_group: age_group_name, event_type: event_type }
    end
  end

  # Group clicks by income ranges
  def group_clicks_by_income
    ClickEvent.joins(ad: {}, buyer: :income)
              .where(ads: { seller_id: current_seller.id })
              .group("incomes.range", :event_type)
              .count
              .transform_keys { |k| { income_range: k[0], event_type: k[1] } }
  end

  # Group clicks by education levels
  def group_clicks_by_education
    ClickEvent.joins(ad: {}, buyer: :education)
              .where(ads: { seller_id: current_seller.id })
              .group("educations.level", :event_type)
              .count
              .transform_keys { |k| { education_level: k[0], event_type: k[1] } }
  end

  # Group clicks by employment statuses
  def group_clicks_by_employment
    ClickEvent.joins(ad: {}, buyer: :employment)
              .where(ads: { seller_id: current_seller.id })
              .group("employments.status", :event_type)
              .count
              .transform_keys { |k| { employment_status: k[0], event_type: k[1] } }
  end

  # Group clicks by sectors
  def group_clicks_by_sector
    ClickEvent.joins(ad: {}, buyer: :sector)
              .where(ads: { seller_id: current_seller.id })
              .group("sectors.name", :event_type)
              .count
              .transform_keys { |k| { sector: k[0], event_type: k[1] } }
  end

  def click_event_trends
    # Define the date range: the current month and the previous 4 months
    end_date = Date.today.end_of_month
    start_date = (end_date - 4.months).beginning_of_month

    # Step 1: Find all ad IDs that belong to the current seller
    ad_ids = Ad.where(seller_id: current_seller.id).pluck(:id)
    # Rails.logger.info("Ad IDs for Seller #{current_seller.id}: #{ad_ids.inspect}")

    if ad_ids.empty?
      # Rails.logger.warn("No Ads found for Seller #{current_seller.id}")
      return (0..4).map do |i|
        month_date = end_date - i.months
        {
          month: month_date.strftime('%B %Y'),
          ad_clicks: 0,
          add_to_wish_list: 0,
          reveal_seller_details: 0
        }
      end.reverse
    end

    # Step 2: Query the click events for those ads within the date range
    click_events = ClickEvent.where(ad_id: ad_ids)
                             .where('created_at BETWEEN ? AND ?', start_date, end_date)
                             .group("DATE_TRUNC('month', created_at)", :event_type)
                             .count

    # Rails.logger.info("Click Events Grouped by Month and Event Type: #{click_events.inspect}")

    # Step 3: Build the monthly data for the past 5 months
    monthly_click_events = (0..4).map do |i|
      month_date = (end_date - i.months).beginning_of_month

      # Ensure key structure matches expected format
      ad_clicks = click_events.select { |(date, event), _| date && date.to_date == month_date.to_date && event == 'Ad-Click' }.values.sum || 0
      add_to_wish_list = click_events.select { |(date, event), _| date && date.to_date == month_date.to_date && event == 'Add-to-Wish-List' }.values.sum || 0
      reveal_seller_details = click_events.select { |(date, event), _| date && date.to_date == month_date.to_date && event == 'Reveal-Seller-Details' }.values.sum || 0

      {
        month: month_date.strftime('%B %Y'), # Format: "Month Year"
        ad_clicks: ad_clicks,
        add_to_wish_list: add_to_wish_list,
        reveal_seller_details: reveal_seller_details
      }
    end.reverse

    # Debugging output
    # Rails.logger.info("Click Event Trends for Seller #{current_seller.id}: #{monthly_click_events.inspect}")

    # Return the result for the frontend
    monthly_click_events
  end

  #================================================= TOP CLICK EVENTS BY PURCHASER DEMOGRAPHICS =================================================#

  # Get the age group with the highest click events
  def top_clicks_by_age
    clicks = group_clicks_by_age
    # Rails.logger.info "Age Group Click Distribution: #{clicks}"

    result = get_top_clicks(clicks, :age_group)
    # Rails.logger.info "Top Age Group Clicks: #{result}"
    result
  end

  # Get the income range with the highest click events
  def top_clicks_by_income
    clicks = group_clicks_by_income
    # Rails.logger.info "Income Range Click Distribution: #{clicks}"

    result = get_top_clicks(clicks, :income_range)
    # Rails.logger.info "Top Income Clicks: #{result}"
    result
  end

  # Get the education level with the highest click events
  def top_clicks_by_education
    clicks = group_clicks_by_education
    # Rails.logger.info "Education Click Distribution: #{clicks}"

    result = get_top_clicks(clicks, :education_level)
    # Rails.logger.info "Top Education Clicks: #{result}"
    result
  end

  # Get the employment status with the highest click events
  def top_clicks_by_employment
    clicks = group_clicks_by_employment
    # Rails.logger.info "Employment Status Click Distribution: #{clicks}"

    result = get_top_clicks(clicks, :employment_status)
    # Rails.logger.info "Top Employment Clicks: #{result}"
    result
  end

  # Get the sector with the highest click events
  def top_clicks_by_sector
    clicks = group_clicks_by_sector
    # Rails.logger.info "Sector Click Distribution: #{clicks}"

    result = get_top_clicks(clicks, :sector)
    # Rails.logger.info "Top Sector Clicks: #{result}"
    result
  end



#================================================= HELPER METHOD FOR GETTING TOP CLICKS =================================================#

  def get_top_clicks(clicks, group_key)
    top_ad_click = clicks.select { |k, _| k[:event_type] == 'Ad-Click' }.max_by { |_, count| count }
    top_wishlist = clicks.select { |k, _| k[:event_type] == 'Add-to-Wish-List' }.max_by { |_, count| count }
    top_reveal = clicks.select { |k, _| k[:event_type] == 'Reveal-Seller-Details' }.max_by { |_, count| count }

    {
      top_ad_click: top_ad_click ? { group_key => top_ad_click[0][group_key], clicks: top_ad_click[1] } : nil,
      top_wishlist: top_wishlist ? { group_key => top_wishlist[0][group_key], clicks: top_wishlist[1] } : nil,
      top_reveal: top_reveal ? { group_key => top_reveal[0][group_key], clicks: top_reveal[1] } : nil
    }
  end




#================================================= WISHLISTS PURCHASER DEMOGRAPHICS =================================================#
  # Get the age group with the highest wishlists
  def top_age_group
    age_group_counts = Buyer.joins(:wish_lists)
                                .where(wish_lists: { ad_id: seller_ad_ids })
                                .group(:age_group_id)
                                .count

    top_group_id, count = age_group_counts.max_by { |_, c| c }

    if top_group_id
      age_group = AgeGroup.find_by(id: top_group_id)
      {
        age_group: age_group&.name || 'Unknown',
        count: count
      }
    else
      nil
    end
  end


  # Get the income range with the highest wishlists
  def top_income_range
    data = WishList.joins(:ad, buyer: :income)
                  .joins("INNER JOIN ads ON wish_lists.ad_id = ads.id")
                  .where(ads: { seller_id: current_seller.id })
                  .group("incomes.range")
                  .count
    
    # Rails.logger.info "Income Range Wishlist Distribution: #{data}"

    group = data.max_by { |_, count| count }

    result = group ? { income_range: group[0], wishlists: group[1] } : nil
    # Rails.logger.info "Top Income Range: #{result}"
    
    result
  end

  # Get the education level with the highest wishlists
  def top_education_level
    data = WishList.joins(:ad, buyer: :education)
                  .joins("INNER JOIN ads ON wish_lists.ad_id = ads.id")
                  .where(ads: { seller_id: current_seller.id })
                  .group("educations.level")
                  .count

    # Rails.logger.info "Education Level Wishlist Distribution: #{data}"

    group = data.max_by { |_, count| count }

    result = group ? { education_level: group[0], wishlists: group[1] } : nil
    # Rails.logger.info "Top Education Level: #{result}"
    
    result
  end

  # Get the employment status with the highest wishlists
  def top_employment_status
    data = WishList.joins(:ad, buyer: :employment)
                  .joins("INNER JOIN ads ON wish_lists.ad_id = ads.id")
                  .where(ads: { seller_id: current_seller.id })
                  .group("employments.status")
                  .count

    # Rails.logger.info "Employment Status Wishlist Distribution: #{data}"

    group = data.max_by { |_, count| count }

    result = group ? { employment_status: group[0], wishlists: group[1] } : nil
    # Rails.logger.info "Top Employment Status: #{result}"
    
    result
  end

  # Get the sector with the highest wishlists
  def top_sector
    data = WishList.joins(:ad, buyer: :sector)
                  .joins("INNER JOIN ads ON wish_lists.ad_id = ads.id")
                  .where(ads: { seller_id: current_seller.id })
                  .group("sectors.name")
                  .count

    # Rails.logger.info "Sector Wishlist Distribution: #{data}"

    group = data.max_by { |_, count| count }

    result = group ? { sector: group[0], wishlists: group[1] } : nil
    # Rails.logger.info "Top Sector: #{result}"
    
    result
  end

  def top_wishlisted_ads
    begin
      WishList.joins(:ad)
              .where(ads: { seller_id: current_seller.id })
              .group('ads.id', 'ads.title', 'ads.media', 'ads.price')
              .select('ads.title AS ad_title, COUNT(wish_lists.id) AS wishlist_count, ads.media AS ad_media, ads.price AS ad_price')
              .order('wishlist_count DESC')
              .limit(3)
              .map do |record|
                {
                  ad_title: record.ad_title,
                  wishlist_count: record.wishlist_count,
                  ad_media: JSON.parse(record.ad_media || '[]'), # Parse media as an array
                  ad_price: record.ad_price
                }
              end
    rescue StandardError
      []
    end
  end
  

  def wishlist_trends
    # Define the date range: the current month and the previous 4 months
    end_date = Date.today.end_of_month
    start_date = (end_date - 4.months).beginning_of_month
  
    # Step 1: Find all ad IDs that belong to the current seller
    ad_ids = Ad.where(seller_id: current_seller.id).pluck(:id)
    # Rails.logger.info("Ad IDs for Seller #{current_seller.id}: #{ad_ids.inspect}")
  
    if ad_ids.empty?
      # Rails.logger.warn("No Ads found for Seller #{current_seller.id}")
      return (0..4).map do |i|
        month_date = end_date - i.months
        {
          month: month_date.strftime('%B %Y'),
          wishlist_count: 0
        }
      end.reverse
    end
  
    # Step 2: Query the wishlists for those ads within the date range
    wishlist_counts = WishList.where(ad_id: ad_ids)
                              .where('created_at BETWEEN ? AND ?', start_date, end_date)
                              .group("DATE_TRUNC('month', created_at)")
                              .count
    # Rails.logger.info("Wishlist Counts Grouped by Month: #{wishlist_counts.inspect}")
  
    # Step 3: Build the monthly data for the past 5 months
    monthly_wishlist_counts = (0..4).map do |i|
      month_date = (end_date - i.months).beginning_of_month
      wishlist_count = wishlist_counts.find { |key, _| key.to_date == month_date.to_date }&.last || 0
  
      {
        month: month_date.strftime('%B %Y'), # Format: "Month Year"
        wishlist_count: wishlist_count
      }
    end.reverse
  
    # Debugging output
    # Rails.logger.info("Wishlist Trends for Seller #{current_seller.id}: #{monthly_wishlist_counts.inspect}")
  
    # Return the result for the frontend
    monthly_wishlist_counts
  end




  def calculate_revenue_share(category_id)
    # Since orders are removed, return zero revenue share
    { seller_revenue: 0, total_category_revenue: 0, revenue_share: 0 }
  end

  def fetch_top_competitor_ads(category_id)
    return [] unless category_id.present?
    
    device_hash = params[:device_hash] || request.headers['X-Device-Hash']
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil
    
    # Get all active competitor ads in this category (excluding current seller)
    competitor_ads_query = Ad.active
                       .joins(:seller)
                       .where(category_id: category_id)
                       .where.not(seller_id: current_seller.id)
                       .where(sellers: { deleted: false, blocked: false })
    
    # Apply date filtering if provided
    if start_date && end_date
      competitor_ads_query = competitor_ads_query.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    end
    
    # OPTIMIZATION: Limit to top 50 by engagement before detailed scoring to reduce processing
    # Pre-load ads with basic info
    competitor_ads = competitor_ads_query
                     .includes(:category)
                     .select(:id, :title, :price, :media, :category_id, :created_at)
                     .limit(50)
                     .to_a
    
    return [] if competitor_ads.empty?
    
    # Get ad IDs for batch queries
    ad_ids = competitor_ads.map(&:id)
    
    # OPTIMIZATION: Batch load all engagement metrics in single queries
    # Batch load clicks
    clicks_query = ClickEvent.excluding_internal_users
                             .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
                             .where(ad_id: ad_ids, event_type: 'Ad-Click')
    clicks_by_ad = clicks_query.group(:ad_id).count
    
    # Batch load reveals
    reveals_query = ClickEvent.excluding_internal_users
                              .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
                              .where(ad_id: ad_ids, event_type: 'Reveal-Seller-Details')
    reveals_by_ad = reveals_query.group(:ad_id).count
    
    # Batch load wishlists
    wishlists_by_ad = WishList.joins(:ad)
                              .where(ad_id: ad_ids)
                              .where(ads: { deleted: false })
                              .group(:ad_id)
                              .count
    
    # Batch load reviews (count and average rating)
    reviews_data = Review.where(ad_id: ad_ids)
                         .group(:ad_id)
                         .select('ad_id, COUNT(*) as review_count, AVG(rating) as avg_rating')
                         .index_by(&:ad_id)
    
    # Build ad scores using pre-loaded data
    ad_scores = competitor_ads.map do |ad|
      clicks = clicks_by_ad[ad.id] || 0
      reveals = reveals_by_ad[ad.id] || 0
      wishlists = wishlists_by_ad[ad.id] || 0
      
      review_data = reviews_data[ad.id]
      reviews_count = review_data ? review_data.review_count.to_i : 0
      avg_rating = review_data ? review_data.avg_rating.to_f.round(2) : 0.0
      
      # Calculate comprehensive score (weighted)
      # Wishlists: 3 points, Clicks: 1 point, Reveals: 2 points, Reviews: 1 point per review, Rating: 0.5 per point
      score = (wishlists * 3) + (clicks * 1) + (reveals * 2) + (reviews_count * 1) + (avg_rating * 0.5)
      
      {
        ad_id: ad.id,
        ad_title: ad.title,
        ad_price: ad.price.to_f,
        ad_media: ad.media.is_a?(String) ? JSON.parse(ad.media || '[]') : (ad.media || []),
        total_wishlists: wishlists,
        total_clicks: clicks,
        total_reveals: reveals,
        total_reviews: reviews_count,
        avg_rating: avg_rating,
        engagement_score: score,
        category_id: ad.category_id,
        category_name: ad.category&.name
      }
    end
    
    # Sort by engagement score and return top 10
    ad_scores.sort_by { |ad| -ad[:engagement_score] }.first(10)
  end  
  

  def calculate_competitor_average_price(category_id)
    return 0.0 unless category_id.present?
    
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil
    
    # Get all active competitor ads in this category (excluding current seller)
    competitor_ads = Ad.active
                       .joins(:seller)
                       .where(category_id: category_id)
                       .where.not(seller_id: current_seller.id)
                       .where(sellers: { deleted: false, blocked: false })
    
    # Apply date filtering if provided
    if start_date && end_date
      competitor_ads = competitor_ads.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    end
    
    return 0.0 if competitor_ads.empty?
    
    competitor_ads.average(:price).to_f.round(2)
  end  

  # Get the primary category ID (category with most ads for this seller)
  def get_primary_category_id
    category_counts = current_seller.ads
                                    .where.not(category_id: nil)
                                    .group(:category_id)
                                    .count
    
    return nil if category_counts.empty?
    
    category_counts.max_by { |_, count| count }&.first
  end

  # Get competitor category ID from params (category_id or category_name)
  def get_competitor_category_id
    category_param = params[:competitor_category_id] || params[:competitor_category_name]
    return nil unless category_param.present?

    # Try to find by ID first
    if category_param.to_s.match?(/\A\d+\z/)
      category = Category.find_by(id: category_param.to_i)
      return category&.id
    end

    # Try to find by name (case-insensitive, partial match)
    category = Category.where("LOWER(name) LIKE ?", "%#{category_param.to_s.downcase}%").first
    category&.id
  end

  # Calculate competitor stats for a given category
  # Aggregates competitor data from all categories the seller participates in
  def calculate_competitor_stats(category_id)
    return {
      revenue_share: { seller_revenue: 0, total_category_revenue: 0, revenue_share: 0 },
      top_competitor_ads: [],
      competitor_average_price: 0,
      total_competitor_ads: 0,
      categories_analyzed: []
    } unless category_id.present?
    
    # Get all categories the seller has ads in (for context)
    seller_category_ids = current_seller.ads.active
                                      .where.not(category_id: nil)
                                      .distinct
                                      .pluck(:category_id)
    
    # OPTIMIZATION: Batch load all categories in one query
    categories_by_id = Category.where(id: seller_category_ids).index_by(&:id)
    
    # Fetch top competitor ads from the specified category
    top_ads = fetch_top_competitor_ads(category_id)
    avg_price = calculate_competitor_average_price(category_id)
    
    # Count total competitor ads in this category
    total_competitor_ads = Ad.active
                              .joins(:seller)
                              .where(category_id: category_id)
                              .where.not(seller_id: current_seller.id)
                              .where(sellers: { deleted: false, blocked: false })
                              .count
    
    {
      revenue_share: calculate_revenue_share(category_id),
      top_competitor_ads: top_ads,
      competitor_average_price: avg_price,
      total_competitor_ads: total_competitor_ads,
      categories_analyzed: seller_category_ids.map { |cat_id| 
        cat = categories_by_id[cat_id]
        next nil unless cat
        { id: cat_id, name: cat.name }
      }.compact
    }
  end



  #===================================== HELPER METHODS =================================================#
  # OPTIMIZATION: Calculate all base stats in a single optimized query
  def calculate_base_stats_optimized
    seller_id = current_seller.id
    
    # Use raw SQL with proper parameterization to avoid ActiveRecord adding ORDER BY
    sql = <<-SQL
      SELECT 
        COUNT(DISTINCT ads.id) as total_ads,
        COUNT(DISTINCT reviews.id) as total_reviews,
        COALESCE(AVG(reviews.rating), 0) as average_rating,
        COUNT(DISTINCT wish_lists.id) as total_ads_wishlisted
      FROM ads
      LEFT JOIN reviews ON reviews.ad_id = ads.id
      LEFT JOIN wish_lists ON wish_lists.ad_id = ads.id
      WHERE ads.seller_id = ?
        AND ads.deleted = false
      GROUP BY ads.seller_id
      LIMIT 1
    SQL
    
    sanitized_sql = ActiveRecord::Base.sanitize_sql_array([sql, seller_id])
    result = ActiveRecord::Base.connection.select_one(sanitized_sql)
    
    if result
      {
        total_ads: result['total_ads'].to_i,
        total_reviews: result['total_reviews'].to_i,
        average_rating: result['average_rating'].to_f.round(1),
        total_ads_wishlisted: result['total_ads_wishlisted'].to_i
      }
    else
      # Fallback if no ads exist
      {
        total_ads: 0,
        total_reviews: 0,
        average_rating: 0.0,
        total_ads_wishlisted: 0
      }
    end
  end

  def calculate_total_orders
    # Since orders are removed, return 0
    0
  end

  def calculate_total_revenue
    # Since orders are removed, return 0
    0
  end

  def calculate_total_ads
    @cached_total_ads ||= current_seller.ads.count
  end

  # OPTIMIZATION: Cache seller_ad_ids to avoid repeated queries
  def seller_ad_ids
    @cached_seller_ad_ids ||= current_seller.ads.active.pluck(:id)
  end
  
  # OPTIMIZATION: Pre-load common data for premium tier calculations
  def preload_common_data_for_premium
    return if @cached_seller_ad_ids.empty?
    
    # Pre-load click event counts per ad (for product health)
    @cached_ad_click_counts = ClickEvent.excluding_internal_users
      .excluding_seller_own_clicks(device_hash: @cached_device_hash, seller_id: current_seller.id)
      .where(ad_id: @cached_seller_ad_ids, event_type: 'Ad-Click')
      .group(:ad_id)
      .count
    
    # Pre-load review data per ad (for product health)
    review_data_array = Review.joins(:ad)
      .where(ads: { id: @cached_seller_ad_ids, deleted: false })
      .group('ads.id')
      .select('ads.id, AVG(reviews.rating) as avg_rating, COUNT(reviews.id) as review_count')
      .to_a
    @cached_ad_review_data = review_data_array.index_by(&:id)
    
    # Pre-load ads with basic info
    ads_array = current_seller.ads.active
      .select(:id, :title, :created_at, :updated_at, :flagged, :description, :price, :media, :brand, :category_id, :subcategory_id)
      .to_a
    @cached_ads = ads_array.index_by(&:id)
  end

  # OPTIMIZATION: Use SQL aggregation instead of Ruby loops
  def calculate_average_rating
    result = Review.joins(:ad)
                  .where(ads: { seller_id: current_seller.id, deleted: false })
                  .average(:rating)
    
    result ? result.to_f.round(1) : 0.0
  end

  def calculate_total_reviews
    @cached_total_reviews ||= current_seller.reviews.count
  end

  def calculate_total_ads_wishlisted
    @cached_total_ads_wishlisted ||= WishList.joins(:ad)
                                             .where(ads: { seller_id: current_seller.id, deleted: false })
                                             .count
  end

  def calculate_sales_performance
    # Since orders are removed, return empty performance data
    {}
  end

  def fetch_best_selling_ads
    # OPTIMIZATION: Get seller's ads with comprehensive scoring in a single query
    ad_ids = seller_ad_ids
    return [] if ad_ids.empty?
    
    seller_ads = current_seller.ads.active
                              .joins(:category, :subcategory)
                              .joins("LEFT JOIN reviews ON ads.id = reviews.ad_id")
                              .joins("LEFT JOIN click_events ON ads.id = click_events.ad_id")
                              .joins("LEFT JOIN wish_lists ON ads.id = wish_lists.ad_id")
                              .joins("LEFT JOIN seller_tiers ON ads.seller_id = seller_tiers.seller_id")
                              .joins("LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id")
                              .select("
                                ads.id,
                                ads.title,
                                ads.description,
                                ads.price,
                                ads.media,
                                ads.created_at,
                                ads.updated_at,
                                ads.seller_id,
                                categories.name as category_name,
                                subcategories.name as subcategory_name,
                                COALESCE(tiers.id, 1) as seller_tier_id,
                                COALESCE(tiers.name, 'Free') as seller_tier_name,
                                COALESCE(AVG(reviews.rating), 0) as avg_rating,
                                COALESCE(COUNT(DISTINCT reviews.id), 0) as review_count,
                                COALESCE(SUM(CASE WHEN click_events.event_type = 'Ad-Click' THEN 1 ELSE 0 END), 0) as ad_clicks,
                                COALESCE(SUM(CASE WHEN click_events.event_type = 'Reveal-Seller-Details' THEN 1 ELSE 0 END), 0) as reveal_clicks,
                                COALESCE(SUM(CASE WHEN click_events.event_type = 'Add-to-Wish-List' THEN 1 ELSE 0 END), 0) as wishlist_clicks,
                                COALESCE(SUM(CASE WHEN click_events.event_type = 'Add-to-Cart' THEN 1 ELSE 0 END), 0) as cart_clicks,
                                COALESCE(COUNT(DISTINCT wish_lists.id), 0) as wishlist_count
                              ")
                              .group("ads.id, categories.id, subcategories.id, tiers.id")
                              .having("AVG(reviews.rating) > 0 OR SUM(CASE WHEN click_events.event_type = 'Ad-Click' THEN 1 ELSE 0 END) > 0 OR COUNT(DISTINCT wish_lists.id) > 0")
                              .limit(50) # OPTIMIZATION: Limit to top 50 before scoring to reduce processing
    
    # OPTIMIZATION: Pre-load all contact interactions in a single query to avoid N+1
    device_hash = params[:device_hash] || request.headers['X-Device-Hash']
    contact_interactions_map = preload_contact_interactions(ad_ids, device_hash)
    
    scored_ads = seller_ads.map do |ad|
      score = calculate_comprehensive_score(ad)
      total_contact_interactions = contact_interactions_map[ad.id] || 0
      
      {
        ad_id: ad.id,
        ad_title: ad.title,
        ad_price: ad.price.to_f,
        media: ad.media,
        comprehensive_score: score,
        metrics: {
          avg_rating: ad.avg_rating.to_f.round(2),
          review_count: ad.review_count.to_i,
          ad_clicks: ad.ad_clicks.to_i,
          reveal_clicks: ad.reveal_clicks.to_i,
          wishlist_clicks: ad.wishlist_clicks.to_i,
          cart_clicks: ad.cart_clicks.to_i,
          wishlist_count: ad.wishlist_count.to_i,
          seller_tier_id: ad.seller_tier_id.to_i,
          seller_tier_name: ad.seller_tier_name,
          total_contact_interactions: total_contact_interactions
        }
      }
    end
    
    # Sort by comprehensive score and return top 10
    scored_ads.sort_by { |ad| -ad[:comprehensive_score] }.first(10)
  end

  # OPTIMIZATION: Pre-load contact interactions for all ads in a single query
  def preload_contact_interactions(ad_ids, device_hash)
    return {} if ad_ids.empty?
    
    # Single query to get all contact interactions grouped by ad_id
    contact_events = ClickEvent.excluding_internal_users
      .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
      .where(ad_id: ad_ids, event_type: 'Reveal-Seller-Details')
      .where("metadata->>'action' = ?", 'seller_contact_interaction')
      .left_joins(:buyer)
      .where("buyers.id IS NULL OR buyers.deleted = ?", false)
      .joins(:ad)
      .where(ads: { deleted: false })
      .group(:ad_id)
      .count
    
    contact_events
  end

  # Alias method for top performing ads (same as best selling ads)
  def top_performing_ads
    fetch_best_selling_ads
  end

  # Comprehensive scoring methods (copied from BestSellersController)
  def calculate_comprehensive_score(ad)
    # Comprehensive scoring algorithm combining multiple factors
    
    # 1. Sales Score (0 since sales data is not available)
    sales_score = 0

    # 2. Review Score (30% weight) - Quality indicator (increased from 25%)
    review_score = calculate_review_score(ad.avg_rating, ad.review_count)

    # 3. Engagement Score (40% weight) - User interest (increased from 20%)
    engagement_score = calculate_engagement_score(
      ad.ad_clicks,
      ad.reveal_clicks,
      ad.wishlist_clicks,
      ad.cart_clicks,
      ad.wishlist_count
    )
    
    # 4. Seller Tier Bonus (15% weight) - Premium seller boost (increased from 10%)
    tier_bonus = calculate_tier_bonus(ad.seller_tier_id.to_i)
    
    # 5. Recency Score (15% weight) - Freshness factor (increased from 5%)
    recency_score = calculate_recency_score(ad.created_at)
    
    # Calculate weighted total score (adjusted weights since sales score is 0)
    total_score = (sales_score * 0.0) + 
                  (review_score * 0.30) + 
                  (engagement_score * 0.40) + 
                  (tier_bonus * 0.15) + 
                  (recency_score * 0.15)
    
    total_score.round(2)
  end

  def calculate_sales_score(total_sold)
    # Logarithmic scaling for sales to prevent extreme outliers from dominating
    return 0 if total_sold <= 0
    
    # Base score from sales volume
    base_score = Math.log10(total_sold + 1) * 10
    
    # Cap at 100 points
    [base_score, 100].min
  end

  def calculate_review_score(avg_rating, review_count)
    return 0 if review_count <= 0
    
    # Rating score (0-50 points based on rating)
    rating_score = (avg_rating / 5.0) * 50
    
    # Review count bonus (0-50 points based on review volume)
    count_bonus = Math.log10(review_count + 1) * 10
    count_bonus = [count_bonus, 50].min
    
    rating_score + count_bonus
  end

  def calculate_engagement_score(ad_clicks, reveal_clicks, wishlist_clicks, cart_clicks, wishlist_count)
    # Combine all engagement metrics with different weights
    
    # Ad clicks (most important engagement metric)
    click_score = Math.log10(ad_clicks + 1) * 15
    
    # Reveal clicks (shows serious interest)
    reveal_score = Math.log10(reveal_clicks + 1) * 10
    
    # Wishlist interactions (shows interest)
    wishlist_score = Math.log10(wishlist_clicks + wishlist_count + 1) * 8
    
    # Cart clicks (shows purchase intent)
    cart_score = Math.log10(cart_clicks + 1) * 12
    
    total_score = click_score + reveal_score + wishlist_score + cart_score
    
    # Cap at 100 points
    [total_score, 100].min
  end

  def calculate_tier_bonus(seller_tier_id)
    # Tier bonuses to give premium sellers a boost
    case seller_tier_id
    when 4 # Premium
      20
    when 3 # Standard
      10
    when 2 # Basic
      5
    else # Free
      0
    end
  end

  def calculate_recency_score(created_at)
    # Give newer ads a small boost
    days_old = (Time.current - created_at) / 1.day
    
    case days_old
    when 0..7      # Less than a week
      10
    when 8..30     # Less than a month
      8
    when 31..90    # Less than 3 months
      5
    when 91..365   # Less than a year
      2
    else           # Older than a year
      0
    end
  end

  #========================================= NEW COMPREHENSIVE STATISTICS =========================================#

  # 1. Conversion Funnel Metrics
  def calculate_conversion_funnel_metrics(device_hash)
    ad_ids = seller_ad_ids
    return empty_funnel_metrics if ad_ids.empty?

    click_events = ClickEvent.excluding_internal_users
      .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
      .where(ad_id: ad_ids)
      .left_joins(:buyer)
      .where("buyers.id IS NULL OR buyers.deleted = ?", false)
      .joins(:ad)
      .where(ads: { deleted: false })

    total_ad_views = click_events.where(event_type: 'Ad-Click').count
    total_clicks = total_ad_views
    total_reveals = click_events.where(event_type: 'Reveal-Seller-Details').count
    total_contacts = click_events.where(event_type: 'Reveal-Seller-Details')
                                  .where("metadata->>'action' = ?", 'seller_contact_interaction')
                                  .count
    total_wishlists = click_events.where(event_type: 'Add-to-Wish-List').count

    click_through_rate = total_ad_views > 0 ? (total_clicks.to_f / total_ad_views * 100).round(2) : 0
    reveal_rate = total_clicks > 0 ? (total_reveals.to_f / total_clicks * 100).round(2) : 0
    contact_rate = total_reveals > 0 ? (total_contacts.to_f / total_reveals * 100).round(2) : 0
    wishlist_rate = total_clicks > 0 ? (total_wishlists.to_f / total_clicks * 100).round(2) : 0

    {
      total_ad_views: total_ad_views,
      total_clicks: total_clicks,
      total_reveals: total_reveals,
      total_contacts: total_contacts,
      total_wishlists: total_wishlists,
      click_through_rate: click_through_rate,
      reveal_rate: reveal_rate,
      contact_rate: contact_rate,
      wishlist_rate: wishlist_rate,
      funnel_stages: [
        { stage: 'Views', count: total_ad_views, percentage: 100.0 },
        { stage: 'Clicks', count: total_clicks, percentage: click_through_rate },
        { stage: 'Reveals', count: total_reveals, percentage: reveal_rate },
        { stage: 'Contacts', count: total_contacts, percentage: contact_rate },
        { stage: 'Wishlists', count: total_wishlists, percentage: wishlist_rate }
      ]
    }
  end

  def empty_funnel_metrics
    {
      total_ad_views: 0,
      total_clicks: 0,
      total_reveals: 0,
      total_contacts: 0,
      total_wishlists: 0,
      click_through_rate: 0,
      reveal_rate: 0,
      contact_rate: 0,
      wishlist_rate: 0,
      funnel_stages: []
    }
  end

  # 2. Product Health Indicators
  def calculate_product_health_indicators
    ads = current_seller.ads.active
    return empty_product_health if ads.empty?

    device_hash = params[:device_hash] || request.headers['X-Device-Hash']
    
    underperforming = []
    low_rated = []
    stale_products = []
    needs_attention = []
    incomplete_products = []

    ads.each do |ad|
      # Underperforming (zero or very low clicks)
      clicks = ClickEvent.excluding_internal_users
        .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
        .where(ad_id: ad.id, event_type: 'Ad-Click')
        .count
      
      if clicks < 5
        underperforming << {
          ad_id: ad.id,
          ad_title: ad.title,
          clicks: clicks,
          days_since_creation: (Time.current - ad.created_at).to_i / 1.day
        }
      end

      # Low rated
      avg_rating = ad.reviews.average(:rating).to_f
      if avg_rating > 0 && avg_rating < 3.0
        low_rated << {
          ad_id: ad.id,
          ad_title: ad.title,
          rating: avg_rating.round(1),
          review_count: ad.reviews.count
        }
      end

      # Stale (not updated in 90+ days)
      days_since_update = (Time.current - ad.updated_at).to_i / 1.day
      if days_since_update >= 90
        stale_products << {
          ad_id: ad.id,
          ad_title: ad.title,
          days_since_update: days_since_update,
          last_updated: ad.updated_at.iso8601
        }
      end

      # Needs attention (flagged or missing critical info)
      if ad.flagged? || !ad.has_valid_images? || ad.description.blank? || ad.title.blank?
        needs_attention << {
          ad_id: ad.id,
          ad_title: ad.title,
          issues: [
            ('flagged' if ad.flagged?),
            ('missing_images' unless ad.has_valid_images?),
            ('missing_description' if ad.description.blank?),
            ('missing_title' if ad.title.blank?)
          ].compact
        }
      end

      # Incomplete (missing key fields)
      completeness_score = calculate_product_completeness(ad)
      if completeness_score < 80
        incomplete_products << {
          ad_id: ad.id,
          ad_title: ad.title,
          completeness_score: completeness_score,
          missing_fields: get_missing_fields(ad)
        }
      end
    end

    {
      underperforming_products: underperforming.first(10),
      low_rated_products: low_rated.first(10),
      stale_products: stale_products.first(10),
      products_needing_attention: needs_attention.first(10),
      incomplete_products: incomplete_products.first(10),
      total_underperforming: underperforming.count,
      total_low_rated: low_rated.count,
      total_stale: stale_products.count,
      total_needs_attention: needs_attention.count,
      total_incomplete: incomplete_products.count
    }
  end
  
  # OPTIMIZED: Product Health Indicators using pre-loaded data
  def calculate_product_health_indicators_optimized
    return empty_product_health if @cached_seller_ad_ids.empty?
    
    underperforming = []
    low_rated = []
    stale_products = []
    needs_attention = []
    incomplete_products = []

    @cached_seller_ad_ids.each do |ad_id|
      ad = @cached_ads[ad_id]
      next unless ad
      
      # Underperforming (zero or very low clicks) - use cached data
      clicks = @cached_ad_click_counts[ad_id] || 0
      if clicks < 5
        underperforming << {
          ad_id: ad.id,
          ad_title: ad.title,
          clicks: clicks,
          days_since_creation: (Time.current - ad.created_at).to_i / 1.day
        }
      end

      # Low rated - use cached data
      review_data = @cached_ad_review_data[ad_id]
      if review_data
        avg_rating = review_data.avg_rating.to_f
        if avg_rating > 0 && avg_rating < 3.0
          low_rated << {
            ad_id: ad.id,
            ad_title: ad.title,
            rating: avg_rating.round(1),
            review_count: review_data.review_count.to_i
          }
        end
      end

      # Stale (not updated in 90+ days)
      days_since_update = (Time.current - ad.updated_at).to_i / 1.day
      if days_since_update >= 90
        stale_products << {
          ad_id: ad.id,
          ad_title: ad.title,
          days_since_update: days_since_update,
          last_updated: ad.updated_at.iso8601
        }
      end

      # Needs attention (flagged or missing critical info)
      has_valid_images = ad.media.present? && (JSON.parse(ad.media) rescue []).any?
      if ad.flagged || !has_valid_images || ad.description.blank? || ad.title.blank?
        needs_attention << {
          ad_id: ad.id,
          ad_title: ad.title,
          issues: [
            ('flagged' if ad.flagged),
            ('missing_images' unless has_valid_images),
            ('missing_description' if ad.description.blank?),
            ('missing_title' if ad.title.blank?)
          ].compact
        }
      end

      # Incomplete (missing key fields)
      completeness_score = calculate_product_completeness_optimized(ad)
      if completeness_score < 80
        incomplete_products << {
          ad_id: ad.id,
          ad_title: ad.title,
          completeness_score: completeness_score,
          missing_fields: get_missing_fields_optimized(ad)
        }
      end
    end

    {
      underperforming_products: underperforming.first(10),
      low_rated_products: low_rated.first(10),
      stale_products: stale_products.first(10),
      products_needing_attention: needs_attention.first(10),
      incomplete_products: incomplete_products.first(10),
      total_underperforming: underperforming.count,
      total_low_rated: low_rated.count,
      total_stale: stale_products.count,
      total_needs_attention: needs_attention.count,
      total_incomplete: incomplete_products.count
    }
  end
  
  def calculate_product_completeness_optimized(ad)
    score = 0
    total_fields = 7

    score += 10 if ad.title.present? && ad.title.length >= 10
    score += 10 if ad.description.present? && ad.description.length >= 100
    score += 10 if ad.price.present? && ad.price > 0
    has_valid_images = ad.media.present? && (JSON.parse(ad.media) rescue []).any?
    score += 10 if has_valid_images
    score += 10 if ad.brand.present?
    score += 10 if ad.category_id.present?
    score += 10 if ad.subcategory_id.present?

    (score.to_f / total_fields * 100).round
  end
  
  def get_missing_fields_optimized(ad)
    missing = []
    missing << 'title' if ad.title.blank? || ad.title.length < 10
    missing << 'description' if ad.description.blank? || ad.description.length < 100
    missing << 'price' if ad.price.blank? || ad.price <= 0
    has_valid_images = ad.media.present? && (JSON.parse(ad.media) rescue []).any?
    missing << 'images' unless has_valid_images
    missing << 'brand' if ad.brand.blank?
    missing << 'category' if ad.category_id.blank?
    missing << 'subcategory' if ad.subcategory_id.blank?
    missing
  end

  def calculate_product_completeness(ad)
    score = 0
    total_fields = 8

    score += 10 if ad.title.present? && ad.title.length >= 10
    score += 10 if ad.description.present? && ad.description.length >= 100
    score += 10 if ad.price.present? && ad.price > 0
    score += 10 if ad.has_valid_images?
    score += 10 if ad.brand.present?
    score += 10 if ad.category.present?
    score += 10 if ad.condition.present?
    score += 20 if ad.media.present? && ad.media.length >= 3

    (score.to_f / total_fields * 10).round
  end

  def get_missing_fields(ad)
    missing = []
    missing << 'title' if ad.title.blank? || ad.title.length < 10
    missing << 'description' if ad.description.blank? || ad.description.length < 100
    missing << 'price' unless ad.price.present? && ad.price > 0
    missing << 'images' unless ad.has_valid_images?
    missing << 'brand' if ad.brand.blank?
    missing << 'category' if ad.category.blank?
    missing << 'condition' if ad.condition.blank?
    missing << 'multiple_images' if ad.media.blank? || ad.media.length < 3
    missing
  end

  def empty_product_health
    {
      underperforming_products: [],
      low_rated_products: [],
      stale_products: [],
      products_needing_attention: [],
      incomplete_products: [],
      total_underperforming: 0,
      total_low_rated: 0,
      total_stale: 0,
      total_needs_attention: 0,
      total_incomplete: 0
    }
  end

  # 3. Engagement Quality Metrics
  def calculate_engagement_quality_metrics(device_hash)
    ad_ids = seller_ad_ids
    return empty_engagement_quality if ad_ids.empty?

    click_events = ClickEvent.excluding_internal_users
      .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
      .where(ad_id: ad_ids)
      .left_joins(:buyer)
      .where("buyers.id IS NULL OR buyers.deleted = ?", false)
      .joins(:ad)
      .where(ads: { deleted: false })

    # Contact interaction breakdown
    contact_events = click_events.where(event_type: 'Reveal-Seller-Details')
                                 .where("metadata->>'action' = ?", 'seller_contact_interaction')
    
    phone_calls = contact_events.where("metadata->>'action_type' = ?", 'call_phone').count
    whatsapp = contact_events.where("metadata->>'action_type' = ?", 'whatsapp').count
    email_copies = contact_events.where("metadata->>'action_type' IN ('copy_phone', 'copy_email')").count
    location_views = contact_events.where("metadata->>'action_type' = ?", 'view_location').count

    # OPTIMIZATION: Calculate average time to reveal using batch queries instead of per-ad loops
    reveal_times = []
    if ad_ids.any?
      # Get clicks and reveals for all ads in one query (limit to recent for performance)
      clicks_data = click_events.where(event_type: 'Ad-Click')
                                .where(ad_id: ad_ids)
                                .where.not(buyer_id: nil)
                                .select(:id, :ad_id, :buyer_id, :created_at)
                                .order(:created_at)
                                .limit(1000)
                                .to_a
      
      reveals_data = click_events.where(event_type: 'Reveal-Seller-Details')
                                 .where(ad_id: ad_ids)
                                 .where.not(buyer_id: nil)
                                 .select(:id, :ad_id, :buyer_id, :created_at)
                                 .order(:created_at)
                                 .limit(1000)
                                 .to_a
      
      # Group reveals by ad_id and buyer_id for faster lookup
      reveals_by_ad_buyer = reveals_data.group_by { |r| [r.ad_id, r.buyer_id] }
      
      # Calculate time differences
      clicks_data.each do |click|
        key = [click.ad_id, click.buyer_id]
        matching_reveals = reveals_by_ad_buyer[key] || []
        matching_reveal = matching_reveals.find { |r| r.created_at > click.created_at }
        if matching_reveal
          time_diff = (matching_reveal.created_at - click.created_at).to_i
          reveal_times << time_diff if time_diff > 0 && time_diff < 3600 # Within 1 hour
        end
      end
    end

    avg_time_to_reveal = reveal_times.any? ? (reveal_times.sum.to_f / reveal_times.size / 60).round(1) : 0 # in minutes

    # OPTIMIZATION: Repeat visitor rate using SQL aggregation
    buyer_click_counts = click_events.where.not(buyer_id: nil)
                                     .where(ad_id: ad_ids)
                                     .group(:buyer_id)
                                     .count
    
    unique_buyers_count = buyer_click_counts.size
    repeat_buyers_count = buyer_click_counts.count { |_, count| count > 1 }
    repeat_visitor_rate = unique_buyers_count > 0 ? (repeat_buyers_count.to_f / unique_buyers_count * 100).round(2) : 0

    # OPTIMIZATION: Average interactions per buyer using pre-calculated data
    total_interactions = click_events.where.not(buyer_id: nil).where(ad_id: ad_ids).count
    interactions_per_buyer = unique_buyers_count > 0 ? (total_interactions.to_f / unique_buyers_count).round(2) : 0

    {
      contact_interaction_breakdown: {
        phone_calls: phone_calls,
        whatsapp: whatsapp,
        email_copies: email_copies,
        location_views: location_views,
        total_contacts: phone_calls + whatsapp + email_copies + location_views
      },
      average_time_to_reveal_minutes: avg_time_to_reveal,
      repeat_visitor_rate: repeat_visitor_rate,
      unique_buyers: unique_buyers_count,
      repeat_buyers: repeat_buyers_count,
      average_interactions_per_buyer: interactions_per_buyer
    }
  end

  def empty_engagement_quality
    {
      contact_interaction_breakdown: {
        phone_calls: 0,
        whatsapp: 0,
        email_copies: 0,
        location_views: 0,
        total_contacts: 0
      },
      average_time_to_reveal_minutes: 0,
      repeat_visitor_rate: 0,
      unique_buyers: 0,
      repeat_buyers: 0,
      average_interactions_per_buyer: 0
    }
  end

  # 4. Temporal Analytics
  def calculate_temporal_analytics
    ad_ids = seller_ad_ids
    return empty_temporal_analytics if ad_ids.empty?

    device_hash = params[:device_hash] || request.headers['X-Device-Hash']
    click_events = ClickEvent.excluding_internal_users
      .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
      .where(ad_id: ad_ids)
      .left_joins(:buyer)
      .where("buyers.id IS NULL OR buyers.deleted = ?", false)
      .joins(:ad)
      .where(ads: { deleted: false })

    # Peak traffic hours (0-23)
    hourly_distribution = click_events.group("EXTRACT(HOUR FROM click_events.created_at)").count
    peak_hour = hourly_distribution.max_by { |_, count| count }&.first || 0
    peak_hour_count = hourly_distribution[peak_hour] || 0

    # Best performing days (0=Sunday, 6=Saturday)
    daily_distribution = click_events.group("EXTRACT(DOW FROM click_events.created_at)").count
    best_day = daily_distribution.max_by { |_, count| count }&.first || 0
    best_day_name = Date::DAYNAMES[best_day.to_i]
    best_day_count = daily_distribution[best_day] || 0

    # Monthly trends (last 6 months)
    monthly_trends = (0..5).map do |i|
      month_start = (Time.current - i.months).beginning_of_month
      month_end = month_start.end_of_month
      count = click_events.where("click_events.created_at >= ? AND click_events.created_at <= ?", month_start, month_end).count
      {
        month: month_start.strftime('%B %Y'),
        count: count,
        month_number: month_start.month,
        year: month_start.year
      }
    end.reverse

    {
      peak_traffic_hour: peak_hour,
      peak_hour_count: peak_hour_count,
      hourly_distribution: (0..23).map { |h| { hour: h, count: hourly_distribution[h] || 0 } },
      best_performing_day: best_day_name,
      best_day_count: best_day_count,
      daily_distribution: (0..6).map { |d| { day: Date::DAYNAMES[d], count: daily_distribution[d] || 0 } },
      monthly_trends: monthly_trends,
      total_this_month: monthly_trends.last[:count],
      total_last_month: monthly_trends[-2][:count]
    }
  end

  def empty_temporal_analytics
    {
      peak_traffic_hour: 0,
      peak_hour_count: 0,
      hourly_distribution: [],
      best_performing_day: 'Monday',
      best_day_count: 0,
      daily_distribution: [],
      monthly_trends: [],
      total_this_month: 0,
      total_last_month: 0
    }
  end

  # 5. Category Performance
  def calculate_category_performance
    ads = current_seller.ads.active.includes(:category, :subcategory)
    return empty_category_performance if ads.empty?

    device_hash = params[:device_hash] || request.headers['X-Device-Hash']
    
    category_stats = {}
    
    ads.group_by(&:category).each do |category, category_ads|
      next unless category
      
      ad_ids = category_ads.map(&:id)
      click_events = ClickEvent.excluding_internal_users
        .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
        .where(ad_id: ad_ids)
        .left_joins(:buyer)
        .where("buyers.id IS NULL OR buyers.deleted = ?", false)
        .joins(:ad)
        .where(ads: { deleted: false })

      total_clicks = click_events.where(event_type: 'Ad-Click').count
      total_reveals = click_events.where(event_type: 'Reveal-Seller-Details').count
      total_wishlists = WishList.where(ad_id: ad_ids).count
      total_reviews = Review.where(ad_id: ad_ids).count
      avg_rating = Review.where(ad_id: ad_ids).average(:rating).to_f.round(1)

      category_stats[category.name] = {
        category_id: category.id,
        category_name: category.name,
        ad_count: category_ads.count,
        total_clicks: total_clicks,
        total_reveals: total_reveals,
        total_wishlists: total_wishlists,
        total_reviews: total_reviews,
        average_rating: avg_rating,
        engagement_score: (total_clicks + total_reveals * 2 + total_wishlists * 1.5).round(2)
      }
    end

    sorted_categories = category_stats.values.sort_by { |c| -c[:engagement_score] }

    {
      category_performance: sorted_categories,
      best_category: sorted_categories.first,
      total_categories: category_stats.count,
      category_growth_trends: calculate_category_growth_trends(category_stats.keys)
    }
  end

  def calculate_category_growth_trends(category_names)
    # Simplified - compare last month vs previous month
    device_hash = params[:device_hash] || request.headers['X-Device-Hash']
    last_month_start = (Time.current - 1.month).beginning_of_month
    last_month_end = last_month_start.end_of_month
    prev_month_start = (Time.current - 2.months).beginning_of_month
    prev_month_end = prev_month_start.end_of_month

    category_names.map do |category_name|
      category = Category.find_by(name: category_name)
      next unless category
      
      ad_ids = current_seller.ads.active.where(category_id: category.id).pluck(:id)
      next if ad_ids.empty?

      last_month_clicks = ClickEvent.excluding_internal_users
        .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
        .where(ad_id: ad_ids, event_type: 'Ad-Click')
        .where('click_events.created_at >= ? AND click_events.created_at <= ?', last_month_start, last_month_end)
        .count

      prev_month_clicks = ClickEvent.excluding_internal_users
        .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
        .where(ad_id: ad_ids, event_type: 'Ad-Click')
        .where('click_events.created_at >= ? AND click_events.created_at <= ?', prev_month_start, prev_month_end)
        .count

      growth = prev_month_clicks > 0 ? ((last_month_clicks - prev_month_clicks).to_f / prev_month_clicks * 100).round(2) : (last_month_clicks > 0 ? 100 : 0)

      {
        category_name: category_name,
        last_month_clicks: last_month_clicks,
        previous_month_clicks: prev_month_clicks,
        growth_percentage: growth
      }
    end.compact
  end

  def empty_category_performance
    {
      category_performance: [],
      best_category: nil,
      total_categories: 0,
      category_growth_trends: []
    }
  end

  # 6. Pricing Intelligence
  def calculate_pricing_intelligence(primary_category_id)
    return empty_pricing_intelligence unless primary_category_id

    seller_ads = current_seller.ads.active.where(category_id: primary_category_id)
    return empty_pricing_intelligence if seller_ads.empty?

    seller_avg_price = seller_ads.average(:price).to_f.round(2)
    seller_min_price = seller_ads.minimum(:price).to_f.round(2)
    seller_max_price = seller_ads.maximum(:price).to_f.round(2)

    competitor_ads = Ad.active
                       .where(category_id: primary_category_id)
                       .where.not(seller_id: current_seller.id)
    
    competitor_avg_price = competitor_ads.any? ? competitor_ads.average(:price).to_f.round(2) : 0
    competitor_min_price = competitor_ads.any? ? competitor_ads.minimum(:price).to_f.round(2) : 0
    competitor_max_price = competitor_ads.any? ? competitor_ads.maximum(:price).to_f.round(2) : 0

    price_difference = competitor_avg_price > 0 ? (seller_avg_price - competitor_avg_price).round(2) : 0
    price_difference_percentage = competitor_avg_price > 0 ? ((price_difference / competitor_avg_price) * 100).round(2) : 0

    # Active offers impact
    active_offers = Offer.active_now.joins(:offer_ads)
                         .where(offer_ads: { ad_id: seller_ads.pluck(:id) })
    
    offer_performance = active_offers.map do |offer|
      offer_ads = offer.offer_ads.joins(:ad).where(ads: { seller_id: current_seller.id })
      device_hash = params[:device_hash] || request.headers['X-Device-Hash']
      
      clicks = ClickEvent.excluding_internal_users
        .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
        .where(ad_id: offer_ads.pluck(:ad_id), event_type: 'Ad-Click')
        .where('click_events.created_at >= ?', offer.start_time)
        .count

      {
        offer_id: offer.id,
        offer_name: offer.name,
        discount_percentage: offer.discount_percentage,
        clicks_since_offer: clicks
      }
    end

    {
      seller_pricing: {
        average_price: seller_avg_price,
        min_price: seller_min_price,
        max_price: seller_max_price,
        price_range: seller_max_price - seller_min_price
      },
      competitor_pricing: {
        average_price: competitor_avg_price,
        min_price: competitor_min_price,
        max_price: competitor_max_price,
        price_range: competitor_max_price - competitor_min_price
      },
      price_comparison: {
        price_difference: price_difference,
        price_difference_percentage: price_difference_percentage,
        positioning: price_difference > 0 ? 'above_average' : price_difference < 0 ? 'below_average' : 'at_average'
      },
      active_offers_count: active_offers.count,
      offer_performance: offer_performance
    }
  end

  def empty_pricing_intelligence
    {
      seller_pricing: {
        average_price: 0,
        min_price: 0,
        max_price: 0,
        price_range: 0
      },
      competitor_pricing: {
        average_price: 0,
        min_price: 0,
        max_price: 0,
        price_range: 0
      },
      price_comparison: {
        price_difference: 0,
        price_difference_percentage: 0,
        positioning: 'unknown'
      },
      active_offers_count: 0,
      offer_performance: []
    }
  end

  # 7. Customer Insights
  def calculate_customer_insights(device_hash)
    ad_ids = seller_ad_ids
    return empty_customer_insights if ad_ids.empty?

    click_events = ClickEvent.excluding_internal_users
      .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
      .where(ad_id: ad_ids)
      .left_joins(:buyer)
      .where("buyers.id IS NULL OR buyers.deleted = ?", false)
      .joins(:ad)
      .where(ads: { deleted: false })

    # New vs returning buyers
    unique_buyers = click_events.where.not(buyer_id: nil).distinct.pluck(:buyer_id)
    new_buyers = unique_buyers.count { |buyer_id|
      first_interaction = click_events.where(buyer_id: buyer_id).order(:created_at).first
      first_interaction && first_interaction.created_at >= 30.days.ago
    }
    returning_buyers = unique_buyers.count - new_buyers

    # Buyer journey length (simplified - time from first click to reveal)
    journey_lengths = []
    unique_buyers.each do |buyer_id|
      buyer_events = click_events.where(buyer_id: buyer_id).order(:created_at)
      first_click = buyer_events.where(event_type: 'Ad-Click').first
      first_reveal = buyer_events.where(event_type: 'Reveal-Seller-Details').first
      
      if first_click && first_reveal && first_reveal.created_at > first_click.created_at
        journey_time = (first_reveal.created_at - first_click.created_at).to_i / 60 # minutes
        journey_lengths << journey_time if journey_time < 1440 # Within 24 hours
      end
    end

    avg_journey_length = journey_lengths.any? ? (journey_lengths.sum.to_f / journey_lengths.size).round(1) : 0

    # Geographic distribution (if available in buyer data)
    # This would require location data in buyer model - simplified for now
    geographic_distribution = {}

    {
      new_buyers: new_buyers,
      returning_buyers: returning_buyers,
      total_unique_buyers: unique_buyers.count,
      new_vs_returning_ratio: unique_buyers.any? ? (new_buyers.to_f / unique_buyers.count * 100).round(2) : 0,
      average_journey_length_minutes: avg_journey_length,
      geographic_distribution: geographic_distribution
    }
  end

  def empty_customer_insights
    {
      new_buyers: 0,
      returning_buyers: 0,
      total_unique_buyers: 0,
      new_vs_returning_ratio: 0,
      average_journey_length_minutes: 0,
      geographic_distribution: {}
    }
  end

  # 8. Operational Metrics
  def calculate_operational_metrics
    ads = current_seller.ads.active
    profile = current_seller

    # Profile completeness
    profile_fields = {
      enterprise_name: profile.enterprise_name.present?,
      description: profile.description.present?,
      phone_number: profile.phone_number.present?,
      email: profile.email.present?,
      profile_picture: profile.profile_picture.present?
    }
    profile_completeness = (profile_fields.values.count(true).to_f / profile_fields.size * 100).round

    # Ad update frequency
    recent_updates = ads.where('updated_at >= ?', 30.days.ago).count
    update_frequency = ads.any? ? (recent_updates.to_f / ads.count * 100).round(2) : 0

    # Last activity
    last_ad_update = ads.maximum(:updated_at)
    last_activity_days_ago = last_ad_update ? ((Time.current - last_ad_update).to_i / 1.day) : 0

    # Response rate (if conversations exist)
    conversations = Conversation.joins(:ad).where(ads: { seller_id: current_seller.id })
    total_messages = Message.where(conversation_id: conversations.pluck(:id), sender_type: 'Seller').count
    response_rate = conversations.any? ? (total_messages.to_f / conversations.count * 100).round(2) : 0

    {
      profile_completeness: profile_completeness,
      profile_missing_fields: profile_fields.select { |_, present| !present }.keys.map(&:to_s),
      ad_update_frequency: update_frequency,
      ads_updated_last_30_days: recent_updates,
      last_activity_days_ago: last_activity_days_ago,
      last_activity_date: last_ad_update&.iso8601,
      response_rate: response_rate,
      total_conversations: conversations.count,
      total_responses: total_messages
    }
  end

  # 9. Competitive Intelligence
  def calculate_competitive_intelligence(primary_category_id)
    return empty_competitive_intelligence unless primary_category_id

    seller_ads = current_seller.ads.active.where(category_id: primary_category_id)
    return empty_competitive_intelligence if seller_ads.empty?

    device_hash = params[:device_hash] || request.headers['X-Device-Hash']
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil
    
    # Market share trends
    seller_clicks = ClickEvent.excluding_internal_users
      .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
      .where(ad_id: seller_ads.pluck(:id), event_type: 'Ad-Click')
    
    # Apply date filtering if provided
    if start_date && end_date
      seller_clicks = seller_clicks.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    end
    
    seller_clicks_count = seller_clicks.count

    category_ads = Ad.active
                     .joins(:seller)
                     .where(category_id: primary_category_id)
                     .where(sellers: { deleted: false, blocked: false })

    category_clicks = ClickEvent.excluding_internal_users
      .where(ad_id: category_ads.pluck(:id), event_type: 'Ad-Click')
    
    # Apply date filtering if provided
    if start_date && end_date
      category_clicks = category_clicks.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    end
    
    category_clicks_count = category_clicks.count

    market_share = category_clicks_count > 0 ? (seller_clicks_count.to_f / category_clicks_count * 100).round(2) : 0

    # Competitor price trends (last 3 months)
    competitor_ads = Ad.active
                       .joins(:seller)
                       .where(category_id: primary_category_id)
                       .where.not(seller_id: current_seller.id)
                       .where(sellers: { deleted: false, blocked: false })
    
    price_trends = (0..2).map do |i|
      month_start = (Time.current - i.months).beginning_of_month
      month_end = month_start.end_of_month
      avg_price = competitor_ads.where(created_at: ..month_end).average(:price).to_f.round(2)
      {
        month: month_start.strftime('%B %Y'),
        average_price: avg_price
      }
    end.reverse

    # Competitor engagement rates (top 10 by engagement, then top 5 by CTR)
    competitor_ads_sample = competitor_ads.limit(20).to_a
    
    competitor_engagement = competitor_ads_sample.map do |ad|
      clicks = ClickEvent.excluding_internal_users
                         .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
        .where(ad_id: ad.id, event_type: 'Ad-Click')
      
      # Apply date filtering if provided
      if start_date && end_date
        clicks = clicks.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
      end
      
      clicks_count = clicks.count
      
      reveals = ClickEvent.excluding_internal_users
                          .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
        .where(ad_id: ad.id, event_type: 'Reveal-Seller-Details')
      
      # Apply date filtering if provided
      if start_date && end_date
        reveals = reveals.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
      end
      
      reveals_count = reveals.count
      
      ctr = clicks_count > 0 ? (reveals_count.to_f / clicks_count * 100).round(2) : 0
      
      {
        ad_id: ad.id,
        ad_title: ad.title,
        price: ad.price.to_f,
        clicks: clicks_count,
        reveals: reveals_count,
        ctr: ctr
      }
    end.sort_by { |a| -a[:ctr] }.first(5)

    avg_competitor_ctr = competitor_engagement.any? ? (competitor_engagement.sum { |a| a[:ctr] } / competitor_engagement.size).round(2) : 0

    # Your CTR for comparison
    your_reveals_query = ClickEvent.excluding_internal_users
      .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
      .where(ad_id: seller_ads.pluck(:id), event_type: 'Reveal-Seller-Details')
    
    # Apply date filtering if provided
    if start_date && end_date
      your_reveals_query = your_reveals_query.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    end
    
    your_reveals_count = your_reveals_query.count
    your_ctr = seller_clicks_count > 0 ? (your_reveals_count.to_f / seller_clicks_count * 100).round(2) : 0

    {
      market_share_percentage: market_share,
      your_clicks: seller_clicks_count,
      category_total_clicks: category_clicks_count,
      competitor_price_trends: price_trends,
      competitor_engagement_rates: competitor_engagement,
      average_competitor_ctr: avg_competitor_ctr,
      your_ctr: your_ctr,
      ctr_gap: (your_ctr - avg_competitor_ctr).round(2)
    }
  end

  def empty_competitive_intelligence
    {
      market_share_percentage: 0,
      your_clicks: 0,
      category_total_clicks: 0,
      competitor_price_trends: [],
      competitor_engagement_rates: [],
      average_competitor_ctr: 0,
      your_ctr: 0,
      ctr_gap: 0
    }
  end

  # 10. Advanced Engagement Metrics
  def calculate_advanced_engagement_metrics(device_hash)
    ad_ids = seller_ad_ids
    return empty_advanced_engagement if ad_ids.empty?

    click_events = ClickEvent.excluding_internal_users
      .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
      .where(ad_id: ad_ids)
      .left_joins(:buyer)
      .where("buyers.id IS NULL OR buyers.deleted = ?", false)
      .joins(:ad)
      .where(ads: { deleted: false })

    # Bounce indicators (high clicks, low reveals)
    bounce_products = ad_ids.map do |ad_id|
      clicks = click_events.where(ad_id: ad_id, event_type: 'Ad-Click').count
      reveals = click_events.where(ad_id: ad_id, event_type: 'Reveal-Seller-Details').count
      bounce_rate = clicks > 0 ? ((clicks - reveals).to_f / clicks * 100).round(2) : 0
      
      ad = Ad.find_by(id: ad_id)
      next unless ad
      
      {
        ad_id: ad_id,
        ad_title: ad.title,
        clicks: clicks,
        reveals: reveals,
        bounce_rate: bounce_rate
      }
    end.compact.select { |p| p[:clicks] >= 10 && p[:bounce_rate] > 50 }.sort_by { |p| -p[:bounce_rate] }.first(10)

    # Wishlist conversion
    total_wishlisted = WishList.where(ad_id: ad_ids).count
    wishlist_contacts = click_events.where(event_type: 'Reveal-Seller-Details')
                                    .where("metadata->>'action' = ?", 'seller_contact_interaction')
                                    .joins("INNER JOIN wish_lists ON wish_lists.ad_id = click_events.ad_id")
                                    .where("wish_lists.created_at <= click_events.created_at")
                                    .count
    wishlist_conversion_rate = total_wishlisted > 0 ? (wishlist_contacts.to_f / total_wishlisted * 100).round(2) : 0

    # Multi-product engagement
    buyer_product_counts = click_events.where.not(buyer_id: nil)
                                      .group(:buyer_id)
                                      .select('buyer_id, COUNT(DISTINCT ad_id) as product_count')
                                      .map { |r| r.product_count }
    multi_product_buyers = buyer_product_counts.count { |c| c > 1 }
    multi_product_rate = buyer_product_counts.any? ? (multi_product_buyers.to_f / buyer_product_counts.size * 100).round(2) : 0
    avg_products_per_buyer = buyer_product_counts.any? ? (buyer_product_counts.sum.to_f / buyer_product_counts.size).round(2) : 0

    {
      bounce_products: bounce_products,
      total_bounce_products: bounce_products.count,
      wishlist_conversion_rate: wishlist_conversion_rate,
      total_wishlisted: total_wishlisted,
      wishlist_contacts: wishlist_contacts,
      multi_product_engagement_rate: multi_product_rate,
      multi_product_buyers: multi_product_buyers,
      average_products_per_buyer: avg_products_per_buyer
    }
  end

  def empty_advanced_engagement
    {
      bounce_products: [],
      total_bounce_products: 0,
      wishlist_conversion_rate: 0,
      total_wishlisted: 0,
      wishlist_contacts: 0,
      multi_product_engagement_rate: 0,
      multi_product_buyers: 0,
      average_products_per_buyer: 0
    }
  end

  # 11. Review and Reputation Metrics
  def calculate_review_reputation_metrics
    ads = current_seller.ads.active
    reviews = Review.joins(:ad).where(ads: { seller_id: current_seller.id })

    # Review response rate
    reviews_with_replies = reviews.where.not(seller_reply: [nil, '']).count
    response_rate = reviews.any? ? (reviews_with_replies.to_f / reviews.count * 100).round(2) : 0

    # Review sentiment trends (last 6 months)
    monthly_sentiment = (0..5).map do |i|
      month_start = (Time.current - i.months).beginning_of_month
      month_end = month_start.end_of_month
      month_reviews = reviews.where(created_at: month_start..month_end)
      positive = month_reviews.where('rating >= 4').count
      neutral = month_reviews.where(rating: 3).count
      negative = month_reviews.where('rating <= 2').count
      
      {
        month: month_start.strftime('%B %Y'),
        total: month_reviews.count,
        positive: positive,
        neutral: neutral,
        negative: negative,
        sentiment_score: month_reviews.any? ? (month_reviews.average(:rating).to_f.round(1)) : 0
      }
    end.reverse

    # Review distribution
    rating_distribution = (1..5).map do |rating|
      {
        rating: rating,
        count: reviews.where(rating: rating).count
      }
    end

    # Review recency
    last_review = reviews.order(:created_at).last
    days_since_last_review = last_review ? ((Time.current - last_review.created_at).to_i / 1.day) : nil

    {
      total_reviews: reviews.count,
      reviews_with_replies: reviews_with_replies,
      response_rate: response_rate,
      monthly_sentiment_trends: monthly_sentiment,
      rating_distribution: rating_distribution,
      days_since_last_review: days_since_last_review,
      last_review_date: last_review&.created_at&.iso8601,
      average_rating: reviews.any? ? reviews.average(:rating).to_f.round(1) : 0
    }
  end

  # 12. Offer/Promotion Analytics
  def calculate_offer_promotion_analytics
    seller_ads = current_seller.ads.active
    offers = Offer.joins(:offer_ads).where(offer_ads: { ad_id: seller_ads.pluck(:id) })

    device_hash = params[:device_hash] || request.headers['X-Device-Hash']

    # Active offers performance
    active_offers = offers.active_now
    active_offer_performance = active_offers.map do |offer|
      offer_ads = offer.offer_ads.joins(:ad).where(ads: { seller_id: current_seller.id })
      ad_ids = offer_ads.pluck(:ad_id)

      # Engagement before and during offer
      before_clicks = ClickEvent.excluding_internal_users
        .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
        .where(ad_id: ad_ids, event_type: 'Ad-Click')
        .where('click_events.created_at < ?', offer.start_time)
        .where('click_events.created_at >= ?', offer.start_time - 7.days)
        .count

      during_clicks = ClickEvent.excluding_internal_users
        .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
        .where(ad_id: ad_ids, event_type: 'Ad-Click')
        .where('click_events.created_at >= ?', offer.start_time)
        .where('click_events.created_at <= ?', [offer.end_time, Time.current].min)
        .count

      engagement_lift = before_clicks > 0 ? ((during_clicks - before_clicks).to_f / before_clicks * 100).round(2) : (during_clicks > 0 ? 100 : 0)

      # Calculate days active safely
      days_active = begin
        ((Time.current - offer.start_time).to_i / 1.day)
      rescue
        0
      end

      {
        offer_id: offer.id,
        offer_name: offer.name,
        offer_type: offer.offer_type,
        discount_percentage: offer.discount_percentage,
        clicks_before: before_clicks,
        clicks_during: during_clicks,
        engagement_lift: engagement_lift,
        days_active: days_active
      }
    end

    # Best offer types
    # Get unique offer IDs first (to avoid DISTINCT on JSON columns), then load full records
    unique_offer_ids = offers.select('offers.id').distinct.pluck(:id)
    offers_list = Offer.where(id: unique_offer_ids).to_a
    offer_type_performance = offers_list.group_by(&:offer_type).map do |offer_type, type_offers|
      type_offer_ids = type_offers.map(&:id)
      type_offer_ads = OfferAd.joins(:ad).where(offer_id: type_offer_ids, ads: { seller_id: current_seller.id })
      ad_ids = type_offer_ads.pluck(:ad_id)
      
      total_clicks = ClickEvent.excluding_internal_users
        .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
        .where(ad_id: ad_ids, event_type: 'Ad-Click')
        .count

      {
        offer_type: offer_type,
        count: type_offers.count,
        total_clicks: total_clicks,
        average_clicks_per_offer: type_offers.count > 0 ? (total_clicks.to_f / type_offers.count).round(2) : 0
      }
    end.sort_by { |o| -o[:total_clicks] }

    {
      active_offers_count: active_offers.count,
      active_offer_performance: active_offer_performance,
      total_offers: offers.count,
      offer_type_performance: offer_type_performance,
      best_offer_type: offer_type_performance.first&.dig(:offer_type)
    }
  end

  def authenticate_seller
    begin
      @current_seller = SellerAuthorizeApiRequest.new(request.headers).result
      unless @current_seller && @current_seller.is_a?(Seller)
        render json: { error: 'Not Authorized' }, status: 401
        return
      end
    rescue ExceptionHandler::InvalidToken, ExceptionHandler::MissingToken => e
      Rails.logger.error "Authentication error: #{e.message}"
      render json: { error: 'Authentication failed' }, status: 401
      return
    rescue => e
      Rails.logger.error "Unexpected authentication error: #{e.message}"
      render json: { error: 'Authentication failed' }, status: 401
      return
    end
  end

  def current_seller
    if @current_seller.nil?
      Rails.logger.error "current_seller called but @current_seller is nil"
      raise "Authentication required"
    end
    @current_seller
  end
end