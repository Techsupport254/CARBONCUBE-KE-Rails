# frozen_string_literal: true

class SyncGoogleReviewsForSellerJob < ApplicationJob
  queue_as :low

  def perform(seller_id)
    connection = GoogleBusinessProfileConnection.find_by(seller_id: seller_id)
    return unless connection&.connected? && connection.google_location_id.present?

    GoogleBusinessProfileService.new(connection).sync_reviews!
  rescue GoogleBusinessProfileService::ApiError => e
    Rails.logger.warn("Google Business Profile review sync failed for seller #{seller_id}: #{e.message}")
  end
end
