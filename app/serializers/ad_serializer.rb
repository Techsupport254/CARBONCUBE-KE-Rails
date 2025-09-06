class AdSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :price, :quantity, :brand, :condition, :manufacturer,
             :item_weight, :weight_unit, :item_length, :item_width, :item_height,
             :created_at, :updated_at, :category_id, :subcategory_id, :category_name, :subcategory_name, :seller_name, 
             :seller_phone_number, :seller_tier_name, :seller_tier, :enterprise_name, :reviews_count, :average_rating, :media_urls, :first_media_url, :tier_priority

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
    object.reviews_count || 0
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
    object.media || [] # Safely return the array of URLs or empty array
  end

  def first_media_url
    object.media&.first # Safely return the first URL or nil
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
end
