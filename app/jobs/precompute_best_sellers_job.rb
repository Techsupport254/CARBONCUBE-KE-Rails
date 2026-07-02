# Triggered every 30 minutes by sidekiq-cron (config/schedule.yml)
class PrecomputeBestSellersJob < ApplicationJob
  queue_as :low  # Non-urgent precomputation — runs from cron, never blocks real-time queues

  retry_on StandardError, wait: :polynomially_longer, attempts: 2
  discard_on ActiveJob::DeserializationError

  def perform
    Rails.logger.info "Starting best sellers precomputation..."
    
    # Precompute common limits
    [10, 20, 50].each do |limit|
      # Best sellers
      cache_key = "best_sellers_v2_#{limit}"
      best_sellers = calculate_best_sellers_fast(limit)
      Rails.cache.write(cache_key, best_sellers, expires_in: 30.minutes)
      
      # Global best sellers
      global_cache_key = "global_best_sellers_v2_#{limit}"
      global_best_sellers = calculate_global_best_sellers_fast(limit)
      Rails.cache.write(global_cache_key, global_best_sellers, expires_in: 1.hour)
      
      # Also populate the dynamic cache key for the next 15-30 minutes to warm the cache for the buyer homepage
      rotation_key = Time.current.to_i / 900
      dynamic_cache_key = "best_sellers_dynamic_#{limit}_#{rotation_key}"
      Rails.cache.write(dynamic_cache_key, best_sellers, expires_in: 15.minutes)
      
      Rails.logger.info "Precomputed best sellers for limit #{limit}: #{best_sellers.count} items"
    end
    
    Rails.logger.info "Best sellers precomputation completed"
  end

  private

  def calculate_best_sellers_fast(limit)
    # Enhanced approach with meaningful metrics without order_items
    # Get ads with comprehensive data including wishlist, ratings, and clicks
    ads_data = Ad.active.with_valid_images
                 .joins(:seller, :category, :subcategory)
                 .joins("LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id")
                 .joins("LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id")
                 .joins("LEFT JOIN wish_lists ON ads.id = wish_lists.ad_id")
                 .joins("LEFT JOIN reviews ON ads.id = reviews.ad_id")
                 .joins("LEFT JOIN click_events ON ads.id = click_events.ad_id")
                 .where(sellers: { blocked: false, deleted: false, flagged: false })
                 .where(flagged: false)
                 .select("
                   ads.id,
                   ads.title,
                   ads.description,
                   ads.price,
                   ads.media,
                   ads.created_at,
                   ads.updated_at,
                   ads.category_id,
                   ads.subcategory_id,
                   sellers.fullname as seller_name,
                   sellers.id as seller_id,
                   categories.name as category_name,
                   subcategories.name as subcategory_name,
                   COALESCE(tiers.id, 1) as seller_tier_id,
                   COALESCE(tiers.name, 'Free') as seller_tier_name,
                   COUNT(DISTINCT wish_lists.id) as wishlist_count,
                   COUNT(DISTINCT reviews.id) as review_count,
                   COALESCE(AVG(reviews.rating), 0) as avg_rating,
                   COUNT(DISTINCT click_events.id) as click_count
                 ")
                 .group("ads.id, sellers.id, categories.id, subcategories.id, tiers.id")
                 .order('RANDOM()')
                 .limit(limit * 5) # Get more for better scoring
    
    return [] if ads_data.empty?
    
    # Enhanced scoring with meaningful metrics
    scored_ads = ads_data.map do |ad|
      # Base scores
      tier_bonus = calculate_tier_bonus(ad.seller_tier_id.to_i)
      recency_score = calculate_recency_score(ad.created_at)
      
      # Engagement metrics
      wishlist_score = calculate_wishlist_score(ad.wishlist_count.to_i)
      rating_score = calculate_rating_score(ad.avg_rating.to_f, ad.review_count.to_i)
      click_score = calculate_click_score(ad.click_count.to_i)
      
      # Weighted comprehensive score
      comprehensive_score = (
        (recency_score * 0.25) +      # 25% - Recency
        (tier_bonus * 0.15) +         # 15% - Seller tier
        (wishlist_score * 0.25) +     # 25% - Wishlist additions
        (rating_score * 0.20) +       # 20% - Ratings & reviews
        (click_score * 0.15)          # 15% - Click engagement
      )
      
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
          avg_rating: ad.avg_rating.to_f.round(2),
          review_count: ad.review_count.to_i,
          total_clicks: ad.click_count.to_i,
          wishlist_count: ad.wishlist_count.to_i
        },
        comprehensive_score: comprehensive_score.round(2)
      }
    end
    
    # Sort by comprehensive score and return top results
    scored_ads.sort_by { |ad| -ad[:comprehensive_score] }.first(limit)
  end

  def calculate_global_best_sellers_fast(limit)
    # Use the same simplified approach as calculate_best_sellers_fast
    calculate_best_sellers_fast(limit)
  end

  # Simplified scoring methods for faster computation
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

  def calculate_wishlist_score(wishlist_count)
    return 0 if wishlist_count <= 0
    Math.log10(wishlist_count + 1) * 20
  end

  def calculate_rating_score(avg_rating, review_count)
    return 0 if review_count <= 0 || avg_rating <= 0
    rating_score = (avg_rating / 5.0) * 30
    count_bonus = Math.log10(review_count + 1) * 10
    rating_score + count_bonus
  end

  def calculate_click_score(click_count)
    return 0 if click_count <= 0
    Math.log10(click_count + 1) * 15
  end
end
