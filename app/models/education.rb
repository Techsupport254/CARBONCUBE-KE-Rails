class Education < ApplicationRecord
  has_many :buyers
  validates :level, presence: true, uniqueness: true
end
