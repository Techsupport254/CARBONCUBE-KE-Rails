class Review < ApplicationRecord
  belongs_to :ad, counter_cache: true
  belongs_to :buyer
  after_save :check_seller_rating


  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :review, presence: true

  private

  def check_seller_rating
    ad.seller.check_and_block
  end
end
