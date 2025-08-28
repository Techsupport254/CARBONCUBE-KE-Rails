class BuyForMeOrder < ApplicationRecord
  belongs_to :ad
  belongs_to :buyer

  validates :quantity, presence: true, numericality: { greater_than: 0 }
end
