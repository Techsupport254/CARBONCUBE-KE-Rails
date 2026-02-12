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

  after_create :send_push_notification

  private

  def send_push_notification
    begin
      recipient = ad.seller
      return unless recipient

      # Retrieve tokens for the recipient
      tokens = DeviceToken.where(user: recipient).pluck(:token)

      if tokens.any?
        payload = {
          title: "New Review on #{ad.title.truncate(30)}",
          body: "#{rating} stars: #{review.truncate(100)}",
          data: {
            type: 'review',
            review_id: id,
            ad_id: ad_id
          }
        }
        
        PushNotificationService.send_notification(tokens, payload)
      end
    rescue => e
      Rails.logger.error "Failed to send review push notification: #{e.message}"
    end
  end

  def check_seller_rating
    ad.seller.check_and_block
  end

  def buyer_can_review
    unless buyer.is_a?(Buyer)
      errors.add(:buyer, "Only buyers can create reviews")
    end
  end
end
