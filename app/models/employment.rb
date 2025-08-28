class Employment < ApplicationRecord
  has_many :buyers
  validates :status, presence: true, uniqueness: true
end
