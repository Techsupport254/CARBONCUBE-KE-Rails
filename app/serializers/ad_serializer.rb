class AdSerializer < ActiveModel::Serializer
    attributes  :id, :seller_id, :category_id, :subcategory_id, :category_name,
                :subcategory_name, :title, :description, :price, :quantity, :brand,
                :manufacturer, :item_weight, :weight_unit, :item_length, :item_width,
                :item_height, :media_urls, :first_media_url, :mean_rating, :review_count,
                :seller_tier, :tier_name, :condition, :seller_enterprise_name, :seller_phone_number,
                :seller_profile_picture, :seller_name

  has_one :seller, serializer: SellerSerializer
  has_many :reviews

  def media_urls
    object.media || [] # ✅ Safely return the array of URLs or empty array
  end

  def first_media_url
    object.media&.first # ✅ Safely return the first URL or nil
  end

  def seller_name
    object.seller.fullname
  end

  def seller_tier
    # Use cached associations if available
    if object.seller.association(:seller_tier).loaded?
      seller_tier = object.seller.seller_tier
      seller_tier ? seller_tier.tier_id : nil
    else
      seller_tier = object.seller.seller_tier
      seller_tier ? seller_tier.tier_id : nil
    end
  end

  def tier_name
    # Use cached associations if available
    if object.seller.association(:seller_tier).loaded? && 
       object.seller.seller_tier&.association(:tier).loaded?
      seller_tier = object.seller.seller_tier
      seller_tier&.tier&.name || 'Unknown'
    else
      seller_tier = object.seller.seller_tier
      seller_tier&.tier&.name || 'Unknown'
    end
  end

  def category_name
    # Use cached association if available
    if object.association(:category).loaded?
      object.category&.name
    else
      object.category&.name
    end
  end

  def subcategory_name
    # Use cached association if available
    if object.association(:subcategory).loaded?
      object.subcategory&.name
    else
      object.subcategory&.name
    end
  end

  def mean_rating
    # Use pre-calculated stats if available, otherwise calculate
    if object.respond_to?(:review_stats) && object.review_stats
      object.review_stats[:average]
    elsif object.reviews.loaded?
      reviews = object.reviews
      reviews.any? ? reviews.sum(&:rating).to_f / reviews.size : 0.0
    else
      object.reviews.average(:rating).to_f
    end
  end

  def review_count
    # Use pre-calculated stats if available, otherwise use counter cache
    if object.respond_to?(:review_stats) && object.review_stats
      object.review_stats[:count]
    else
      object.reviews_count || object.reviews.count
    end
  end

  # More efficient method that calculates both at once
  def review_stats
    if object.respond_to?(:review_stats) && object.review_stats
      object.review_stats
    else
      stats = object.review_stats
      {
        count: stats[:count],
        average: stats[:average]
      }
    end
  end

  def seller_enterprise_name
    object.seller.enterprise_name
  end

  def seller_profile_picture
    object.seller.profile_picture
  end

  def seller_phone_number
    object.seller.phone_number || "N/A"
  end
end
