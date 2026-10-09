# frozen_string_literal: true

# Follow-up for NEW sellers: roughly a day or two after they register, ask
# them to send us their catalog. Runs on a daily sidekiq-cron schedule and
# picks up sellers created 24–48h ago — every registration window is covered
# exactly once.
#
# Idempotent: sellers that already received this campaign (matched by the
# in-app Notification title) are skipped — so anyone who already got the bulk
# broadcast won't be nudged again.
class SendCatalogUploadToNewSellersJob < ApplicationJob
  queue_as :broadcast

  MIN_AGE_HOURS = 24
  MAX_AGE_HOURS = 48

  def perform(dry_run: false, min_age_hours: MIN_AGE_HOURS, max_age_hours: MAX_AGE_HOURS)
    title = SendCatalogUploadRequestJob::NOTIFICATION_TITLE

    sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
                    .where(created_at: max_age_hours.hours.ago..min_age_hours.hours.ago)

    stats = { eligible: 0, queued: 0, skipped_duplicate: 0, failed: 0 }

    sellers.find_each do |seller|
      stats[:eligible] += 1

      if Notification.exists?(recipient: seller, title: title)
        stats[:skipped_duplicate] += 1
        next
      end

      SendCatalogUploadRequestJob.perform_later(seller.id) unless dry_run
      stats[:queued] += 1
    rescue StandardError => e
      stats[:failed] += 1
      Rails.logger.error "[SendCatalogUploadToNewSellersJob] Seller##{seller.id} failed: #{e.message}"
    end

    Rails.logger.info "[SendCatalogUploadToNewSellersJob] dry_run=#{dry_run} " \
                      "window=#{max_age_hours}-#{min_age_hours}h ago " \
                      "eligible=#{stats[:eligible]} queued=#{stats[:queued]} " \
                      "skipped=#{stats[:skipped_duplicate]} failed=#{stats[:failed]}"
    stats.merge(dry_run: dry_run)
  end
end
