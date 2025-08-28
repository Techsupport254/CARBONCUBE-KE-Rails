class County < ApplicationRecord
  has_many :sub_counties, dependent: :destroy
  has_many :sellers
  # validates :name, presence: true, uniqueness: true
end
