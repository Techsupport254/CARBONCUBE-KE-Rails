# app/serializers/seller_analytics_serializer.rb

class SellerAnalyticsSerializer < ActiveModel::Serializer
  attributes :total_orders, :total_revenue, :average_rating

  def total_orders
    object[:total_orders]
  end

  def total_revenue
    object[:total_revenue]
  end

  def average_rating
    object[:average_rating]
  end
end
