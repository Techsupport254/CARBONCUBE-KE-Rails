class Review < ApplicationRecord
  belongs_to :ad, counter_cache: true
  belongs_to :buyer, optional: true
  belongs_to :seller, optional: true
  after_save :check_seller_rating

  # Note: images column is already JSON type in database, no need to serialize
  # The json column type handles serialization automatically

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :review, presence: true
  validates :images, length: { maximum: 5, message: "cannot have more than 5 images" }

  # Ensure either a buyer or a seller is present
  validate :reviewer_presence

  after_create :send_push_notification
  after_create :send_review_email
  after_update :send_reply_email, if: :saved_change_to_seller_reply?

  private

  def send_review_email
    begin
      # If the review has a seller author, the ad belongs to another seller? 
      # Usually a buyer reviews a seller.
      # Only notify if the author is a buyer (not a seller reviewing themselves/others)
      return unless buyer_id.present? 

      ReviewMailer.with(review: self).review_posted_notification.deliver_later
    rescue => e
      Rails.logger.error "Failed to send review email: #{e.message}"
    end
  end

  def send_reply_email
    begin
      # Only notify if the seller_reply was added and the author is a buyer
      return unless seller_reply.present? && buyer_id.present?
      
      ReviewMailer.with(review: self).reply_posted_notification.deliver_later
    rescue => e
      Rails.logger.error "Failed to send reply email: #{e.message}"
    end
  end

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

  def reviewer_presence
    if buyer_id.blank? && seller_id.blank?
      errors.add(:base, "Review must have a buyer or a seller as an author")
    end
  end
end
