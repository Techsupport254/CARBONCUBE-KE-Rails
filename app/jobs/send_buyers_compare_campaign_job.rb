# frozen_string_literal: true

class SendBuyersCompareCampaignJob < ApplicationJob
  queue_as :broadcast

  # Sidekiq retry configuration
  retry_on StandardError, wait: 1.minute, attempts: 3

  CAMPAIGN_KEY = 'campaign:buyers_compare_before_contact:sent_sellers'
  FAILURES_KEY = 'campaign:buyers_compare_before_contact:failed_sellers'

  # Performs the campaign broadcast via Sidekiq job workflow with strict idempotency.
  #
  # @param dry_run [Boolean] When true, simulates execution without sending emails.
  # @param target_email [String, nil] Optional target email to test single recipient via job workflow.
  # @param batch_size [Integer] Batch size for database querying (default: 50).
  # @param throttle_seconds [Float] Delay between individual email dispatches (default: 0.05s).
  def perform(dry_run = false, target_email = nil, batch_size = 50, throttle_seconds = 0.05)
    Rails.logger.info "[SendBuyersCompareCampaignJob] Starting campaign job run (dry_run: #{dry_run}, target_email: #{target_email.inspect})..."

    sellers_to_process = []

    if target_email.present?
      db_seller = Seller.find_by(email: target_email)
      if db_seller
        sellers_to_process = [db_seller]
      else
        Rails.logger.info "[SendBuyersCompareCampaignJob] Target email #{target_email} not in DB. Using test mock seller object..."
        sellers_to_process = [
          OpenStruct.new(
            id: "optisoft-test",
            email: target_email,
            fullname: "Optisoft Kenya Team",
            enterprise_name: "Optisoft Kenya"
          )
        ]
      end
      total_eligible = sellers_to_process.size
    else
      active_sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
                             .where.not(email: [nil, ''])
      total_eligible = active_sellers.count
    end

    if total_eligible.zero?
      Rails.logger.info "[SendBuyersCompareCampaignJob] No eligible sellers found."
      return summary_hash(dry_run, 0, 0, 0, 0, [])
    end

    already_sent_count = 0
    success_count = 0
    failed_count = 0
    failed_details = []

    # Fetch previously sent seller IDs from Redis to guarantee zero duplicate sends
    sent_seller_ids = fetch_sent_seller_ids

    process_seller_record = lambda do |seller|
      # 1. Idempotency Check: Skip if already sent in previous run/attempt
      if sent_seller_ids.include?(seller.id.to_s)
        already_sent_count += 1
        return
      end

      if dry_run
        success_count += 1
      else
        # Double-check lock atomically in Redis before sending (protects against concurrent workers)
        lock_acquired = acquire_atomic_lock(seller.id)
        unless lock_acquired
          already_sent_count += 1
          return
        end

        begin
          mail = SellerCommunicationsMailer.with(seller: seller).buyers_compare_before_contact
          mail.deliver_now

          mark_as_sent(seller.id)
          success_count += 1

          # Throttling to respect Brevo SMTP rate limits
          sleep(throttle_seconds) if throttle_seconds.positive?
        rescue => e
          release_atomic_lock(seller.id) # Release lock on failure so it can retry safely if needed
          failed_count += 1
          failed_details << { seller_id: seller.id, email: seller.email, error: e.message }
          mark_as_failed(seller.id, e.message)

          Rails.logger.error "[SendBuyersCompareCampaignJob] Failed to send email to Seller ##{seller.id} (#{seller.email}): #{e.message}"
        end
      end
    end

    if target_email.present?
      sellers_to_process.each(&process_seller_record)
    else
      active_sellers.find_in_batches(batch_size: batch_size) do |seller_batch|
        seller_batch.each(&process_seller_record)
      end
    end

    results = summary_hash(dry_run, total_eligible, already_sent_count, success_count, failed_count, failed_details)
    
    Rails.logger.info "[SendBuyersCompareCampaignJob] Campaign job execution complete. " \
                      "Total: #{total_eligible}, Sent: #{success_count}, Skipped: #{already_sent_count}, Failed: #{failed_count}"
    
    results
  end

  private

  def summary_hash(dry_run, total, skipped, successful, failed, failed_details)
    {
      dry_run: dry_run,
      total_eligible_sellers: total,
      already_sent_skipped: skipped,
      successfully_processed: successful,
      failed_count: failed,
      failed_sellers: failed_details,
      timestamp: Time.current.iso8601
    }
  end

  def fetch_sent_seller_ids
    if defined?(Redis) && Sidekiq.redis { |r| r.smembers(CAMPAIGN_KEY) }
      Sidekiq.redis { |r| r.smembers(CAMPAIGN_KEY) }
    else
      Array(Rails.cache.read(CAMPAIGN_KEY)).map(&:to_s)
    end
  rescue StandardError => e
    Rails.logger.warn "[SendBuyersCompareCampaignJob] Redis lookup warning: #{e.message}"
    []
  end

  def acquire_atomic_lock(seller_id)
    key = "lock:buyers_compare:#{seller_id}"
    if defined?(Redis)
      Sidekiq.redis { |r| r.set(key, '1', nx: true, ex: 86400) }
    else
      Rails.cache.write(key, '1', expires_in: 24.hours, unless_exist: true)
    end
  rescue StandardError
    true
  end

  def release_atomic_lock(seller_id)
    key = "lock:buyers_compare:#{seller_id}"
    if defined?(Redis)
      Sidekiq.redis { |r| r.del(key) }
    else
      Rails.cache.delete(key)
    end
  rescue StandardError
    nil
  end

  def mark_as_sent(seller_id)
    if defined?(Redis)
      Sidekiq.redis { |r| r.sadd(CAMPAIGN_KEY, seller_id.to_s) }
    else
      current = Array(Rails.cache.read(CAMPAIGN_KEY))
      Rails.cache.write(CAMPAIGN_KEY, (current + [seller_id.to_s]).uniq)
    end
  rescue StandardError => e
    Rails.logger.error "[SendBuyersCompareCampaignJob] Failed to mark seller #{seller_id} as sent: #{e.message}"
  end

  def mark_as_failed(seller_id, error)
    if defined?(Redis)
      Sidekiq.redis { |r| r.hset(FAILURES_KEY, seller_id.to_s, "#{Time.current.iso8601}: #{error}") }
    end
  rescue StandardError
    nil
  end
end
