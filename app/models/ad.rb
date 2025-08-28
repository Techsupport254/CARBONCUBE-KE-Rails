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
  
  has_many :order_items
  has_many :orders, through: :order_items
  has_many :reviews, dependent: :destroy
  has_many :cart_items, dependent: :destroy
  has_many :wish_lists, dependent: :destroy
  has_many :buyers, through: :bookmarks
  has_many :buy_for_me_orders
  has_many :click_events
  has_many :conversations, dependent: :destroy

  accepts_nested_attributes_for :category
  accepts_nested_attributes_for :reviews

  validates :title, :description, :price, :quantity, :brand, :manufacturer, presence: true
  validates :price, numericality: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :item_length, :item_width, :item_height, numericality: true, allow_nil: true
  validates :item_weight, numericality: { greater_than: 0 }, allow_nil: true


  validates :weight_unit, inclusion: { in: ['Grams', 'Kilograms'] }

  # Ensure media can accept a string or array of strings
  serialize :media, coder: JSON

  # Soft delete
  def flag
    update(flagged: true)
  end

  # Restore flagged product
  def unflag
    update(flagged: false)
  end

  # Calculate the total quantity sold for the product
  def quantity_sold
    order_items.sum(:quantity)
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
      {
        count: reviews.size,
        average: reviews.any? ? reviews.sum(&:rating).to_f / reviews.size : 0.0
      }
    else
      {
        count: reviews_count || reviews.count,
        average: reviews.average(:rating).to_f
      }
    end
  end
  
  def media_urls
    media&.map { |url| url } || []
  end

  def first_media_url
    media&.first # Safely access the first URL in the media array
  end  
end
