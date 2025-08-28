class Tier < ApplicationRecord
  has_many :tier_features, dependent: :destroy
  has_many :tier_pricings, dependent: :destroy
  has_many :seller_tiers
  has_many :sellers, through: :seller_tiers

  validates :name, presence: true, uniqueness: true
  validates :ads_limit, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  accepts_nested_attributes_for :tier_pricings, allow_destroy: true
  accepts_nested_attributes_for :tier_features, allow_destroy: true
end