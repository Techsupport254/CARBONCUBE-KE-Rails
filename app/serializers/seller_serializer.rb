class SellerSerializer < ActiveModel::Serializer
  attributes :id, :fullname, :slug, :phone_number, :secondary_phone_number, :email, :enterprise_name, :location,
             :business_registration_number, :description, :username, :profile_picture,
             :age_group_id, :zipcode, :city, :gender, :blocked, :flagged, :tier, :county_id, :sub_county_id,
             :document_url, :document_type_id, :document_expiry_date, :document_verified, :ads_count, :provider,
             :carbon_code, :created_at, :updated_at, :partner_status, :partner_type,
             :facebook_url, :instagram_url, :whatsapp_url, :tiktok_url, :twitter_url, :linkedin_url, :website, :google_business_profile_url
  attribute :google_place_reviews, if: :include_google_place_reviews?
  attribute :google_reviews_fetched_at, if: :include_google_place_reviews?

  has_many :categories
  has_many :seller_documents, serializer: SellerDocumentSerializer

  # Canonical slug — stored slug, or the UUID fallback so clients building
  # /shop/<slug> links never emit a null segment.
  def slug
    object.url_slug
  end

  def tier
    object.seller_tier&.tier
  end

  # "Verified Partner" badge — storefront belongs to an active partner.
  # Frontend shows the badge when this equals 'active'.
  def partner_status
    object.partner&.status
  end

  def partner_type
    object.partner&.partner_type
  end

  def include_google_place_reviews?
    return false unless object.class.column_names.include?("google_place_reviews")

    object.respond_to?(:verified_google_business_profile?) && object.verified_google_business_profile?
  end

  def google_place_reviews
    object.verified_google_reviews
  end

  def carbon_code
    return nil unless object.respond_to?(:carbon_code_id) && object.carbon_code_id.present?
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
