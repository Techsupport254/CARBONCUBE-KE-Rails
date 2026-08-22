# frozen_string_literal: true

class SyncGoogleReviewsSchedulerJob < ApplicationJob
  queue_as :low

  # Space each seller 10 minutes apart so we never burst more than ~6 calls/hour.
  # With the 1,000 free monthly requests cap, this stays free for up to 1,000 sellers/month.
  SPACING = 10.minutes

  def perform
    # Only refresh sellers that already have a Google place_id.
    # Resolving new place_ids is not done automatically here because it burns
    # requests on sellers without a business profile and can quickly exceed the
    # free 1,000 requests/month cap.
    Seller
      .where.not(google_place_id: [nil, ""])
      .where("google_reviews_fetched_at IS NULL OR google_reviews_fetched_at < ?", 30.days.ago)
      .where.not(enterprise_name: [nil, ""])
      .find_each.with_index do |seller, index|
        SyncGoogleReviewsForSellerJob.perform_in(SPACING * index, seller.id)
      end
  end
end
