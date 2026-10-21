# frozen_string_literal: true

# Follow-up for NEW sellers roughly 1 week after they register:
# asks them to send us their catalog if they have not uploaded any products/ads yet.
# Runs on a daily sidekiq-cron schedule and picks up sellers created 168–192h ago
# (7–8 days), ensuring every registration window is covered exactly once.
#
# Idempotent & Guarded:
#   - Strictly excludes sellers who already have products/ads listed (`seller.ads.where(deleted: [false, nil]).exists?`)
#   - Strictly excludes sellers who already received this reminder (matched by Notification title)
#   - Excludes deleted or blocked sellers
class SendCatalogUploadReminderToNewSellersJob < ApplicationJob
  queue_as :broadcast

  MIN_AGE_HOURS = 168 # 7 days
  MAX_AGE_HOURS = 192 # 8 days

  def perform(dry_run: false, min_age_hours: MIN_AGE_HOURS, max_age_hours: MAX_AGE_HOURS)
    title = SendCatalogUploadReminderJob::NOTIFICATION_TITLE

    sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
                    .where(created_at: max_age_hours.hours.ago..min_age_hours.hours.ago)

    stats = {
      eligible: 0,
      queued: 0,
      skipped_has_ads: 0,
      skipped_duplicate: 0,
      failed: 0
    }

    sellers.find_each do |seller|
      stats[:eligible] += 1

      # Skip if seller already has active/non-deleted products listed
      if seller.ads.exists?(deleted: [false, nil])
        stats[:skipped_has_ads] += 1
        next
      end

      # Skip if seller already received this reminder notification
      if Notification.exists?(recipient: seller, title: title)
        stats[:skipped_duplicate] += 1
        next
      end

      SendCatalogUploadReminderJob.perform_later(seller.id) unless dry_run
      stats[:queued] += 1
    rescue StandardError => e
      stats[:failed] += 1
      Rails.logger.error "[SendCatalogUploadReminderToNewSellersJob] Seller##{seller.id} failed: #{e.message}"
    end

    Rails.logger.info "[SendCatalogUploadReminderToNewSellersJob] dry_run=#{dry_run} " \
                      "window=#{max_age_hours}-#{min_age_hours}h ago " \
                      "eligible=#{stats[:eligible]} queued=#{stats[:queued]} " \
                      "skipped_has_ads=#{stats[:skipped_has_ads]} " \
                      "skipped_duplicate=#{stats[:skipped_duplicate]} failed=#{stats[:failed]}"
    stats.merge(dry_run: dry_run)
  end
end
