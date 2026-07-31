# frozen_string_literal: true

class SendPhoneUpdateReminderJob < ApplicationJob
  queue_as :broadcast

  retry_on StandardError, wait: 1.minute, attempts: 3

  CAMPAIGN_PREFIX = 'campaign:request_phone_number:sent_sellers'
  FAILURES_PREFIX = 'campaign:request_phone_number:failed_sellers'

  # Executes the weekly phone number request campaign for sellers missing a phone number.
  # Automatically excludes sellers who have added their phone numbers.
  #
  # @param dry_run [Boolean] When true (default), simulates execution without sending emails or mutating Redis.
  # @param week_number [Integer] Week iteration index (1 to 4).
  # @param target_email [String, nil] Optional target email for single recipient testing.
  # @param batch_size [Integer] Batch size for database querying (default: 50).
  # @param throttle_seconds [Float] Delay between dispatches (default: 0.05s).
  def perform(dry_run = true, week_number = 1, target_email = nil, batch_size = 50, throttle_seconds = 0.05)
    week_number = [[week_number.to_i, 1].max, 4].min
    campaign_key = "#{CAMPAIGN_PREFIX}:week_#{week_number}"
    failures_key = "#{FAILURES_PREFIX}:week_#{week_number}"

    Rails.logger.info "[SendPhoneUpdateReminderJob] Starting campaign run (dry_run: #{dry_run}, week: #{week_number}/4, target_email: #{target_email.inspect})..."

    # DYNAMIC EXCLUSION: Query active sellers who STILL have a missing or empty phone number OR county
    sellers_missing_phone = Seller.where(deleted: [false, nil], blocked: [false, nil])
                                  .where("phone_number IS NULL OR phone_number = '' OR length(trim(phone_number)) = 0 OR county_id IS NULL")
                                  .where.not(email: [nil, ''])

    if target_email.present?
      sellers_missing_phone = sellers_missing_phone.where(email: target_email)
    end

    total_eligible = sellers_missing_phone.count
    if total_eligible.zero?
      Rails.logger.info "[SendPhoneUpdateReminderJob] No eligible active sellers with missing phone numbers or counties found."
      return summary_hash(dry_run, week_number, 0, 0, 0, 0, [])
    end

    already_sent_count = 0
    success_count = 0
    failed_count = 0
    failed_details = []

    # Fetch previously sent seller IDs for this specific week iteration
    sent_seller_ids = fetch_sent_seller_ids(campaign_key)

    sellers_missing_phone.find_in_batches(batch_size: batch_size) do |seller_batch|
      seller_batch.each do |seller|
        # Idempotency Check: Skip if already sent to in this week's iteration
        if sent_seller_ids.include?(seller.id.to_s)
          already_sent_count += 1
          next
        end

        if dry_run
          success_count += 1
        else
          lock_key = "lock:request_phone:week_#{week_number}:#{seller.id}"
          lock_acquired = acquire_atomic_lock(lock_key)
          unless lock_acquired
            already_sent_count += 1
            next
          end

          begin
            mail = SellerCommunicationsMailer.with(seller: seller).request_phone_number
            mail.deliver_now

            mark_as_sent(campaign_key, seller.id)
            success_count += 1

            sleep(throttle_seconds) if throttle_seconds.positive?
          rescue => e
            release_atomic_lock(lock_key)
            failed_count += 1
            failed_details << { seller_id: seller.id, email: seller.email, error: e.message }
            mark_as_failed(failures_key, seller.id, e.message)

            Rails.logger.error "[SendPhoneUpdateReminderJob] Failed to send email to Seller ##{seller.id} (#{seller.email}): #{e.message}"
          end
        end
      end
    end

    results = summary_hash(dry_run, week_number, total_eligible, already_sent_count, success_count, failed_count, failed_details)

    Rails.logger.info "[SendPhoneUpdateReminderJob] Week #{week_number} run finished. " \
                      "Total: #{total_eligible}, Sent: #{success_count}, Skipped: #{already_sent_count}, Failed: #{failed_count}"

    results
  end

  private

  def summary_hash(dry_run, week, total, skipped, successful, failed, failed_details)
    {
      dry_run: dry_run,
      week_number: week,
      max_weeks: 4,
      total_eligible_sellers: total,
      already_sent_skipped: skipped,
      successfully_processed: successful,
      failed_count: failed,
      failed_sellers: failed_details,
      timestamp: Time.current.iso8601
    }
  end

  def fetch_sent_seller_ids(campaign_key)
    if defined?(Redis)
      Sidekiq.redis { |r| r.smembers(campaign_key) }
    else
      Array(Rails.cache.read(campaign_key)).map(&:to_s)
    end
  rescue StandardError => e
    Rails.logger.warn "[SendPhoneUpdateReminderJob] Redis lookup warning: #{e.message}"
    []
  end

  def acquire_atomic_lock(key)
    if defined?(Redis)
      Sidekiq.redis { |r| r.set(key, '1', nx: true, ex: 86400 * 7) }
    else
      Rails.cache.write(key, '1', expires_in: 7.days, unless_exist: true)
    end
  rescue StandardError
    true
  end

  def release_atomic_lock(key)
    if defined?(Redis)
      Sidekiq.redis { |r| r.del(key) }
    else
      Rails.cache.delete(key)
    end
  rescue StandardError
    nil
  end

  def mark_as_sent(campaign_key, seller_id)
    if defined?(Redis)
      Sidekiq.redis { |r| r.sadd(campaign_key, seller_id.to_s) }
    else
      current = Array(Rails.cache.read(campaign_key))
      Rails.cache.write(campaign_key, (current + [seller_id.to_s]).uniq)
    end
  rescue StandardError => e
    Rails.logger.error "[SendPhoneUpdateReminderJob] Failed to mark seller #{seller_id} as sent: #{e.message}"
  end

  def mark_as_failed(failures_key, seller_id, error)
    if defined?(Redis)
      Sidekiq.redis { |r| r.hset(failures_key, seller_id.to_s, "#{Time.current.iso8601}: #{error}") }
    end
  rescue StandardError
    nil
  end
end
