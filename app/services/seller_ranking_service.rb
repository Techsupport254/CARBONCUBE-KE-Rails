class SellerRankingService
  attr_reader :filters

  def initialize(filters: {})
    @filters = filters || {}
  end

  # Get ranked sellers with aggregated metrics (OPTIMIZED with bulk queries)
  def ranked_sellers(limit: 100)
    # Get all seller IDs that match filters
    seller_ids = base_seller_query.pluck(:id)
    return [] if seller_ids.empty?
    
    # Calculate all metrics in bulk using SQL aggregations
    metrics_by_seller = calculate_all_seller_metrics_bulk(seller_ids)
    
    # Get seller details with eager loading
    sellers_hash = base_seller_query
      .includes(:seller_tier, :tier)
      .where(id: seller_ids)
      .index_by(&:id)
    
    # Build results with composite scores
    sellers_with_metrics = seller_ids.map do |seller_id|
      seller = sellers_hash[seller_id]
      next nil unless seller && metrics_by_seller[seller_id]
      
      metrics = metrics_by_seller[seller_id]
      total_contact_interactions = metrics[:copy_clicks] + metrics[:call_clicks] + 
                                    metrics[:whatsapp_clicks] + metrics[:location_clicks]
      
      composite_score = (
        (metrics[:ad_clicks] * 0.25) +
        (metrics[:reveal_clicks] * 0.20) +
        (total_contact_interactions * 0.15) +
        (metrics[:wishlists_count] * 0.15) +
        (metrics[:reviews_count] * 0.15) +
        (metrics[:avg_rating] * 10 * 0.10)
      ).round(2)
      
      {
        seller: format_seller(seller),
        ad_clicks: metrics[:ad_clicks],
        reveal_clicks: metrics[:reveal_clicks],
        wishlist_clicks: metrics[:wishlist_clicks],
        cart_clicks: metrics[:cart_clicks],
        copy_clicks: metrics[:copy_clicks],
        call_clicks: metrics[:call_clicks],
        whatsapp_clicks: metrics[:whatsapp_clicks],
        location_clicks: metrics[:location_clicks],
        total_contact_interactions: total_contact_interactions,
        wishlists_count: metrics[:wishlists_count],
        reviews_count: metrics[:reviews_count],
        avg_rating: metrics[:avg_rating],
        ads_count: metrics[:ads_count],
        composite_score: composite_score,
        rank: 0 # Will be set after sorting
      }
    end.compact
    
    # Sort by composite score and limit
    sellers_with_metrics.sort_by { |s| -s[:composite_score] }.first(limit)
  end

  # Get rankings by specific metric (OPTIMIZED with bulk queries)
  def rankings_by_metric(metric_type, limit: 100)
    # Get all seller IDs that match filters
    seller_ids = base_seller_query.pluck(:id)
    return [] if seller_ids.empty?
    
    # Calculate all metrics in bulk
    metrics_by_seller = calculate_all_seller_metrics_bulk(seller_ids)
    
    # Get seller details with eager loading
    sellers_hash = base_seller_query
      .includes(:seller_tier, :tier)
      .where(id: seller_ids)
      .index_by(&:id)
    
    # Build results
    sellers_with_metrics = seller_ids.map do |seller_id|
      seller = sellers_hash[seller_id]
      next nil unless seller && metrics_by_seller[seller_id]
      
      metrics = metrics_by_seller[seller_id]
      total_contact_interactions = metrics[:copy_clicks] + metrics[:call_clicks] + 
                                    metrics[:whatsapp_clicks] + metrics[:location_clicks]
      
      composite_score = (
        (metrics[:ad_clicks] * 0.25) +
        (metrics[:reveal_clicks] * 0.20) +
        (total_contact_interactions * 0.15) +
        (metrics[:wishlists_count] * 0.15) +
        (metrics[:reviews_count] * 0.15) +
        (metrics[:avg_rating] * 10 * 0.10)
      ).round(2)
      
      metric_value = case metric_type.to_s
                     when 'ad_clicks' then metrics[:ad_clicks]
                     when 'reveal_clicks' then metrics[:reveal_clicks]
                     when 'copy_clicks' then metrics[:copy_clicks]
                     when 'call_clicks' then metrics[:call_clicks]
                     when 'whatsapp_clicks' then metrics[:whatsapp_clicks]
                     when 'location_clicks' then metrics[:location_clicks]
                     when 'total_contact_interactions' then total_contact_interactions
                     when 'wishlists_count' then metrics[:wishlists_count]
                     when 'reviews_count' then metrics[:reviews_count]
                     when 'avg_rating' then metrics[:avg_rating]
                     else 0
                     end
      
      {
        seller: format_seller(seller),
        value: metric_value,
        ad_clicks: metrics[:ad_clicks],
        reveal_clicks: metrics[:reveal_clicks],
        copy_clicks: metrics[:copy_clicks],
        call_clicks: metrics[:call_clicks],
        whatsapp_clicks: metrics[:whatsapp_clicks],
        location_clicks: metrics[:location_clicks],
        total_contact_interactions: total_contact_interactions,
        wishlists_count: metrics[:wishlists_count],
        reviews_count: metrics[:reviews_count],
        avg_rating: metrics[:avg_rating],
        ads_count: metrics[:ads_count],
        composite_score: composite_score,
        rank: 0 # Will be set after sorting
      }
    end.compact
    
    # Sort by the specified metric and limit
    sorted = sellers_with_metrics.sort_by { |s| -s[:value] }.first(limit)
    
    # Assign ranks
    sorted.each_with_index do |seller_data, index|
      seller_data[:rank] = index + 1
    end
    
    sorted
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

  # OPTIMIZED: Calculate metrics for all sellers in bulk using SQL aggregations
  def calculate_all_seller_metrics_bulk(seller_ids)
    return {} if seller_ids.empty?
    
    # Get all ad IDs grouped by seller_id
    ads_by_seller = Ad.where(seller_id: seller_ids, deleted: false)
                      .group(:seller_id)
                      .pluck(:seller_id, Arel.sql('ARRAY_AGG(id)'))
                      .to_h
    
    all_ad_ids = ads_by_seller.values.flatten
    return {} if all_ad_ids.empty?
    
    # Build base click events query (excluding internal users)
    # Note: We can't use excluding_seller_own_clicks with seller_id here since we're doing bulk
    # The scope would need seller_id per seller, so we'll exclude seller own clicks in the SQL
    base_click_events = ClickEvent
      .excluding_internal_users
      .where(ad_id: all_ad_ids)
      .joins(:ad)
      .where(ads: { deleted: false })
      .left_joins(:buyer)
      .where("buyers.id IS NULL OR buyers.deleted = ?", false)
    
    # Exclude seller own clicks using SQL
    # Exclude logged-in sellers clicking own ads
    base_click_events = base_click_events.where(
      "NOT (
        (metadata->>'user_role' = 'seller' OR metadata->>'user_role' = 'Seller')
        AND metadata->>'user_id' IS NOT NULL
        AND ads.seller_id IS NOT NULL
        AND CAST(metadata->>'user_id' AS TEXT) = CAST(ads.seller_id AS TEXT)
      )"
    )
    
    # Aggregate click events by seller_id and event_type
    click_metrics = base_click_events
      .group('ads.seller_id', 'click_events.event_type')
      .pluck(
        'ads.seller_id',
        'click_events.event_type',
        Arel.sql('COUNT(*)')
      )
      .group_by { |row| row[0] } # Group by seller_id
    
    # Aggregate contact interaction clicks by seller_id and action_type
    contact_interaction_events = base_click_events
      .where(event_type: 'Reveal-Seller-Details')
      .where("metadata->>'action' = ?", 'seller_contact_interaction')
      .group('ads.seller_id', Arel.sql("metadata->>'action_type'"))
      .pluck(
        'ads.seller_id',
        Arel.sql("metadata->>'action_type'"),
        Arel.sql('COUNT(*)')
      )
      .group_by { |row| row[0] } # Group by seller_id
    
    # Get wishlists count by seller
    wishlists_by_seller = WishList
      .where(ad_id: all_ad_ids)
      .joins(:ad)
      .group('ads.seller_id')
      .pluck('ads.seller_id', Arel.sql('COUNT(*)'))
      .to_h
    
    # Get reviews count and average rating by seller
    reviews_by_seller = Review
      .joins(:ad)
      .where(ads: { id: all_ad_ids, deleted: false, seller_id: seller_ids })
      .group('ads.seller_id')
      .pluck(
        'ads.seller_id',
        Arel.sql('COUNT(*)'),
        Arel.sql('COALESCE(AVG(rating), 0)')
      )
      .to_h { |row| [row[0], { count: row[1], avg: row[2].to_f.round(2) }] }
    
    # Build metrics hash for each seller
    metrics_by_seller = {}
    
    seller_ids.each do |seller_id|
      ad_ids = ads_by_seller[seller_id] || []
      seller_clicks = click_metrics[seller_id] || []
      seller_contacts = contact_interaction_events[seller_id] || []
      
      # Extract click counts by event type
      clicks_by_type = seller_clicks.to_h { |row| [row[1], row[2]] }
      
      # Extract contact interaction counts by action type
      contacts_by_type = seller_contacts.to_h { |row| [row[1], row[2]] }
      
      review_data = reviews_by_seller[seller_id] || { count: 0, avg: 0.0 }
      
      metrics_by_seller[seller_id] = {
        ad_clicks: clicks_by_type['Ad-Click'] || 0,
        reveal_clicks: clicks_by_type['Reveal-Seller-Details'] || 0,
        wishlist_clicks: clicks_by_type['Add-to-Wish-List'] || 0,
        cart_clicks: clicks_by_type['Add-to-Cart'] || 0,
        copy_clicks: (contacts_by_type['copy_phone'] || 0) + (contacts_by_type['copy_email'] || 0),
        call_clicks: contacts_by_type['call_phone'] || 0,
        whatsapp_clicks: contacts_by_type['whatsapp'] || 0,
        location_clicks: contacts_by_type['view_location'] || 0,
        wishlists_count: wishlists_by_seller[seller_id] || 0,
        reviews_count: review_data[:count],
        avg_rating: review_data[:avg],
        ads_count: ad_ids.count
      }
    end
    
    metrics_by_seller
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

