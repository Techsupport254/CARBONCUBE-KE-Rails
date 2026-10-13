# frozen_string_literal: true

# Sends "Install the CCK App" emails with structured scheduling and reminder delays
# to avoid spamming users.
#
# Anti-Spam & Scheduling Rules:
# 1. Minimum Account Age: Only users registered for at least MIN_ACCOUNT_AGE_DAYS (3 days)
#    are considered, giving them time to explore the platform on web first.
# 2. Maximum Account Age: Accounts older than MAX_ACCOUNT_AGE_DAYS (90 days) without
#    engagement are not nagged.
# 3. Scheduled Reminders with Backoff:
#    - Stage 1 (Initial): 3 days after registration
#    - Stage 2 (Reminder 1): 7 days after initial send (T + 10d)
#    - Stage 3 (Final Reminder): 14 days after reminder 1 (T + 24d)
#    - Maximum 3 total sends ever (MAX_SENDS = 3). Never emailed again after stage 3.
# 4. Immediate Stop upon Installation:
#    - If a user installs the app and registers an iOS or Android DeviceToken at any point,
#      their campaign is marked 'completed' and all further reminders are halted instantly.
# 5. Global Marketing Suppression:
#    - Deleted or blocked accounts are skipped.
#    - Hard bounce / suppressed status honored.
#
# State tracking is backed by the `app_install_nudge_campaigns` table.
# Scheduled by sidekiq-cron (see config/schedule.yml).
class SendAppInstallNudgeJob < ApplicationJob
  queue_as :broadcast

  MIN_ACCOUNT_AGE_DAYS = 3
  MAX_ACCOUNT_AGE_DAYS = 90
  BATCH_SIZE = 100

  def perform(dry_run: false)
    # Step 1: Enroll any new qualifying users who don't have a campaign yet
    enrolled_count = enroll_qualifying_users

    # Step 2: Check for users who recently installed the app and mark them completed
    completed_count = complete_installed_campaigns

    # Step 3: Process campaigns ready for sending (initial or reminders)
    send_stats = process_ready_campaigns(dry_run: dry_run)

    summary = {
      enrolled: enrolled_count,
      installed_and_completed: completed_count,
      sent_initial: send_stats[:initial],
      sent_reminders: send_stats[:reminders],
      exhausted: send_stats[:exhausted],
      skipped_installed: send_stats[:skipped_installed],
      failed: send_stats[:failed],
      dry_run: dry_run
    }

    Rails.logger.info "[SendAppInstallNudgeJob] #{summary.inspect}"
    summary
  end

  private

  # Enrolls eligible buyers and sellers into the campaign table
  def enroll_qualifying_users
    enrolled = 0

    [Buyer, Seller].each do |klass|
      eligible_users_for_enrollment(klass).find_each(batch_size: BATCH_SIZE) do |user|
        campaign = AppInstallNudgeCampaign.build_for(user)
        # If user registered earlier, calibrate first send to be ready immediately or relative to created_at
        earliest_send = user.created_at + AppInstallNudgeCampaign::SEND_DELAYS[0]
        campaign.next_send_at = [earliest_send, Time.current].max

        campaign.save!
        enrolled += 1
      rescue ActiveRecord::RecordNotUnique
        # Concurrency race guard
        next
      rescue StandardError => e
        Rails.logger.error "[SendAppInstallNudgeJob] Enrollment failed for #{klass.name}##{user.id}: #{e.message}"
      end
    end

    enrolled
  end

  # Returns users with no campaign row and no mobile device tokens
  def eligible_users_for_enrollment(klass)
    existing_campaign_uids = AppInstallNudgeCampaign
      .where(user_type: klass.name)
      .select(:user_id)

    users_with_mobile_tokens = DeviceToken
      .where(user_type: klass.name, platform: %w[ios android])
      .where.not(user_id: nil)
      .select(:user_id)

    klass
      .where(deleted: [false, nil], blocked: [false, nil])
      .where.not(email: [nil, ''])
      .where(created_at: MAX_ACCOUNT_AGE_DAYS.days.ago..MIN_ACCOUNT_AGE_DAYS.days.ago)
      .where.not(id: existing_campaign_uids)
      .where.not(id: users_with_mobile_tokens)
  end

  # Fast sweep: mark campaigns completed for anyone who has registered a mobile token
  def complete_installed_campaigns
    active_campaigns = AppInstallNudgeCampaign.where(status: %w[enrolled active])

    installed_user_pairs = DeviceToken
      .where(platform: %w[ios android])
      .where.not(user_id: nil)
      .distinct
      .pluck(:user_type, :user_id)

    return 0 if installed_user_pairs.empty?

    completed = 0
    installed_user_pairs.each do |user_type, user_id|
      campaign = active_campaigns.find_by(user_type: user_type, user_id: user_id)
      if campaign
        campaign.mark_completed!
        completed += 1
      end
    end

    completed
  end

  # Process campaigns ready to send right now
  def process_ready_campaigns(dry_run:)
    stats = { initial: 0, reminders: 0, exhausted: 0, skipped_installed: 0, failed: 0 }

    AppInstallNudgeCampaign.ready_to_send.includes(:user).find_each(batch_size: BATCH_SIZE) do |campaign|
      user = campaign.user

      # 1. Guard against missing or deactivated users
      if user.blank? || user.try(:deleted) || user.try(:blocked) || user.email.blank?
        campaign.suppress!
        next
      end

      # 2. Re-verify they haven't installed the app right before dispatch
      if user_has_mobile_app?(user)
        campaign.mark_completed!
        stats[:skipped_installed] += 1
        next
      end

      # 3. Guard against exceeding maximum sends
      if campaign.sends_count >= AppInstallNudgeCampaign::MAX_SENDS
        campaign.update!(status: 'exhausted')
        stats[:exhausted] += 1
        next
      end

      # 4. Dispatch email with current reminder tier
      reminder_number = campaign.sends_count # 0 = initial, 1 = reminder 1, 2 = reminder 2

      unless dry_run
        MarketingMailer.app_install_nudge(
          recipient: user,
          reminder_number: reminder_number
        ).deliver_later

        campaign.record_send!
      end

      if reminder_number == 0
        stats[:initial] += 1
      else
        stats[:reminders] += 1
      end
    rescue StandardError => e
      stats[:failed] += 1
      Rails.logger.error "[SendAppInstallNudgeJob] Send failed for campaign ##{campaign.id}: #{e.message}"
    end

    stats
  end

  def user_has_mobile_app?(user)
    DeviceToken.exists?(
      user_type: user.class.name,
      user_id: user.id,
      platform: %w[ios android]
    )
  end
end
