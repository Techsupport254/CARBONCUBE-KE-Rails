class ConversationSerializer < ActiveModel::Serializer
  attributes :id, :admin_id, :buyer_id, :seller_id, :ad_id, :created_at, :updated_at

  belongs_to :admin
  belongs_to :buyer
  belongs_to :seller
  belongs_to :ad
  # has_many :messages
end
