class BestSellersController < ApplicationController
  # GET /best_sellers
  def index
    limit = params[:limit]&.to_i || 20
    limit = [limit, 100].min # Cap at 100 for performance
    
    # Use optimized calculation for fast response
    @best_sellers = calculate_best_sellers_fast(limit)
    
    render json: {
      best_sellers: @best_sellers,
      total_count: @best_sellers.count,
      algorithm_version: "v3.0-fast",
      cached: false
    }
  end

  # GET /best_sellers/global
  def global
    limit = params[:limit]&.to_i || 50
    limit = [limit, 200].min # Cap at 200 for performance
    
    # Use optimized calculation for fast response
    @global_best_sellers = calculate_global_best_sellers_fast(limit)
    
    render json: {
      global_best_sellers: @global_best_sellers,
      total_count: @global_best_sellers.count,
      algorithm_version: "v3.0-fast",
      cached: false
    }
  end

  # GET /best_sellers/refresh - Admin endpoint to refresh cache
  def refresh
    # Only allow admin access
    unless current_admin
      render json: { error: 'Unauthorized' }, status: 401
      return
    end
    
    # Clear expired cache entries
    BestSellersCache.delete_expired
    
    # Precompute common limits
    [10, 20, 50].each do |limit|
      best_sellers = calculate_best_sellers_fast(limit)
      BestSellersCache.set("best_sellers_v3_#{limit}", best_sellers, expires_in: 30.minutes)
      
      global_best_sellers = calculate_global_best_sellers_fast(limit)
      BestSellersCache.set("global_best_sellers_v3_#{limit}", global_best_sellers, expires_in: 1.hour)
    end
    
    render json: { message: 'Best sellers cache refreshed successfully' }
  end

  private

  def calculate_best_sellers_fast(limit)
    # Fast approach: Use precomputed scores and simple queries
    # First get ads with basic metrics using optimized queries
    
    # Get ads with sales data (most important metric)
    ads_with_sales = Ad.active
                      .joins(:seller, :order_items)
                      .where(sellers: { blocked: false, deleted: false })
                      .where(flagged: false)
                      .group('ads.id')
                      .having('SUM(order_items.quantity) > 0')
                      .select('ads.id, SUM(order_items.quantity) as total_sold')
                      .order('SUM(order_items.quantity) DESC')
                      .limit(limit * 2) # Get more to account for other metrics
    
    # Get ads with reviews (second most important)
    ads_with_reviews = Ad.active
                        .joins(:seller, :reviews)
                        .where(sellers: { blocked: false, deleted: false })
                        .where(flagged: false)
                        .group('ads.id')
                        .having('COUNT(reviews.id) > 0')
                        .select('ads.id, AVG(reviews.rating) as avg_rating, COUNT(reviews.id) as review_count')
                        .order('AVG(reviews.rating) DESC, COUNT(reviews.id) DESC')
                        .limit(limit * 2)
    
    # Get ads with clicks (third most important)
    ads_with_clicks = Ad.active
                       .joins(:seller, :click_events)
                       .where(sellers: { blocked: false, deleted: false })
                       .where(flagged: false)
                       .group('ads.id')
                       .having('COUNT(click_events.id) > 0')
                       .select('ads.id, COUNT(click_events.id) as total_clicks')
                       .order('COUNT(click_events.id) DESC')
                       .limit(limit * 2)
    
    # Combine all ad IDs and get unique set
    all_ad_ids = (ads_with_sales.pluck(:id) + 
                  ads_with_reviews.pluck(:id) + 
                  ads_with_clicks.pluck(:id)).uniq
    
    return [] if all_ad_ids.empty?
    
    # Get full ad data for the selected ads
    ads_data = Ad.active
                 .joins(:seller, :category, :subcategory)
                 .joins("LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id")
                 .joins("LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id")
                 .where(id: all_ad_ids)
                 .where(sellers: { blocked: false, deleted: false })
                 .where(flagged: false)
                 .select("
                   ads.id,
                   ads.title,
                   ads.description,
                   ads.price,
                   ads.quantity,
                   ads.media,
                   ads.created_at,
                   ads.updated_at,
                   sellers.fullname as seller_name,
                   sellers.id as seller_id,
                   categories.name as category_name,
                   subcategories.name as subcategory_name,
                   COALESCE(tiers.id, 1) as seller_tier_id,
                   COALESCE(tiers.name, 'Free') as seller_tier_name
                 ")
    
    # Get metrics for these ads efficiently
    sales_metrics = Hash[ads_with_sales.map { |ad| [ad.id, ad.total_sold.to_i] }]
    review_metrics = Hash[ads_with_reviews.map { |ad| [ad.id, { avg_rating: ad.avg_rating.to_f, review_count: ad.review_count.to_i }] }]
    click_metrics = Hash[ads_with_clicks.map { |ad| [ad.id, ad.total_clicks.to_i] }]
    
    # Calculate scores and sort
    scored_ads = ads_data.map do |ad|
      sales_score = calculate_sales_score(sales_metrics[ad.id] || 0)
      review_data = review_metrics[ad.id] || { avg_rating: 0, review_count: 0 }
      review_score = calculate_review_score(review_data[:avg_rating], review_data[:review_count])
      click_score = calculate_click_score(click_metrics[ad.id] || 0)
      tier_bonus = calculate_tier_bonus(ad.seller_tier_id.to_i)
      recency_score = calculate_recency_score(ad.created_at)
      
      comprehensive_score = (sales_score * 0.50) + (review_score * 0.30) + (click_score * 0.15) + (tier_bonus * 0.03) + (recency_score * 0.02)
      
      {
        ad_id: ad.id,
        title: ad.title,
        description: ad.description,
        price: ad.price.to_f,
        quantity: ad.quantity,
        media: ad.media,
        created_at: ad.created_at,
        updated_at: ad.updated_at,
        seller_name: ad.seller_name,
        seller_id: ad.seller_id,
        category_name: ad.category_name,
        subcategory_name: ad.subcategory_name,
        seller_tier_id: ad.seller_tier_id,
        seller_tier_name: ad.seller_tier_name,
        metrics: {
          total_sold: sales_metrics[ad.id] || 0,
          avg_rating: review_data[:avg_rating].round(2),
          review_count: review_data[:review_count],
          total_clicks: click_metrics[ad.id] || 0
        },
        comprehensive_score: comprehensive_score.round(2)
      }
    end
    
    # Sort by comprehensive score and return top results
    scored_ads.sort_by { |ad| -ad[:comprehensive_score] }.first(limit)
  end

  def calculate_global_best_sellers_fast(limit)
    # Similar to calculate_best_sellers_fast but with different weighting
    # Focus more on sales volume and less on seller tier for global ranking
    
    # Get ads with sales data (most important for global)
    ads_with_sales = Ad.active
                      .joins(:seller, :order_items)
                      .where(sellers: { blocked: false, deleted: false })
                      .where(flagged: false)
                      .group('ads.id')
                      .having('SUM(order_items.quantity) > 0')
                      .select('ads.id, SUM(order_items.quantity) as total_sold')
                      .order('SUM(order_items.quantity) DESC')
                      .limit(limit * 3) # Get more for global ranking
    
    # Get ads with reviews
    ads_with_reviews = Ad.active
                        .joins(:seller, :reviews)
                        .where(sellers: { blocked: false, deleted: false })
                        .where(flagged: false)
                        .group('ads.id')
                        .having('COUNT(reviews.id) > 0')
                        .select('ads.id, AVG(reviews.rating) as avg_rating, COUNT(reviews.id) as review_count')
                        .order('AVG(reviews.rating) DESC, COUNT(reviews.id) DESC')
                        .limit(limit * 2)
    
    # Combine ad IDs
    all_ad_ids = (ads_with_sales.pluck(:id) + ads_with_reviews.pluck(:id)).uniq
    
    return [] if all_ad_ids.empty?
    
    # Get full ad data
    ads_data = Ad.active
                 .joins(:seller, :category, :subcategory)
                 .joins("LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id")
                 .joins("LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id")
                 .where(id: all_ad_ids)
                 .where(sellers: { blocked: false, deleted: false })
                 .where(flagged: false)
                 .select("
                   ads.id,
                   ads.title,
                   ads.description,
                   ads.price,
                   ads.quantity,
                   ads.media,
                   ads.created_at,
                   ads.updated_at,
                   sellers.fullname as seller_name,
                   sellers.id as seller_id,
                   categories.name as category_name,
                   subcategories.name as subcategory_name,
                   COALESCE(tiers.id, 1) as seller_tier_id,
                   COALESCE(tiers.name, 'Free') as seller_tier_name
                 ")
    
    # Get metrics
    sales_metrics = Hash[ads_with_sales.map { |ad| [ad.id, ad.total_sold.to_i] }]
    review_metrics = Hash[ads_with_reviews.map { |ad| [ad.id, { avg_rating: ad.avg_rating.to_f, review_count: ad.review_count.to_i }] }]
    
    # Calculate global scores (higher sales weight, lower tier bias)
    scored_ads = ads_data.map do |ad|
      sales_score = calculate_sales_score(sales_metrics[ad.id] || 0)
      review_data = review_metrics[ad.id] || { avg_rating: 0, review_count: 0 }
      review_score = calculate_review_score(review_data[:avg_rating], review_data[:review_count])
      tier_bonus = calculate_tier_bonus(ad.seller_tier_id.to_i) * 0.1 # Much lower tier bias
      recency_score = calculate_recency_score(ad.created_at) * 0.1 # Lower recency weight
      
      comprehensive_score = (sales_score * 0.70) + (review_score * 0.25) + (tier_bonus * 0.03) + (recency_score * 0.02)
      
      {
        ad_id: ad.id,
        title: ad.title,
        description: ad.description,
        price: ad.price.to_f,
        quantity: ad.quantity,
        media: ad.media,
        created_at: ad.created_at,
        updated_at: ad.updated_at,
        seller_name: ad.seller_name,
        seller_id: ad.seller_id,
        category_name: ad.category_name,
        subcategory_name: ad.subcategory_name,
        seller_tier_id: ad.seller_tier_id,
        seller_tier_name: ad.seller_tier_name,
        metrics: {
          total_sold: sales_metrics[ad.id] || 0,
          avg_rating: review_data[:avg_rating].round(2),
          review_count: review_data[:review_count]
        },
        comprehensive_score: comprehensive_score.round(2)
      }
    end
    
    # Sort by comprehensive score and return top results
    scored_ads.sort_by { |ad| -ad[:comprehensive_score] }.first(limit)
  end

  # Simplified scoring methods for faster computation
  def calculate_sales_score(total_sold)
    return 0 if total_sold <= 0
    Math.log10(total_sold + 1) * 15 # Faster calculation
  end

  def calculate_review_score(avg_rating, review_count)
    return 0 if review_count <= 0
    rating_score = (avg_rating / 5.0) * 40
    count_bonus = Math.log10(review_count + 1) * 8
    rating_score + count_bonus
  end

  def calculate_click_score(total_clicks)
    return 0 if total_clicks <= 0
    Math.log10(total_clicks + 1) * 12
  end

  def calculate_tier_bonus(seller_tier_id)
    case seller_tier_id
    when 4 then 15
    when 3 then 8
    when 2 then 4
    else 0
    end
  end

  def calculate_recency_score(created_at)
    days_old = (Time.current - created_at) / 1.day
    case days_old
    when 0..7 then 8
    when 8..30 then 5
    when 31..90 then 3
    when 91..365 then 1
    else 0
    end
  end

  def current_admin
    # Simple admin check - you can implement proper admin authentication here
    @current_admin ||= Admin.first if Rails.env.development?
  end
end