# app/serializers/order_serializer.rb
class OrderSerializer < ActiveModel::Serializer
  attributes :id, :buyer_id, :status, :total_amount, :processing_fee, :delivery_fee, :mpesa_transaction_code, :created_at, :updated_at, :order_date
  belongs_to :buyer, serializer: BuyerSerializer
  has_many :order_items, serializer: OrderItemSerializer

  def order_date
    object.created_at.strftime('%Y-%m-%d')
  end
end
