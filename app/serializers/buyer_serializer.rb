# app/serializers/buyer_serializer.rb
class BuyerSerializer < ActiveModel::Serializer
  attributes :id, :fullname, :email, :phone_number, :location, :username, :city, 
             :zipcode, :profile_picture, :age_group_id, :gender, :blocked, 
             :income_id, :sector_id, :education_id, :employment_id, :provider,
             :created_at, :updated_at

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
