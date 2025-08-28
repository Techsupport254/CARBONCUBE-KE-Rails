class SellerOrderItemSerializer < ActiveModel::Serializer
  attributes :id, :quantity, :ad_title, :price

  def ad_title
    object.ad&.title || 'Unknown Ad'
  end

  def price
    object.ad&.price || 0
  end
end
