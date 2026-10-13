# frozen_string_literal: true

# Fans out the catalog upload reminder across all 4 channels to sellers who
# have NOT yet submitted their catalog (i.e. sellers with ZERO active ads).
#
# Strictly excludes any seller who has active ads or has already received this reminder.
#
# Usage:
#   SendCatalogUploadReminderBroadcastJob.perform_later(dry_run: true)   # counts only
#   SendCatalogUploadReminderBroadcastJob.perform_later(dry_run: false)  # live execution
#
# Scheduling for 12:00 noon:
#   scheduled_time = Time.zone.parse("2026-10-13 12:00:00")
#   SendCatalogUploadReminderBroadcastJob.set(wait_until: scheduled_time).perform_later(dry_run: false)
class SendCatalogUploadReminderBroadcastJob < ApplicationJob
  queue_as :broadcast

  def perform(dry_run: true)
    title = SendCatalogUploadReminderJob::NOTIFICATION_TITLE

    # Eligible: active sellers who currently have ZERO active ads
    active_sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
    sellers_with_active_ads_ids = Ad.where(deleted: false).select(:seller_id).distinct

    eligible_sellers = active_sellers.where.not(id: sellers_with_active_ads_ids)

    stats = {
      total_sellers_without_ads: eligible_sellers.count,
      queued: 0,
      skipped_has_ads: 0,
      skipped_duplicate: 0,
      failed: 0
    }

    eligible_sellers.find_each(batch_size: 50) do |seller|
      # Double check: strictly exclude anyone who has active ads
      if seller.ads.where(deleted: false).exists?
        stats[:skipped_has_ads] += 1
        next
      end

      # Idempotent: do not re-send if already notified for this reminder
      if Notification.exists?(recipient: seller, title: title)
        stats[:skipped_duplicate] += 1
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
                      "total_without_ads=#{stats[:total_sellers_without_ads]} " \
                      "queued=#{stats[:queued]} skipped_has_ads=#{stats[:skipped_has_ads]} " \
                      "skipped_duplicate=#{stats[:skipped_duplicate]} failed=#{stats[:failed]}"

    stats.merge(dry_run: dry_run)
  end
end
