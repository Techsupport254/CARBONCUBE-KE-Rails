class TierPricing < ApplicationRecord
  belongs_to :tier

  validates :duration_months, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
