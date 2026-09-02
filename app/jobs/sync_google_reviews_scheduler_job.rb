# frozen_string_literal: true

class SyncGoogleReviewsSchedulerJob < ApplicationJob
  queue_as :low

  # Business Profile API connections are owner-authorized and do not use the
  # Maps/Places API. Space requests to stay well within GBP API quotas.
  SPACING = 10.minutes

  def perform
    connections = GoogleBusinessProfileConnection
      .where(status: 'connected')
      .where.not(google_account_id: nil)
      .where.not(google_location_id: nil)
      .where('last_synced_at IS NULL OR last_synced_at < ?', 30.days.ago)
      .limit(500)

    connections.find_each.with_index do |connection, index|
      SyncGoogleReviewsForSellerJob.set(wait: SPACING * index).perform_later(connection.seller_id)
    end
  end
end
