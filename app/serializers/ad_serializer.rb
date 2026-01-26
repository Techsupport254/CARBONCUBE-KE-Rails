class AdSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :price, :brand, :condition, :manufacturer,
             :item_weight, :weight_unit, :item_length, :item_width, :item_height,
             :created_at, :updated_at, :category_id, :subcategory_id, :category_name, :subcategory_name, :seller_id, :seller_name, 
             :seller_phone_number, :seller_tier_name, :seller_tier, :enterprise_name, :reviews_count, :average_rating, :media_urls, :first_media_url, :tier_priority,
             :seller_is_verified, :seller_document_verified, :is_added_by_sales,
             :flash_sale_info

  has_one :seller, serializer: SellerSerializer
  has_many :reviews, if: :include_reviews?

  def category_name
    object.category&.name || "N/A"
  end

  def subcategory_name
    object.subcategory&.name || "N/A"
  end

  def seller_name
    object.seller&.fullname || "N/A"
  end

  def seller_phone_number
    object.seller.phone_number || "N/A"
  end

  def seller_tier_name
    # Try to get tier name from associations first
    tier_name = object.seller&.seller_tier&.tier&.name
    return tier_name if tier_name.present?
    
    # Fallback: determine tier name from tier_id if available
    tier_id = object.seller&.seller_tier&.tier_id
    case tier_id
    when 4 then "Premium"
    when 3 then "Standard"
    when 2 then "Basic"
    when 1 then "Free"
    else "Free"
    end
  end

  def reviews_count
    if object.reviews.loaded?
      object.reviews.size
    else
      object.reviews.count
    end
  end

  def average_rating
    # Calculate average rating from reviews
    if object.reviews.loaded?
      # Use loaded reviews if available
      reviews = object.reviews
      reviews.any? ? (reviews.sum(&:rating).to_f / reviews.size).round(1) : 0.0
    else
      # Calculate from database
      object.reviews.average(:rating)&.round(1) || 0.0
    end
  end

  def media_urls
    object.valid_media_urls # Return only valid media URLs
  end

  def first_media_url
    object.first_valid_media_url # Return the first valid media URL
  end

  def category_id
    object.category_id
  end

  def subcategory_id
    object.subcategory_id
  end

  def seller_tier
    object.seller&.seller_tier&.tier_id || 1
  end

  def enterprise_name
    object.seller&.enterprise_name
  end

  def tier_priority
    # Try to get tier_id from associations first
    tier_id = object.seller&.seller_tier&.tier_id
    if tier_id
      case tier_id
      when 4 then 1  # Premium
      when 3 then 2  # Standard
      when 2 then 3  # Basic
      when 1 then 4  # Free
      else 5         # Unknown
      end
    else
      # Fallback: try to get from the database directly
      seller_tier = SellerTier.find_by(seller_id: object.seller_id)
      if seller_tier
        case seller_tier.tier_id
        when 4 then 1  # Premium
        when 3 then 2  # Standard
        when 2 then 3  # Basic
        when 1 then 4  # Free
        else 5         # Unknown
        end
      else
        4  # Default to Free
      end
    end
  end

  def include_reviews?
    instance_options[:include_reviews] == true
  end

  def flash_sale_info
    # Find active or scheduled offer that includes this ad (any offer type)
    # First try to use preloaded associations if available (more efficient)
    active_offer_ad = nil
    
    if object.association(:offer_ads).loaded?
      # Use preloaded associations
      active_offer_ad = object.offer_ads.find do |offer_ad|
        offer = offer_ad.association(:offer).loaded? ? offer_ad.offer : offer_ad.offer
        offer && 
        ['active', 'scheduled'].include?(offer.status) &&
        offer.end_time >= Time.current  # Only check end_time - allow scheduled offers before start
      end
      
      # If found via associations, ensure offer is loaded
      if active_offer_ad && !active_offer_ad.association(:offer).loaded?
        active_offer_ad = active_offer_ad.reload(include: :offer)
      end
    end
    
    # Fallback to database query if associations not loaded or not found
    unless active_offer_ad
      # Debug: Log all offer_ads for this ad to see what's available (only when enabled)
      if flash_sale_debug_logs_enabled?
        all_offer_ads = OfferAd.where(ad_id: object.id).includes(:offer)
        Rails.logger.debug "🔍 AdSerializer [Ad #{object.id}] - All OfferAds: #{all_offer_ads.map { |oa| { id: oa.id, offer_id: oa.offer_id, offer_status: oa.offer&.status, start_time: oa.offer&.start_time, end_time: oa.offer&.end_time } }.inspect}"
      end
      
      # Include both active and scheduled offers
      # Active offers: must have started (start_time <= now) and not ended (end_time >= now)
      # Scheduled offers: can be shown before they start (start_time > now) as long as they haven't ended (end_time >= now)
      active_offer_ad = OfferAd.joins(:offer)
                               .where(ad_id: object.id)
                               .where(offers: { 
                                 status: ['active', 'scheduled']
                               })
                               .where('offers.end_time >= ?', Time.current)  # Only check end_time - allow scheduled offers before start
                               .order('offers.start_time ASC')
                               .first
      
      if flash_sale_debug_logs_enabled?
        Rails.logger.debug "🔍 AdSerializer [Ad #{object.id}] - Found active_offer_ad: #{active_offer_ad ? { id: active_offer_ad.id, offer_id: active_offer_ad.offer_id, discount: active_offer_ad.discount_percentage } : 'nil'}"
      end
    end
    
    return nil unless active_offer_ad
    
    offer = active_offer_ad.offer
    
    {
      active: offer.status == 'active',
      scheduled: offer.status == 'scheduled',
      offer_id: offer.id,
      offer_name: offer.name,
      offer_type: offer.offer_type,
      discount_type: offer.discount_type,
      original_price: active_offer_ad.original_price,
      discounted_price: active_offer_ad.discounted_price,
      discount_percentage: active_offer_ad.discount_percentage,
      savings_amount: active_offer_ad.savings_amount,
      seller_notes: active_offer_ad.seller_notes,
      start_time: offer.start_time,
      end_time: offer.end_time,
      time_remaining: offer.time_remaining,
      badge_color: offer.badge_color,
      banner_color: offer.banner_color,
      # Bulk offer specific fields
      minimum_order_amount: offer.minimum_order_amount
    }
  end

  def seller_document_verified
    object.seller&.document_verified?
  end

  def seller_is_verified
    seller_document_verified
  end

  private

  def flash_sale_debug_logs_enabled?
    ENV.fetch('FLASH_SALE_DEBUG_LOGS', 'false') == 'true'
  end
end
