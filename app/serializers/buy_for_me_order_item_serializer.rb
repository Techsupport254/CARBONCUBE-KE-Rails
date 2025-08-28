# app/serializers/buy_for_me_order_item_serializer.rb
class BuyForMeOrderItemSerializer < ActiveModel::Serializer
  attributes :id, :buy_for_me_order_id, :ad_id, :quantity, :ad_name, :price, :seller_name

  belongs_to :buy_for_me_order
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
