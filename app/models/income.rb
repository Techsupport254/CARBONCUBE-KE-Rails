class Income < ApplicationRecord

  has_many :buyers
  validates :range, presence: true, uniqueness: true
end
