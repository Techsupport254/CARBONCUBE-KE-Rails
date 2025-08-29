class AdSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :price, :quantity, :brand, :condition, :manufacturer,
             :item_weight, :weight_unit, :item_length, :item_width, :item_height,
             :created_at, :updated_at, :category_id, :subcategory_id, :category_name, :subcategory_name, :seller_name, 
             :seller_phone_number, :seller_tier_name, :seller_tier, :enterprise_name, :reviews_count, :media_urls, :first_media_url

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
    object.seller&.seller_tier&.tier&.name || "N/A"
  end

  def reviews_count
    object.reviews_count || 0
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
    object.seller&.seller_tier&.tier_id
  end

  def enterprise_name
    object.seller&.enterprise_name
  end

  def include_reviews?
    instance_options[:include_reviews] == true
  end
end
