class OfferAd < ApplicationRecord
  belongs_to :offer
  belongs_to :ad
  
  # Validations
  validates :discount_percentage, presence: true, 
            numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :original_price, presence: true, 
            numericality: { greater_than: 0 }
  validates :discounted_price, presence: true, 
            numericality: { greater_than: 0 }
  validates :ad_id, uniqueness: { scope: :offer_id, 
            message: "is already part of this offer" }
  
  # Custom validations
  validate :discounted_price_less_than_original
  validate :discount_matches_prices
  
  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :by_offer, ->(offer_id) { where(offer_id: offer_id) }
  scope :by_discount_range, ->(min, max) { where(discount_percentage: min..max) }
  
  # Callbacks
  before_validation :calculate_discounted_price, if: -> { original_price.present? && discount_percentage.present? }
  before_validation :calculate_discount_percentage, if: -> { original_price.present? && discounted_price.present? && discount_percentage.blank? }
  
  # Methods
  def savings_amount
    original_price - discounted_price
  end
  
  def is_discounted?
    discounted_price < original_price
  end
  
  def discount_valid?
    discount_percentage > 0 && discount_percentage <= 100
  end
  
  private
  
  def calculate_discounted_price
    return unless original_price.present? && discount_percentage.present?
    self.discounted_price = original_price * (1 - discount_percentage / 100)
  end
  
  def calculate_discount_percentage
    return unless original_price.present? && discounted_price.present?
    self.discount_percentage = ((original_price - discounted_price) / original_price) * 100
  end
  
  def discounted_price_less_than_original
    return unless original_price.present? && discounted_price.present?
    if discounted_price >= original_price
      errors.add(:discounted_price, "must be less than original price")
    end
  end
  
  def discount_matches_prices
    return unless original_price.present? && discounted_price.present? && discount_percentage.present?
    
    expected_discounted = original_price * (1 - discount_percentage / 100)
    if (discounted_price - expected_discounted).abs > 0.01 # Allow for small rounding differences
      errors.add(:discounted_price, "does not match the discount percentage")
    end
  end
end
