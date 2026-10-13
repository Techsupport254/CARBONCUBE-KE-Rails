# frozen_string_literal: true

# Schedules the native App Store / Play Store review prompt for qualifying users.
#
# A user is eligible when they meet ALL of the following:
#   • They have been registered for at least MIN_ACCOUNT_AGE_DAYS days
#   • They have at least MIN_SESSIONS sessions recorded (via ClickEvents as a proxy)
#   • They don't already have an app_store_review_prompt row
#
# This job creates a pending AppStoreReviewPrompt for each qualifying user with
# a scheduled_at in the past (i.e. "show immediately on next app open").
#
# Re-prompt logic:
#   After a user is shown the dialog (status = 'shown'), they won't be re-prompted
#   unless you reset their record or a future version of this job handles it.
#   Apple/Google also enforce their own rate limits on the native dialog.
#
# Scheduled by sidekiq-cron (see config/schedule.yml).
class ScheduleAppStoreReviewPromptsJob < ApplicationJob
  queue_as :low

  # Minimum number of days since account creation before prompting.
  MIN_ACCOUNT_AGE_DAYS = 7

  # Minimum number of qualifying engagement events (used as a session proxy).
  MIN_SESSIONS = 3

  def perform
    qualifying_users.find_each do |user|
      AppStoreReviewPrompt.create!(
        user: user,
        status: 'pending',
        scheduled_at: Time.current
      )
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      Rails.logger.warn("ScheduleAppStoreReviewPromptsJob: skipped user #{user.id} (#{user.class.name}): #{e.message}")
    end

    Rails.logger.info("ScheduleAppStoreReviewPromptsJob: done")
  end

  private

  # Returns all Buyers and Sellers who:
  #   1. Have been registered long enough
  #   2. Have enough engagement events
  #   3. Don't already have a prompt row
  def qualifying_users
    existing_user_ids_by_type = existing_prompt_user_ids

    [Buyer, Seller].flat_map do |klass|
      type_name = klass.name
      excluded_ids = existing_user_ids_by_type[type_name] || []

      klass
        .where('created_at <= ?', MIN_ACCOUNT_AGE_DAYS.days.ago)
        .where.not(id: excluded_ids)
        .joins(
          "INNER JOIN (
            SELECT COALESCE(buyer_id, seller_id) AS uid,
                   COUNT(*) AS session_count
            FROM click_events
            WHERE created_at >= '2000-01-01'
            GROUP BY uid
            HAVING COUNT(*) >= #{MIN_SESSIONS}
          ) AS eng ON eng.uid = #{klass.table_name}.id"
        )
    end
  end

  def existing_prompt_user_ids
    AppStoreReviewPrompt
      .group(:user_type)
      .pluck(:user_type, Arel.sql('ARRAY_AGG(user_id)'))
      .to_h
  end
end
