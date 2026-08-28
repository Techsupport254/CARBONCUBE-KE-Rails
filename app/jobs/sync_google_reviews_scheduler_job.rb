# frozen_string_literal: true

class SyncGoogleReviewsSchedulerJob < ApplicationJob
  queue_as :low

  # Space each seller 10 minutes apart so we never burst more than ~6 calls/hour.
  # With the 1,000 free monthly requests cap, this stays free for up to 1,000 sellers/month.
  SPACING = 10.minutes

  def perform
    # Process up to 500 sellers per month to stay inside the free 1,000
    # Google Places API requests cap. Resolving a missing place_id makes
    # 2 requests (textsearch + details); refreshing reviews for an existing
    # place_id makes 1 request. New sellers are prioritised until they are
    # all resolved, then refresh older reviews.
    resolve_candidates = Seller
      .where(google_place_id: [nil, ""])
      .where.not(enterprise_name: [nil, ""])
      .limit(500)
      .to_a

    refresh_candidates = Seller
      .where.not(google_place_id: [nil, ""])
      .where("google_reviews_fetched_at IS NULL OR google_reviews_fetched_at < ?", 30.days.ago)
      .where.not(enterprise_name: [nil, ""])
      .to_a

    sellers_to_process = (resolve_candidates + refresh_candidates).take(500)

    sellers_to_process.each_with_index do |seller, index|
      SyncGoogleReviewsForSellerJob.perform_in(SPACING * index, seller.id)
    end
  end
end
