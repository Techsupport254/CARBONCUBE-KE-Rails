# frozen_string_literal: true

# Fans the catalog upload request out to every active seller. Per-seller work
# is delegated to SendCatalogUploadRequestJob so each send is independently
# retryable.
#
# Idempotent: sellers that already received this campaign (matched by the
# in-app Notification title, which every processed seller gets regardless of
# channel availability) are skipped on re-runs.
#
#   SendCatalogUploadBroadcastJob.perform_later(dry_run: true)   # counts only
#   SendCatalogUploadBroadcastJob.perform_later(dry_run: false)  # live
class SendCatalogUploadBroadcastJob < ApplicationJob
  queue_as :broadcast

  def perform(dry_run: true)
    title = SendCatalogUploadRequestJob::NOTIFICATION_TITLE

    sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])

    stats = { eligible: 0, queued: 0, skipped_duplicate: 0, failed: 0 }

    sellers.find_each(batch_size: 50) do |seller|
      stats[:eligible] += 1

      if Notification.exists?(recipient: seller, title: title)
        stats[:skipped_duplicate] += 1
        next
      end

      SendCatalogUploadRequestJob.perform_later(seller.id) unless dry_run
      stats[:queued] += 1
      sleep(0.02) # keep Sidekiq enqueue bursts gentle on Redis
    rescue StandardError => e
      stats[:failed] += 1
      Rails.logger.error "[SendCatalogUploadBroadcastJob] Seller##{seller.id} failed: #{e.message}"
    end

    Rails.logger.info "[SendCatalogUploadBroadcastJob] dry_run=#{dry_run} " \
                      "eligible=#{stats[:eligible]} queued=#{stats[:queued]} " \
                      "skipped=#{stats[:skipped_duplicate]} failed=#{stats[:failed]}"
    stats.merge(dry_run: dry_run)
  end
end
