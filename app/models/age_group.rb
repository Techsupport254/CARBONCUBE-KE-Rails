class AgeGroup < ApplicationRecord
  has_many :buyers
  has_many :sellers

  validates :name, presence: true, uniqueness: true
end
