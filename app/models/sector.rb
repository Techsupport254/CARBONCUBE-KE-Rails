class Sector < ApplicationRecord
  has_many :buyers
  validates :name, presence: true, uniqueness: true
end
