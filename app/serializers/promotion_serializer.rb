class PromotionSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :discount_percentage, :coupon_code, :start_date, :end_date
end
