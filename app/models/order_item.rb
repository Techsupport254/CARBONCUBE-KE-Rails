class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :ad

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_save :calculate_total_price

  private

  def calculate_total_price
    self.price = ad.price
    self.total_price = price * quantity
  end
end
  