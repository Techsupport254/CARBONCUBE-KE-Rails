class SellerRankingService
  attr_reader :filters

  def initialize(filters: {})
    @filters = filters || {}
  end

  # Get ranked sellers with aggregated metrics
  def ranked_sellers(limit: 100)
    sellers = base_seller_query
    
    # Calculate metrics for each seller
    sellers_with_metrics = sellers.map do |seller|
      calculate_seller_metrics(seller)
    end
    
    # Sort by composite score (descending)
    sellers_with_metrics.sort_by { |s| -s[:composite_score] }.first(limit)
  end

  # Get rankings by specific metric
  def rankings_by_metric(metric_type, limit: 100)
    sellers = base_seller_query
    
    sellers_with_metrics = sellers.map do |seller|
      metrics = calculate_seller_metrics(seller)
      metric_value = case metric_type.to_s
                     when 'ad_clicks' then metrics[:ad_clicks]
                     when 'reveal_clicks' then metrics[:reveal_clicks]
                     when 'wishlists_count' then metrics[:wishlists_count]
                     when 'reviews_count' then metrics[:reviews_count]
                     when 'avg_rating' then metrics[:avg_rating]
                     else 0
                     end
      
      {
        seller: format_seller(seller),
        value: metric_value,
        # Include all metrics for display
        ad_clicks: metrics[:ad_clicks],
        reveal_clicks: metrics[:reveal_clicks],
        wishlists_count: metrics[:wishlists_count],
        reviews_count: metrics[:reviews_count],
        avg_rating: metrics[:avg_rating],
        ads_count: metrics[:ads_count],
        composite_score: metrics[:composite_score],
        rank: 0 # Will be set after sorting
      }
    end
    
    # Sort by the specified metric
    sorted = sellers_with_metrics.sort_by { |s| -s[:value] }
    
    # Assign ranks
    sorted.each_with_index do |seller_data, index|
      seller_data[:rank] = index + 1
    end
    
    sorted.first(limit)
  end

  private

  def base_seller_query
    query = Seller.where(deleted: false, blocked: false)
    
    # Apply filters if any
    if filters[:tier_id].present?
      query = query.joins(:seller_tier).where(seller_tiers: { tier_id: filters[:tier_id] })
    end
    
    if filters[:category_id].present?
      query = query.joins(:categories).where(categories: { id: filters[:category_id] })
    end
    
    query
  end

  def calculate_seller_metrics(seller)
    ad_ids = seller.ads.where(deleted: false).pluck(:id)
    
    # Get click events for seller's ads (excluding internal users)
    click_events = ClickEvent
      .excluding_internal_users
      .where(ad_id: ad_ids)
      .joins(:ad)
      .where(ads: { deleted: false })
    
    # Calculate metrics
    ad_clicks = click_events.where(event_type: 'Ad-Click').count
    reveal_clicks = click_events.where(event_type: 'Reveal-Seller-Details').count
    wishlist_clicks = click_events.where(event_type: 'Add-to-Wish-List').count
    cart_clicks = click_events.where(event_type: 'Add-to-Cart').count
    
    # Get wishlists (actual wishlist records, not just click events)
    wishlists_count = WishList.where(ad_id: ad_ids).count
    
    # Get reviews
    reviews = seller.reviews.joins(:ad).where(ads: { id: ad_ids, deleted: false })
    reviews_count = reviews.count
    avg_rating = reviews.average(:rating).to_f.round(2)
    
    # Get ads count
    ads_count = ad_ids.count
    
    # Calculate composite score
    # Weighted scoring: clicks (30%), reveals (25%), wishlists (20%), reviews (15%), rating (10%)
    composite_score = (
      (ad_clicks * 0.30) +
      (reveal_clicks * 0.25) +
      (wishlists_count * 0.20) +
      (reviews_count * 0.15) +
      (avg_rating * 10 * 0.10) # Multiply rating by 10 to normalize (0-5 becomes 0-50)
    ).round(2)
    
    {
      seller: format_seller(seller),
      ad_clicks: ad_clicks,
      reveal_clicks: reveal_clicks,
      wishlist_clicks: wishlist_clicks,
      cart_clicks: cart_clicks,
      wishlists_count: wishlists_count,
      reviews_count: reviews_count,
      avg_rating: avg_rating,
      ads_count: ads_count,
      composite_score: composite_score,
      rank: 0 # Will be set after sorting
    }
  end

  def format_seller(seller)
    {
      id: seller.id,
      fullname: seller.fullname,
      enterprise_name: seller.enterprise_name,
      email: seller.email,
      phone_number: seller.phone_number,
      location: seller.location,
      profile_picture: seller.profile_picture,
      tier: seller.tier&.name || 'Free',
      created_at: seller.created_at&.iso8601
    }
  end
end

