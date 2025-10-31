# app/serializers/buyer_serializer.rb
class BuyerSerializer < ActiveModel::Serializer
  attributes :id, :fullname, :email, :phone_number, :location, :username, :city, 
             :zipcode, :profile_picture, :age_group_id, :gender, :blocked, 
             :income_id, :sector_id, :education_id, :employment_id, :provider,
             :created_at, :updated_at
end
