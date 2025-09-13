class Ad < ApplicationRecord
  include PgSearch::Model

  enum :condition, { brand_new: 0, second_hand: 1, refurbished: 2 }

  pg_search_scope :search_by_title_and_description, against: [:title, :description], using: { tsearch: { prefix: true }, trigram: {}}

  scope :all_products, -> { unscope(:where).all }

  scope :active, -> { where(deleted: false) }
  scope :deleted, -> { where(deleted: true) }

  belongs_to :seller
  belongs_to :category
  belongs_to :subcategory
  
  has_many :reviews, dependent: :destroy
  has_many :cart_items, dependent: :destroy
  has_many :wish_lists, dependent: :destroy
  has_many :buyers, through: :bookmarks
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

  # Efficient method to get review statistics
  def review_stats
    if reviews.loaded?
      total_reviews = reviews.size
      return { total: 0, average: 0.0 } if total_reviews == 0
      
      total_rating = reviews.sum(&:rating)
      average_rating = total_rating.to_f / total_reviews
      
      { total: total_reviews, average: average_rating }
    else
      total_reviews = reviews.count
      return { total: 0, average: 0.0 } if total_reviews == 0
      
      average_rating = reviews.average(:rating).to_f
      
      { total: total_reviews, average: average_rating }
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

  private

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
