class ReviewPushNotificationJob < ApplicationJob
  queue_as :default

  def perform(review_id)
    review = Review.find_by(id: review_id)
    return unless review

    recipient = review.ad&.seller
    return unless recipient

    tokens = DeviceToken.where(user: recipient).pluck(:token)
    return unless tokens.any?

    payload = {
      title: "New Review on #{review.ad.title.truncate(30)}",
      body: "#{review.rating} stars: #{review.review.to_s.truncate(100)}",
      data: {
        type: 'review',
        review_id: review.id,
        ad_id: review.ad_id
      }
    }

    PushNotificationService.send_notification(tokens, payload)
  rescue => e
    Rails.logger.error "Failed to send review push notification: #{e.message}"
  end
end
