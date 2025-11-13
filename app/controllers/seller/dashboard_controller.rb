class Seller::DashboardController < ApplicationController
  before_action :authenticate_seller

  def index
    begin
      seller = current_seller
      tier_id = seller.seller_tier&.tier_id || 1

      # Calculate base stats
      base_stats = calculate_base_stats_optimized(seller)

      # Build consolidated dashboard response
      response_data = {
        # Shop header data
        shop: {
          enterprise_name: seller.enterprise_name,
          description: seller.description,
          profile_picture: get_profile_picture(seller),
          flagged: seller.flagged || false,
          seller_tier_name: get_tier_name(tier_id)
        },
        
        # Quick stats
        stats: {
          tier_id: tier_id,
          total_ads: base_stats[:total_ads],
          total_reviews: base_stats[:total_reviews],
          average_rating: base_stats[:average_rating],
          total_wishlisted: base_stats[:total_ads_wishlisted]
        },

        # Tier countdown data
        tier_countdown: get_tier_countdown(seller.id, tier_id),

        # Review request status
        review_request: {
          has_pending_request: check_pending_review_request(seller.id)
        }
      }

      # Add tier-specific analytics (only what's used on dashboard)
      if tier_id >= 2
        device_hash = params[:device_hash] || request.headers['X-Device-Hash']
        click_events_service = ClickEventsAnalyticsService.new(
          filters: { seller_id: seller.id },
          device_hash: device_hash
        )

        # Get timestamps for charts (all time, no limits)
        timestamps = click_events_service.timestamps(limit: nil, date_limit: nil)
        
        # Get add-to-wishlist click event timestamps
        add_to_wishlist_timestamps = click_events_service.base_query
                                                          .where(event_type: 'Add-to-Wish-List')
                                                          .order('click_events.created_at DESC')
                                                          .pluck(Arel.sql("click_events.created_at"))
                                                          .map { |ts| ts&.iso8601 }

        response_data[:analytics] = {
          basic_click_event_stats: {
            click_event_trends: click_events_service.click_event_trends(months: nil)
          },
          ad_clicks_timestamps: timestamps[:ad_clicks_timestamps],
          reveal_events_timestamps: timestamps[:reveal_events_timestamps],
          add_to_wishlist_timestamps: add_to_wishlist_timestamps
        }

        # Add wishlist stats for tier 2+
        if tier_id >= 2
          response_data[:analytics][:basic_wishlist_stats] = {
            wishlist_trends: get_wishlist_trends(seller.id)
          }
        end

        # Add wishlist timestamps for tier 4
        if tier_id >= 4
          wishlist_timestamps = WishList.joins(:ad)
                                       .where(ads: { seller_id: seller.id, deleted: false })
                                       .order('wish_lists.created_at DESC')
                                       .pluck(:created_at)
                                       .map { |ts| ts&.iso8601 }
          response_data[:analytics][:wishlist_timestamps] = wishlist_timestamps
        end

        # Add top performing ads for tier 4
        if tier_id >= 4
          response_data[:analytics][:top_performing_ads] = get_top_performing_ads(seller.id)
        end
      end

      render json: response_data
    rescue => e
      Rails.logger.error "Dashboard error for seller #{current_seller&.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'Internal server error', details: e.message }, status: 500
    end
  end

  private

  def calculate_base_stats_optimized(seller)
    # Single query to get all base stats
    ads_scope = seller.ads.where(deleted: false)
    
    {
      total_ads: ads_scope.count,
      total_reviews: Review.joins(:ad).where(ads: { seller_id: seller.id }).count,
      average_rating: calculate_average_rating(seller),
      total_ads_wishlisted: WishList.joins(:ad)
                                   .where(ads: { seller_id: seller.id, deleted: false })
                                   .distinct
                                   .count('ads.id')
    }
  end

  def calculate_average_rating(seller)
    # Calculate average rating per ad, then average those
    ad_ratings = Review.joins(:ad)
                      .where(ads: { seller_id: seller.id })
                      .group('ads.id')
                      .select('AVG(reviews.rating) as avg_rating')
                      .pluck('AVG(reviews.rating)')
                      .compact
                      .map(&:to_f)
    
    ad_ratings.any? ? (ad_ratings.sum / ad_ratings.size).round(1) : 0.0
  end

  def get_profile_picture(seller)
    url = seller.profile_picture
    return nil if url.blank?
    # Don't use cached profile pictures
    return nil if url.start_with?('/cached_profile_pictures/')
    url
  end

  def get_tier_name(tier_id)
    case tier_id
    when 1 then "Free"
    when 2 then "Basic"
    when 3 then "Standard"
    when 4 then "Premium"
    else "Free"
    end
  end

  def get_tier_countdown(seller_id, tier_id)
    return nil if tier_id == 1 # Free tier has no expiry
    
    seller_tier = SellerTier.find_by(seller_id: seller_id)
    return nil unless seller_tier

    # Calculate expiry date: use expires_at if set, otherwise calculate from updated_at + duration_months
    end_date = seller_tier.expires_at || (seller_tier.updated_at + seller_tier.duration_months.months)
    return nil unless end_date

    now = Time.current
    
    if end_date <= now
      return {
        expired: true,
        never_expires: false
      }
    end

    # Calculate time remaining
    diff = end_date - now
    months = (diff / 1.month).floor
    weeks = ((diff % 1.month) / 1.week).floor
    days = ((diff % 1.week) / 1.day).floor
    hours = ((diff % 1.day) / 1.hour).floor
    minutes = ((diff % 1.hour) / 1.minute).floor
    seconds = ((diff % 1.minute) / 1.second).floor

    {
      expired: false,
      never_expires: false,
      months: months,
      weeks: weeks,
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      subscription_expiry_date: end_date.iso8601
    }
  end

  def check_pending_review_request(seller_id)
    ReviewRequest.where(seller_id: seller_id, status: 'pending').exists?
  end

  def get_wishlist_trends(seller_id)
    # Get monthly wishlist trends (all time)
    WishList.joins(:ad)
            .where(ads: { seller_id: seller_id, deleted: false })
            .group(Arel.sql("DATE_TRUNC('month', wish_lists.created_at)"))
            .order(Arel.sql("DATE_TRUNC('month', wish_lists.created_at) ASC"))
            .pluck(
              Arel.sql("DATE_TRUNC('month', wish_lists.created_at) as month"),
              Arel.sql("COUNT(DISTINCT wish_lists.id) as count")
            )
            .map do |month, count|
              {
                month: month.strftime('%Y-%m'),
                wishlist_count: count.to_i
              }
            end
  end

  def get_top_performing_ads(seller_id, limit = 10)
    # Get top performing ads based on comprehensive score
    # Use the same approach as Seller::AnalyticsController to avoid JOIN issues
    seller_ads = Ad.where(seller_id: seller_id, deleted: false)
            .joins("LEFT JOIN reviews ON reviews.ad_id = ads.id")
            .joins("LEFT JOIN click_events ON click_events.ad_id = ads.id")
            .joins("LEFT JOIN wish_lists ON wish_lists.ad_id = ads.id")
            .select("
              ads.id,
              ads.title,
              ads.price,
              ads.media,
              ads.created_at,
              COALESCE(AVG(reviews.rating), 0) as avg_rating,
              COALESCE(COUNT(DISTINCT reviews.id), 0) as review_count,
              COALESCE(SUM(CASE WHEN click_events.event_type = 'Ad-Click' THEN 1 ELSE 0 END), 0) as ad_clicks,
              COALESCE(SUM(CASE WHEN click_events.event_type IN ('Reveal-Seller-Details', 'Reveal-Vendor-Details') THEN 1 ELSE 0 END), 0) as reveal_clicks,
              COALESCE(SUM(CASE WHEN click_events.event_type = 'Add-to-Wish-List' THEN 1 ELSE 0 END), 0) as wishlist_clicks,
              COALESCE(COUNT(DISTINCT wish_lists.id), 0) as wishlist_count
            ")
            .group("ads.id")
            .having("AVG(reviews.rating) > 0 OR SUM(CASE WHEN click_events.event_type = 'Ad-Click' THEN 1 ELSE 0 END) > 0 OR COUNT(DISTINCT wish_lists.id) > 0")
            .limit(50) # Limit before scoring to reduce processing

    # Get ad IDs for contact interactions query
    ad_ids = seller_ads.map(&:id)
    
    # Pre-load contact interactions
    device_hash = request.headers['X-Device-Hash']
    contact_interactions_map = preload_contact_interactions(ad_ids, seller_id, device_hash)

    # Calculate comprehensive score for each ad
    scored_ads = seller_ads.map do |ad|
      # Calculate comprehensive score
      rating_score = (ad.avg_rating.to_f * 20) # 0-100
      review_score = [ad.review_count.to_i * 5, 50].min # Max 50 points
      click_score = [ad.ad_clicks.to_i * 2, 100].min # Max 100 points
      reveal_score = [ad.reveal_clicks.to_i * 3, 75].min # Max 75 points
      wishlist_score = [ad.wishlist_count.to_i * 4, 60].min # Max 60 points
      
      comprehensive_score = rating_score + review_score + click_score + reveal_score + wishlist_score

      # Parse media
      media_urls = []
      if ad.media.present?
        begin
          media_data = JSON.parse(ad.media)
          media_urls = media_data.is_a?(Array) ? media_data : [media_data]
        rescue
          media_urls = []
        end
      end

      {
        ad_id: ad.id,
        ad_title: ad.title,
        ad_price: ad.price.to_f,
        media: media_urls,
        comprehensive_score: comprehensive_score.round(2),
        metrics: {
          avg_rating: ad.avg_rating.to_f.round(1),
          review_count: ad.review_count.to_i,
          ad_clicks: ad.ad_clicks.to_i,
          reveal_clicks: ad.reveal_clicks.to_i,
          wishlist_clicks: ad.wishlist_clicks.to_i,
          wishlist_count: ad.wishlist_count.to_i,
          total_contact_interactions: contact_interactions_map[ad.id] || 0
        }
      }
    end

    # Sort by comprehensive score and return top N
    scored_ads.sort_by { |ad| -ad[:comprehensive_score] }.first(limit)
  end

  def preload_contact_interactions(ad_ids, seller_id, device_hash)
    return {} if ad_ids.empty?
    
    # Get contact interactions for all ads in a single query
    contact_events = ClickEvent
      .where(ad_id: ad_ids, event_type: 'Reveal-Seller-Details')
      .where("metadata->>'action' = ?", 'seller_contact_interaction')
      .joins(:ad)
      .where(ads: { seller_id: seller_id, deleted: false })
      .group(:ad_id)
      .count
    
    contact_events
  end

  def authenticate_seller
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_seller && @current_seller.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_seller
    @current_seller
  end
end

