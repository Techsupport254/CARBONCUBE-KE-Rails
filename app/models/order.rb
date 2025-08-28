class Order < ApplicationRecord
  belongs_to :buyer
  has_many :order_items, dependent: :destroy
  has_many :order_sellers, dependent: :destroy
  has_many :ads, through: :order_items
  has_many :sellers, through: :order_sellers

  before_save :calculate_total_amount

  accepts_nested_attributes_for :order_items, allow_destroy: true
  accepts_nested_attributes_for :order_sellers, allow_destroy: true

  validates :status, inclusion: { in: %w[Processing Dispatched In-Transit Delivered Cancelled Returned] }
  validates :mpesa_transaction_code, presence: true

  private

  def order_date
    created_at.strftime('%Y-%m-%d')
  end

  def total_price
    order_items.sum do |item|
      item.ad ? item.quantity * item.ad.price : 0
    end
  end

  def calculate_total_amount
    self.total_amount = total_price + processing_fee.to_f + delivery_fee.to_f
  end
end
