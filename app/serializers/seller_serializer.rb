class SellerSerializer < ActiveModel::Serializer
  attributes :id, :fullname, :phone_number, :email, :enterprise_name, :location, 
             :business_registration_number, :description, :username, :profile_picture, 
             :age_group_id, :zipcode, :city, :gender, :blocked, :tier

  has_many :categories

  def tier
    object.seller_tier&.tier
  end
end
