# frozen_string_literal: true

# Fans out the catalog upload reminder across all 4 channels to all active sellers
# who have NOT uploaded ads in the last 7 days.
#
# Even if a seller previously received a reminder, if no ads have been uploaded in the
# last 7 days, they are reminded again.
#
# Strictly excludes: any seller whose ads were uploaded in the last 7 days,
# and avoids sending duplicates within the same 4-hour window.
#
# Usage:
#   SendCatalogUploadReminderBroadcastJob.perform_later(dry_run: true)   # counts only
#   SendCatalogUploadReminderBroadcastJob.perform_later(dry_run: false)  # live execution
class SendCatalogUploadReminderBroadcastJob < ApplicationJob
  queue_as :broadcast

  EXCLUSION_WINDOW = 7.days

  def perform(dry_run: true)
    title = SendCatalogUploadReminderJob::NOTIFICATION_TITLE

    # Eligible: active sellers excluding those whose ads were uploaded in the last 7 days
    active_sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
    sellers_with_recent_ads_ids = Ad.where("created_at >= ?", EXCLUSION_WINDOW.ago).select(:seller_id).distinct

    eligible_sellers = active_sellers.where.not(id: sellers_with_recent_ads_ids)

    stats = {
      total_eligible: eligible_sellers.count,
      queued: 0,
      skipped_recent_ads: 0,
      skipped_recent_notification: 0,
      failed: 0
    }

    eligible_sellers.find_each(batch_size: 50) do |seller|
      # Strictly exclude anyone whose ads were uploaded in the last 7 days
      if seller.ads.where("created_at >= ?", EXCLUSION_WINDOW.ago).exists?
        stats[:skipped_recent_ads] += 1
        next
      end

      # Skip if already notified within the last 4 hours (e.g. at 12:00 noon today)
      if Notification.where(recipient: seller, title: title).where("created_at >= ?", 4.hours.ago).exists?
        stats[:skipped_recent_notification] += 1
        next
      end

      SendCatalogUploadReminderJob.perform_later(seller.id) unless dry_run
      stats[:queued] += 1
      sleep(0.02) # Gentle pacing on Redis and Sidekiq
    rescue StandardError => e
      stats[:failed] += 1
      Rails.logger.error "[SendCatalogUploadReminderBroadcastJob] Seller##{seller.id} failed: #{e.message}"
    end

    Rails.logger.info "[SendCatalogUploadReminderBroadcastJob] dry_run=#{dry_run} " \
                      "total_eligible=#{stats[:total_eligible]} " \
                      "queued=#{stats[:queued]} skipped_recent_ads=#{stats[:skipped_recent_ads]} " \
                      "skipped_recent_notification=#{stats[:skipped_recent_notification]} " \
                      "failed=#{stats[:failed]}"

    stats.merge(dry_run: dry_run)
  end
end
