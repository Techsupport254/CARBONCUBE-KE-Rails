class SellerSerializer < ActiveModel::Serializer
  attributes :id, :fullname, :phone_number, :email, :enterprise_name, :location, 
             :business_registration_number, :description, :username, :profile_picture, 
             :age_group_id, :zipcode, :city, :gender, :blocked, :tier, :county_id, :sub_county_id,
             :document_url, :document_type_id, :document_expiry_date, :document_verified, :ads_count, :provider,
             :created_at, :updated_at

  has_many :categories
  has_many :seller_documents, serializer: SellerDocumentSerializer

  def tier
    object.seller_tier&.tier
  end
end
