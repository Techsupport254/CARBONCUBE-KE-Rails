class Rider < ApplicationRecord
  has_secure_password

  belongs_to :county
  belongs_to :sub_county

  # Validations
  validates :full_name, :phone_number, :email, :id_number, :gender, :driving_license, :physical_address, :vehicle_type, :license_plate, :kin_full_name, :kin_relationship, :kin_phone_number, presence: true
  validates :phone_number, uniqueness: true
  validates :kin_phone_number, uniqueness: true
  validates :email, uniqueness: true
  validates :id_number, uniqueness: true
  validates :driving_license, uniqueness: true
  validates :license_plate, uniqueness: true
end
