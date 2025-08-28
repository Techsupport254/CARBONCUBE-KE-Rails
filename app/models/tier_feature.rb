class TierFeature < ApplicationRecord
  belongs_to :tier

  validates :feature_name, presence: true, uniqueness: { scope: :tier_id, message: "Feature already exists for this tier" }
end
