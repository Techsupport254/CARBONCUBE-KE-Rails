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
    # Ultra-simplified approach to minimize database connections
    # Get recent active ads with basic info only
    ads_data = Ad.active.with_valid_images
                 .joins(:seller, :category, :subcategory)
                 .joins("LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id")
                 .joins("LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id")
                 .where(sellers: { blocked: false, deleted: false })
                 .where(flagged: false)
                 .select("
                   ads.id,
                   ads.title,
                   ads.description,
                   ads.price,
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
                 .order('ads.created_at DESC')
                 .limit(limit * 3) # Get more than needed for basic scoring
    
    return [] if ads_data.empty?
    
    # Simple scoring based on recency and tier only (no additional DB queries)
    scored_ads = ads_data.map do |ad|
      tier_bonus = calculate_tier_bonus(ad.seller_tier_id.to_i)
      recency_score = calculate_recency_score(ad.created_at)
      
      # Simple score: mostly recency with small tier bonus
      simple_score = (recency_score * 0.8) + (tier_bonus * 0.2)
      
      {
        ad_id: ad.id,
        title: ad.title,
        description: ad.description,
        price: ad.price.to_f,
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
          avg_rating: 0.0,
          review_count: 0,
          total_clicks: 0
        },
        comprehensive_score: simple_score.round(2)
      }
    end
    
    # Sort by simple score and return top results
    scored_ads.sort_by { |ad| -ad[:comprehensive_score] }.first(limit)
  end

  def calculate_global_best_sellers_fast(limit)
    # Use the same simplified approach as calculate_best_sellers_fast
    calculate_best_sellers_fast(limit)
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