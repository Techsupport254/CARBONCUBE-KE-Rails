class AdminSerializer < ActiveModel::Serializer
  attributes :id, :fullname, :username, :email, :phone_number, :profile_picture, :location,
             :city, :zipcode, :county_id, :sub_county_id, :email_verified, :provider,
             :created_at, :updated_at
  # Exclude password_digest and other sensitive data
end
