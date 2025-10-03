class Ad < ApplicationRecord
  include PgSearch::Model

  enum :condition, { brand_new: 0, second_hand: 1, refurbished: 2 }

  pg_search_scope :search_by_title_and_description, against: [:title, :description], using: { tsearch: { prefix: true }, trigram: {}}


  scope :active, -> { where(deleted: false) }
  scope :deleted, -> { where(deleted: true) }
  scope :with_valid_images, -> { where.not(media: [nil, [], ""]) }

  belongs_to :seller
  belongs_to :category
  belongs_to :subcategory
  
  has_many :reviews, dependent: :destroy
  has_many :cart_items, dependent: :destroy
  has_many :wish_lists, dependent: :destroy
  has_many :click_events
  has_many :conversations, dependent: :destroy

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
        availability: 'IN_STOCK',
        price: {
          amountMicros: (price * 1000000).to_i.to_s,
          currencyCode: 'KES'
        },
        condition: google_condition,
        brand: brand.present? ? brand : nil
      }.compact
    }
  end

  def product_url
    slug = create_slug(title)
    "https://carboncube-ke.com/ads/#{slug}?id=#{id}"
  end

  def google_condition
    case condition
    when 'brand_new' then 'NEW'
    when 'second_hand' then 'USED'
    when 'refurbished' then 'REFURBISHED'
    else 'NEW'
    end
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
    return false if title.blank?
    return false if description.blank?
    return false if price.blank? || price <= 0
    
    true
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
