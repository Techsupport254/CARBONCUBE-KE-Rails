class SellerPricingTemplate < ApplicationRecord
  self.primary_key = 'id'

  belongs_to :seller
  belongs_to :category, optional: true
  belongs_to :subcategory, optional: true

  validates :pricing_unit, presence: true
  validates :price_display_mode, presence: true, inclusion: { in: %w[public tiered request_quote] }
  validates :price_tiers, presence: true, if: -> { price_display_mode == 'tiered' }

  validate :price_tiers_shape, if: -> { price_tiers.present? }

  # Only one template per seller/category/subcategory scope.
  # nil category_id + nil subcategory_id = global default.
  validates :subcategory_id, uniqueness: { scope: [:seller_id, :category_id] }, allow_nil: true

  scope :for_seller, ->(seller) { where(seller: seller) }

  # Most specific match wins: subcategory -> category -> global.
  def self.resolve(seller, category_id: nil, subcategory_id: nil)
    return nil unless seller

    subcategory_match = for_seller(seller)
                          .where(category_id: category_id, subcategory_id: subcategory_id)
                          .first
    return subcategory_match if subcategory_match

    category_match = for_seller(seller)
                       .where(category_id: category_id, subcategory_id: nil)
                       .first
    return category_match if category_match

    for_seller(seller).where(category_id: nil, subcategory_id: nil).first
  end

  private

  def price_tiers_shape
    tiers = Array(price_tiers)
    return if tiers.empty?

    tiers.each_with_index do |tier, index|
      unless tier.is_a?(Hash)
        errors.add(:price_tiers, "tier #{index + 1} must be an object")
        next
      end

      min = tier['min_quantity']

      unless min.is_a?(Numeric) && min.to_i >= 0
        errors.add(:price_tiers, "tier #{index + 1} min_quantity must be a positive number")
      end

      if tier.key?('max_quantity') && tier['max_quantity'].present?
        max = tier['max_quantity']
        unless max.is_a?(Numeric) && max.to_i >= min.to_i
          errors.add(:price_tiers, "tier #{index + 1} max_quantity must be >= min_quantity")
        end
      end
    end
  end
end
