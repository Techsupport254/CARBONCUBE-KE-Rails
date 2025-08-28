# app/serializers/order_item_serializer.rb
class OrderItemSerializer < ActiveModel::Serializer
  attributes :id, :order_id, :ad_id, :quantity, :ad_name, :price, :seller_name

  belongs_to :order
  belongs_to :ad, serializer: AdSerializer

  def ad_name
    object.ad&.title || 'Unknown Ad'
  end

  def price
    object.ad&.price || 0
  end

  def seller_name
    object.ad&.seller&.fullname || 'Unknown Seller'
  end
end
