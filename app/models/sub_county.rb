class SubCounty < ApplicationRecord
  belongs_to :county
  has_many :sellers
  # validates :name, presence: true
end
