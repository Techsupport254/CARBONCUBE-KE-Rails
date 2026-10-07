# frozen_string_literal: true

module ActivityTracking
  extend ActiveSupport::Concern

  # after_action, not before: authentication lives in subclass before_actions
  # that run after this concern's callback, so current_user is still nil in a
  # before_action. After the action, the authenticated user ivar is set — and
  # requests halted by failed auth never reach us.
  included do
    after_action :track_user_activity
  end

  private

  THROTTLE_PERIOD = 5.minutes # Only update database every 5 minutes

  # Controllers authenticate into different ivars per role.
  def activity_tracked_user
    current_user ||
      @current_seller ||
      @current_sales_user ||
      @current_admin ||
      @current_buyer ||
      @current_marketing_user
  end

  def track_user_activity
    user = activity_tracked_user
    return unless user.respond_to?(:last_active_at)

    # Use Redis to throttle database updates
    redis_key = "user_activity:#{user.class.name}:#{user.id}"

    # Check if we've recently updated this user's activity
    last_update = RedisConnection.with { |conn| conn.get(redis_key) }

    if last_update.nil?
      # First activity or throttle period expired - update database
      update_user_activity(user)
      
      # Set Redis key with TTL to throttle future updates
      RedisConnection.with do |conn|
        conn.setex(redis_key, THROTTLE_PERIOD.to_i, Time.current.to_i)
      end
    end
    # If key exists, we skip the database update (throttled)
  rescue StandardError => e
    # Don't fail the request if activity tracking fails
    Rails.logger.warn "Failed to track user activity: #{e.message}"
  end

  def update_user_activity(user)
    # Use update_column to skip validations and callbacks for performance
    user.update_column(:last_active_at, Time.current)
  end
end
