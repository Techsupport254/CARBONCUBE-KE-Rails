class ReviewSerializer < ActiveModel::Serializer
    attributes :id, :rating, :review, :seller_reply, :images, :created_at, :updated_at
  
    belongs_to :ad
    belongs_to :buyer
end
  