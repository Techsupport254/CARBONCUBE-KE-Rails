
class TierSerializer < ActiveModel::Serializer
  attributes :id, :name, :ads_limit
  has_many :tier_features
  has_many :tier_pricings
end
