# frozen_string_literal: true

class SyncGoogleReviewsForSellerJob < ApplicationJob
  queue_as :low

  def perform(seller_id)
    seller = Seller.find_by(id: seller_id)
    return if seller.blank?

    GooglePlaceReviewService.new(seller).sync!
  end
end
