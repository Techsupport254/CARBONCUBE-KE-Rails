class Ad < ApplicationRecord
  include PgSearch::Model

  enum :condition, { brand_new: 0, second_hand: 1, refurbished: 2, x_japan: 3, ex_uk: 4 }

  # tsearch only: trigram (%) requires pg_trgm and can raise "operator does not exist: unknown % text"
  pg_search_scope :search_by_title_and_description, against: [:title, :description], using: { tsearch: { prefix: true } }


  scope :active, -> { where(deleted: false) }
  scope :deleted, -> { where(deleted: true) }
  scope :with_valid_images, -> { where.not(media: [nil, [], ""]) }
  scope :from_active_sellers, -> { joins(:seller).where(sellers: { blocked: false, deleted: false, flagged: false }) }

  belongs_to :seller
  belongs_to :category
  belongs_to :subcategory
  
  has_many :reviews, dependent: :destroy
  has_many :cart_items, dependent: :destroy
  has_many :wish_lists, dependent: :destroy
  has_many :click_events, dependent: :destroy
  has_many :offer_ads, dependent: :destroy
  has_many :offers, through: :offer_ads
  has_many :conversations, dependent: :destroy

  delegate :name, to: :category, prefix: true, allow_nil: true
  delegate :name, to: :subcategory, prefix: true, allow_nil: true

  accepts_nested_attributes_for :category
  accepts_nested_attributes_for :reviews

  validates :title, :description, :price, :brand, :manufacturer, presence: true
  validates :price, numericality: true
  validates :item_length, :item_width, :item_height, numericality: true, allow_nil: true
  validates :item_weight, numericality: { greater_than: 0 }, allow_nil: true


  validates :weight_unit, inclusion: { in: ['Grams', 'Kilograms'] }

  # Ensure media can accept a string or array of strings
  serialize :media, coder: JSON

  # Callbacks for cache invalidation
  after_save :invalidate_caches
  after_destroy :invalidate_caches
  
  # Google Merchant API sync callbacks
  after_save :schedule_google_merchant_sync, if: :should_sync_to_google_merchant?
  after_destroy :schedule_google_merchant_delete

  # Soft delete
  def flag
    update(flagged: true)
  end

  # Restore flagged product
  def unflag
    update(flagged: false)
  end

  # Soft delete ad (for stores to delete their own ads)
  def soft_delete
    update(deleted: true)
  end

  # Restore deleted ad
  def restore
    update(deleted: false)
  end

  # Calculate the average rating for the product
  def mean_rating
    # Use cached reviews if available, otherwise calculate
    if reviews.loaded?
      reviews.any? ? reviews.sum(&:rating).to_f / reviews.size : 0.0
    else
      reviews.average(:rating).to_f
    end
  end

  
  def media_urls
    media&.map { |url| url } || []
  end

  def first_media_url
    media&.first # Safely access the first URL in the media array
  end

  # Utility: generate a URL-friendly slug from a title
  def self.slugify(value)
    return "" if value.blank?

    value.to_s
         .downcase
         .strip
         .gsub(/[^\w\s-]/, "")    # remove special characters except spaces/hyphens
         .gsub(/\s+/, " ")        # normalize multiple spaces
         .strip
         .gsub(/\s+/, "-")        # spaces to hyphen
         .gsub(/-+/, "-")         # collapse multiple hyphens
         .gsub(/^-+|-+$/, "")     # trim leading/trailing hyphens
  end

  # Find an ad by numeric ID or by slugified title
  def self.find_by_id_or_slug(param)
    return nil if param.blank?

    # Try direct ID lookup first
    ad = where(id: param).first
    return ad if ad

    normalized_slug = slugify(param)
    return nil if normalized_slug.blank?

    # Also consider a space-separated version for titles stored with spaces
    spacey = normalized_slug.tr("-", " ")

    sanitized_sql = "LOWER(BTRIM(REGEXP_REPLACE(REGEXP_REPLACE(title, '[^a-z0-9]+', '-', 'g'), '-+', '-', 'g'), '-'))"

    # Match against multiple representations of the title
    where(
      "#{sanitized_sql} = :slug OR LOWER(title) = :spacey OR LOWER(REPLACE(title, '-', ' ')) = :spacey",
      slug: normalized_slug,
      spacey: spacey
    ).first
  end

  # Analytics methods for seller dashboard
  def total_sold
    # For now, return 0 as we don't have a sales tracking system yet
    # This could be calculated from completed orders/payments in the future
    0
  end

  def avg_rating
    mean_rating
  end

  def review_count
    # Try to use the cached database column first, otherwise count reviews
    if has_attribute?(:reviews_count) && reviews_count.present?
      reviews_count
    else
      reviews.size
    end
  end

  def ad_clicks
    click_events.where(event_type: 'Ad-Click').count
  end

  def reveal_clicks
    click_events.where(event_type: 'Reveal-Seller-Details').count
  end

  def wishlist_clicks
    click_events.where(event_type: 'Add-to-Wish-List').count
  end

  def cart_clicks
    click_events.where(event_type: 'Add-to-Cart').count
  end

  def wishlist_count
    wish_lists.count
  end

  # Check if ad has valid images
  def has_valid_images?
    return false if media.blank?
    
    # Check if media is an array and not empty
    return false unless media.is_a?(Array) && media.any?
    
    # Check if all media URLs are valid (not nil, not empty, and properly formatted)
    media.all? do |url|
      url.present? && 
      url.is_a?(String) && 
      url.strip.length > 0 &&
      (url.start_with?('http://') || url.start_with?('https://'))
    end
  end

  # Get only valid media URLs
  def valid_media_urls
    return [] unless has_valid_images?
    
    media.select do |url|
      url.present? && 
      url.is_a?(String) && 
      url.strip.length > 0 &&
      (url.start_with?('http://') || url.start_with?('https://'))
    end
  end

  # Get first valid media URL
  def first_valid_media_url
    valid_media_urls.first
  end

  # Google Merchant API integration methods
  def google_merchant_data
    {
      offerId: id.to_s,
      contentLanguage: 'en',
      feedLabel: 'primary',
      productAttributes: {
        title: title,
        description: description,
        link: product_url,
        imageLink: first_valid_media_url,
        availability: availability_status,
        price: {
          amountMicros: (price * 1000000).to_i.to_s,
          currencyCode: 'KES'
        },
        condition: google_condition,
        brand: brand.present? ? brand : nil,
        # Additional recommended fields
        category: category&.name,
        subcategory: subcategory&.name,
        manufacturer: manufacturer.present? ? manufacturer : nil,
        # Weight and dimensions if available
        weight: item_weight.present? ? "#{item_weight} #{weight_unit.downcase}" : nil,
        dimensions: dimensions_string
      }.compact
    }
  end

  def product_url
    slug = create_slug(title)
    "https://carboncube-ke.com/ads/#{slug}?id=#{id}"
  end

  # Ad URL with UTM params for links sent to users (WhatsApp, email, etc.).
  # Use this when the backend generates an ad link; frontend contact flows use their own UTM via shareUtils.
  # @param source [String] e.g. 'whatsapp', 'email'
  # @param medium [String] e.g. 'contact', 'notification'
  # @param campaign [String] e.g. 'ad_inquiry', 'message'
  def product_url_with_utm(source: 'whatsapp', medium: 'contact', campaign: 'ad_inquiry')
    UtmUrlHelper.append_utm(
      product_url,
      source: source,
      medium: medium,
      campaign: campaign,
      content: id.to_s,
      term: title
    )
  end

  # Returns the current price, taking into account active discounts/flash sales
  def effective_price
    # First check for active offer_ads through the association
    # This matches the logic in AdSerializer but simplified for model use
    active_offer = offer_ads.joins(:offer)
                            .where(offers: { status: 'active' })
                            .where('offers.start_time <= ? AND offers.end_time >= ?', Time.current, Time.current)
                            .first
    
    active_offer&.discounted_price || price
  end

  # Returns true if the product currently has an active discount
  def on_sale?
    offer_ads.joins(:offer)
             .where(offers: { status: 'active' })
             .where('offers.start_time <= ? AND offers.end_time >= ?', Time.current, Time.current)
             .exists?
  end

  def google_condition
    case condition
    when 'brand_new' then 'NEW'
    when 'second_hand' then 'USED'
    when 'refurbished' then 'REFURBISHED'
    when 'x_japan' then 'NEW' # X-Japan treated as new condition for Google Merchant
    when 'ex_uk' then 'USED' # EX-UK treated as used condition for Google Merchant
    else 'NEW'
    end
  end

  def availability_status
    # For now, assume all active ads are in stock
    # This could be enhanced with actual inventory tracking
    'IN_STOCK'
  end

  def dimensions_string
    return nil unless item_length.present? && item_width.present? && item_height.present?
    "#{item_length} x #{item_width} x #{item_height} cm"
  end

  def sync_to_google_merchant
    GoogleMerchantService.sync_ad(self)
  end

  def valid_for_google_merchant?
    return false if deleted?
    return false if flagged?
    return false unless seller
    return false if seller.blocked?
    return false if seller.deleted?
    return false unless has_valid_images?
    return false if title.blank? || title.length < 10
    return false if description.blank? || description.length < 20
    return false if price.blank? || price <= 0
    return false if price > 1000000
    return false if brand.blank?
    return false if category.blank?
    return false if condition.blank?
    
    true
  end
  
  def google_merchant_validation_errors
    errors = []
    
    if deleted?
      errors << "Ad is deleted"
    end
    
    if flagged?
      errors << "Ad is flagged"
    end
    
    unless seller
      errors << "No seller associated"
    else
      if seller.blocked?
        errors << "Seller is blocked"
      end
      if seller.deleted?
        errors << "Seller is deleted"
      end
    end
    
    unless has_valid_images?
      errors << "Valid product images are required"
    end
    
    if title.blank?
      errors << "Title is required"
    elsif title.length < 10
      errors << "Title too short (minimum 10 characters)"
    elsif title.length > 150
      errors << "Title too long (maximum 150 characters)"
    end
    
    if description.blank?
      errors << "Description is required"
    elsif description.length < 20
      errors << "Description too short (minimum 20 characters)"
    elsif description.length > 5000
      errors << "Description too long (maximum 5000 characters)"
    end
    
    if price.blank?
      errors << "Price is required"
    elsif price <= 0
      errors << "Price must be greater than 0"
    elsif price > 1000000
      errors << "Price too high (maximum 1,000,000 KES)"
    end
    
    if brand.blank?
      errors << "Brand is required"
    end
    
    if category.blank?
      errors << "Category is required"
    end
    
    if condition.blank?
      errors << "Product condition is required"
    end
    
    errors
  end

  private

  def create_slug(title)
    return "product-#{Time.current.to_i}" if title.blank?
    
    title.downcase
         .gsub(/[^a-z0-9\s]/, '')
         .gsub(/\s+/, '-')
         .strip
  end

  def schedule_google_merchant_sync
    # Schedule sync job with a small delay to avoid overwhelming the API
    GoogleMerchantSyncJob.set(wait: 5.seconds).perform_later(id, 'sync')
  end

  def schedule_google_merchant_delete
    # Schedule delete job immediately
    GoogleMerchantSyncJob.perform_later(id, 'delete')
  end

  def should_sync_to_google_merchant?
    # Only sync if the ad is valid and relevant fields have changed
    return false unless valid_for_google_merchant?
    
    # Check if any relevant fields have changed
    saved_change_to_title? || 
    saved_change_to_description? || 
    saved_change_to_price? || 
    saved_change_to_media? ||
    saved_change_to_condition? ||
    saved_change_to_brand? ||
    saved_change_to_deleted? ||
    saved_change_to_flagged?
  end

  def invalidate_caches
    # Invalidate related caches when ad is updated or deleted
    Rails.cache.delete_matched("buyer_ads_*")
    Rails.cache.delete_matched("search_*")
    Rails.cache.delete_matched("balanced_ads_*")
    Rails.cache.delete_matched("related_ads_*")
    
    # Invalidate category and subcategory caches
          Rails.cache.delete('buyer_categories_with_ads_count')
      Rails.cache.delete('buyer_category_analytics')
    Rails.cache.delete('buyer_subcategories_all')
  end
end
