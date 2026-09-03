# app/models/cart_item.rb

class CartItem < ApplicationRecord
  belongs_to :buyer
  belongs_to :ad

  after_create_commit :refresh_ad_stats

  validates :quantity, numericality: { greater_than_or_equal_to: 1 }
  before_save :set_price

  def total_price
    price * quantity
  end

  private

  def set_price
    self.price = ad.price
  end

  def refresh_ad_stats
    AdStat.schedule_refresh_if_stale
  end
end
