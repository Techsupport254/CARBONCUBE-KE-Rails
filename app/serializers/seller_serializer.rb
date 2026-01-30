class SellerSerializer < ActiveModel::Serializer
  attributes :id, :fullname, :phone_number, :secondary_phone_number, :email, :enterprise_name, :location,
             :business_registration_number, :description, :username, :profile_picture,
             :age_group_id, :zipcode, :city, :gender, :blocked, :flagged, :tier, :county_id, :sub_county_id,
             :document_url, :document_type_id, :document_expiry_date, :document_verified, :ads_count, :provider,
             :carbon_code, :created_at, :updated_at

  has_many :categories
  has_many :seller_documents, serializer: SellerDocumentSerializer

  def tier
    object.seller_tier&.tier
  end

  def carbon_code
    return nil unless object.carbon_code_id?
    cc = object.carbon_code
    return nil unless cc
    { id: cc.id, code: cc.code, label: cc.label }
  end

  # Avoid using cached profile pictures - always return nil for cached URLs
  def profile_picture
    url = object.profile_picture
    return nil if url.blank?
    
    # If it's a cached profile picture URL, don't use it (return nil to avoid 404 errors)
    return nil if url.start_with?('/cached_profile_pictures/')
    
    # Return original Google URL or other valid URLs (but not cached ones)
    url
  end
end
