class Review < ApplicationRecord
  belongs_to :ad, counter_cache: true
  belongs_to :buyer
  after_save :check_seller_rating

  # Note: images column is already JSON type in database, no need to serialize
  # The json column type handles serialization automatically

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :review, presence: true
  validates :images, length: { maximum: 5, message: "cannot have more than 5 images" }

  # Ensure only buyers can create reviews
  validate :buyer_can_review

  private

  def check_seller_rating
    ad.seller.check_and_block
  end

  def buyer_can_review
    unless buyer.is_a?(Buyer)
      errors.add(:buyer, "Only buyers can create reviews")
    end
  end
end
