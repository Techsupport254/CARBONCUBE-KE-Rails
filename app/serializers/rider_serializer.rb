class RiderSerializer < ActiveModel::Serializer
  attributes :id, :full_name, :phone_number, :gender, :age_group_id, :email, :id_number, :blocked, :driving_license, :physical_address,:vehicle_type, :license_plate, :password, :kin_full_name, :kin_relationship, :kin_phone_number
end