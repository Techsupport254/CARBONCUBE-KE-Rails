# app/serializers/buy_for_me_order_serializer.rb
class BuyForMeOrderSerializer < ActiveModel::Serializer
  attributes :id, :buyer_id, :total_amount, :processing_fee, :delivery_fee, :mpesa_transaction_code, :created_at, :updated_at, :order_date
  belongs_to :buyer, serializer: BuyerSerializer
  has_many :buy_for_me_order_items, serializer: BuyForMeOrderItemSerializer

  def order_date
    object.created_at.strftime('%Y-%m-%d')
  end
end
