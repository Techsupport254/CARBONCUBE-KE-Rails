class TierPricingSerializer < ActiveModel::Serializer
  attributes :id, :duration_months, :price
end
