class Seller::AnalyticsController < ApplicationController
  before_action :authenticate_seller

  def index
    begin
      # Get seller's tier_id
      tier_id = current_seller.seller_tier&.tier_id || 1

      Rails.logger.info "Analytics request for seller #{current_seller.id} with tier #{tier_id}"

      # Base response data - always include these fields for dashboard
      response_data = {
        tier_id: tier_id,
        total_orders: calculate_total_orders,
        total_ads: calculate_total_ads,
        total_reviews: calculate_total_reviews,
        average_rating: calculate_average_rating,
        total_ads_wishlisted: calculate_total_ads_wishlisted
      }

      # Add more data based on the seller's tier
      case tier_id
      when 1 # Free tier
        # Free tier already has base data above
      when 2 # Basic tier
        response_data.merge!(calculate_basic_tier_data)
      when 3 # Standard tier
        response_data.merge!(calculate_standard_tier_data)
        response_data.merge!(click_events_stats: top_click_event_stats)
      when 4 # Premium tier
        response_data.merge!(calculate_premium_tier_data)
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
      total_revenue: calculate_total_revenue,
      total_reviews: calculate_total_reviews,
      sales_performance: calculate_sales_performance,
      best_selling_ads: fetch_best_selling_ads
    }
  end

  # Data for Premium tier
  def calculate_premium_tier_data
    {
      total_revenue: calculate_total_revenue,
      average_rating: calculate_average_rating,
      total_reviews: calculate_total_reviews,
      sales_performance: calculate_sales_performance,
      best_selling_ads: fetch_best_selling_ads,
      wishlist_stats: top_wishlist_stats, # Merge wishlist stats into the response
      click_events_stats: top_click_event_stats,
      basic_wishlist_stats: basic_wishlist_stats,
      basic_click_event_stats: basic_click_event_stats
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
    stats = {
      top_age_group_clicks: top_clicks_by_age,
      top_income_range_clicks: top_clicks_by_income,
      top_education_level_clicks: top_clicks_by_education,
      top_employment_status_clicks: top_clicks_by_employment,
      top_sector_clicks: top_clicks_by_sector
    }

    # Rails.logger.info "Final Click Events Stats: #{stats}"
    stats
  end

  def basic_click_event_stats
    {
      click_event_trends: click_event_trends
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
    Seller.joins(ads: :wish_lists)
          .where(ads: { category_id: category_id })
          .where.not(id: current_seller.id)
          .select('ads.id AS ad_id, ads.title AS ad_title, COUNT(wish_lists.id) AS total_wishlists, ads.price AS ad_price, ads.media AS ad_media')
          .group('ads.id')
          .order('total_wishlists DESC')
          .limit(3)
          .map { |record| 
            { 
              ad_id: record.ad_id,
              ad_title: record.ad_title,
              total_wishlists: record.total_wishlists,
              ad_price: record.ad_price,
              ad_media: JSON.parse(record.ad_media || '[]') # Parse the media as an array
            } 
          }
  end  
  

  def calculate_competitor_average_price(category_id)
    Seller.joins(:ads)
          .where(ads: { category_id: category_id })
          .where.not(id: current_seller.id)
          .average('ads.price')
          .to_f.round(2)
  end  




  #===================================== HELPER METHODS =================================================#
  def calculate_total_orders
    # Since orders are removed, return 0
    0
  end

  def calculate_total_revenue
    # Since orders are removed, return 0
    0
  end

  def calculate_total_ads
    current_seller.ads.count
  end

  def seller_ad_ids
    current_seller.ads.pluck(:id)
  end

  def calculate_average_rating
    ads = current_seller.ads.includes(:reviews)

    if ads.empty?
      return 0.0
    end

    # Calculate average rating for each ad that has reviews, then average those
    ad_ratings = ads.map do |ad|
      if ad.reviews.loaded?
        ad.reviews.any? ? ad.reviews.sum(&:rating).to_f / ad.reviews.size : nil
      else
        ad.reviews.average(:rating).to_f if ad.reviews.exists?
      end
    end.compact # Remove nil values (ads with no reviews)

    # Return average of rated ads only, rounded to 1 decimal place
    if ad_ratings.any?
      (ad_ratings.sum / ad_ratings.size).round(1)
    else
      0.0 # No rated ads yet
    end
  end

  def calculate_total_reviews
    current_seller.reviews.count
  end

  def calculate_total_ads_wishlisted
    WishList.joins(:ad).where(ads: { seller_id: current_seller.id }).count
  end

  def calculate_sales_performance
    # Since orders are removed, return empty performance data
    {}
  end

  def fetch_best_selling_ads
    # Use the new comprehensive scoring algorithm
    best_sellers_controller = BestSellersController.new
    best_sellers_controller.params = ActionController::Parameters.new(limit: 3)
    
    # Get seller's ads with comprehensive scoring
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
    
    # Calculate comprehensive scores and sort
    scored_ads = seller_ads.map do |ad|
      score = calculate_comprehensive_score(ad)
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
          seller_tier_name: ad.seller_tier_name
        }
      }
    end
    
    # Sort by comprehensive score and return top 3
    scored_ads.sort_by { |ad| -ad[:comprehensive_score] }.first(3)
  end

  # Comprehensive scoring methods (copied from BestSellersController)
  def calculate_comprehensive_score(ad)
    # Comprehensive scoring algorithm combining multiple factors
    
    # 1. Sales Score (40% weight) - Most important factor
    sales_score = calculate_sales_score(ad.total_sold.to_i)

    # 2. Review Score (25% weight) - Quality indicator
    review_score = calculate_review_score(ad.avg_rating, ad.review_count)

    # 3. Engagement Score (20% weight) - User interest
    engagement_score = calculate_engagement_score(
      ad.ad_clicks,
      ad.reveal_clicks,
      ad.wishlist_clicks,
      ad.cart_clicks,
      ad.wishlist_count
    )
    
    # 4. Seller Tier Bonus (10% weight) - Premium seller boost
    tier_bonus = calculate_tier_bonus(ad.seller_tier_id.to_i)
    
    # 5. Recency Score (5% weight) - Freshness factor
    recency_score = calculate_recency_score(ad.created_at)
    
    # Calculate weighted total score
    total_score = (sales_score * 0.40) + 
                  (review_score * 0.25) + 
                  (engagement_score * 0.20) + 
                  (tier_bonus * 0.10) + 
                  (recency_score * 0.05)
    
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