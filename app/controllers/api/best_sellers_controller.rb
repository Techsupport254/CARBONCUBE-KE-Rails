class Api::BestSellersController < ApplicationController
  # GET /api/best_sellers
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

  # GET /api/best_sellers/global
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

  # GET /api/best_sellers/refresh - Admin endpoint to refresh cache
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
    # Get active ads with essential data
    ads_data = Ad.active
                 .joins(:category, :subcategory, :seller)
                 .joins("LEFT JOIN seller_tiers ON ads.seller_id = seller_tiers.seller_id")
                 .joins("LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id")
                 .select("
                   ads.id, ads.title, ads.description, ads.price, ads.media, 
                   ads.created_at, ads.updated_at, ads.seller_id,
                   categories.name as category_name,
                   subcategories.name as subcategory_name,
                   sellers.fullname as seller_name,
                   seller_tiers.tier_id as seller_tier_id,
                   tiers.name as seller_tier_name
                 ")
                 .limit(limit * 3) # Get more than needed for better scoring
                 .order('ads.created_at DESC')

    return [] if ads_data.empty?

    # Get review metrics in one query
    review_metrics = Review.joins(:ad)
                          .where(ad_id: ads_data.map(&:id))
                          .group('reviews.ad_id')
                          .group('ads.id')
                          .average(:rating)
                          .transform_values { |avg_rating| 
                            { avg_rating: avg_rating || 0, review_count: 0 }
                          }

    # Get review counts
    review_counts = Review.joins(:ad)
                         .where(ad_id: ads_data.map(&:id))
                         .group('reviews.ad_id')
                         .count

    # Merge review counts into metrics
    review_metrics.each do |ad_id, data|
      data[:review_count] = review_counts[ad_id] || 0
    end

    # Get click metrics in one query
    click_metrics = ClickEvent.joins(:ad)
                             .where(ad_id: ads_data.map(&:id))
                             .group('click_events.ad_id')
                             .count

    # Calculate global scores (higher review weight, lower tier bias)
    scored_ads = ads_data.map do |ad|
      review_data = review_metrics[ad.id] || { avg_rating: 0, review_count: 0 }
      review_score = calculate_review_score(review_data[:avg_rating], review_data[:review_count])
      click_score = calculate_click_score(click_metrics[ad.id] || 0)
      tier_bonus = calculate_tier_bonus(ad.seller_tier_id.to_i) * 0.1 # Much lower tier bias
      recency_score = calculate_recency_score(ad.created_at) * 0.1 # Lower recency weight
      
      comprehensive_score = (review_score * 0.60) + (click_score * 0.30) + (tier_bonus * 0.08) + (recency_score * 0.02)
      
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
    # Similar to calculate_best_sellers_fast but with different scoring weights
    ads_data = Ad.active
                 .joins(:category, :subcategory, :seller)
                 .joins("LEFT JOIN seller_tiers ON ads.seller_id = seller_tiers.seller_id")
                 .joins("LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id")
                 .select("
                   ads.id, ads.title, ads.description, ads.price, ads.media, 
                   ads.created_at, ads.updated_at, ads.seller_id,
                   categories.name as category_name,
                   subcategories.name as subcategory_name,
                   sellers.fullname as seller_name,
                   seller_tiers.tier_id as seller_tier_id,
                   tiers.name as seller_tier_name
                 ")
                 .limit(limit * 5) # Get more for global scoring
                 .order('ads.created_at DESC')

    return [] if ads_data.empty?

    # Get review metrics
    review_metrics = Review.joins(:ad)
                          .where(ad_id: ads_data.map(&:id))
                          .group('reviews.ad_id')
                          .group('ads.id')
                          .average(:rating)
                          .transform_values { |avg_rating| 
                            { avg_rating: avg_rating || 0, review_count: 0 }
                          }

    review_counts = Review.joins(:ad)
                         .where(ad_id: ads_data.map(&:id))
                         .group('reviews.ad_id')
                         .count

    review_metrics.each do |ad_id, data|
      data[:review_count] = review_counts[ad_id] || 0
    end

    # Get click metrics
    click_metrics = ClickEvent.joins(:ad)
                             .where(ad_id: ads_data.map(&:id))
                             .group('click_events.ad_id')
                             .count

    # Calculate global scores (even more review-focused, minimal tier bias)
    scored_ads = ads_data.map do |ad|
      review_data = review_metrics[ad.id] || { avg_rating: 0, review_count: 0 }
      review_score = calculate_review_score(review_data[:avg_rating], review_data[:review_count])
      click_score = calculate_click_score(click_metrics[ad.id] || 0)
      tier_bonus = calculate_tier_bonus(ad.seller_tier_id.to_i) * 0.05 # Even lower tier bias
      recency_score = calculate_recency_score(ad.created_at) * 0.05 # Lower recency weight
      
      comprehensive_score = (review_score * 0.70) + (click_score * 0.25) + (tier_bonus * 0.03) + (recency_score * 0.02)
      
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

  def calculate_tier_bonus(tier_id)
    case tier_id
    when 1 then 50  # Diamond
    when 2 then 30  # Gold
    when 3 then 15  # Silver
    when 4 then 5   # Bronze
    else 0
    end
  end

  def calculate_recency_score(created_at)
    days_old = (Time.current - created_at) / 1.day
    return 50 if days_old <= 7
    return 30 if days_old <= 30
    return 15 if days_old <= 90
    return 5 if days_old <= 365
    0
  end
end
