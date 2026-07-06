# frozen_string_literal: true

module ActivityTracking
  extend ActiveSupport::Concern

  included do
    before_action :track_user_activity
  end

  private

  THROTTLE_PERIOD = 5.minutes # Only update database every 5 minutes

  def track_user_activity
    return unless current_user
    return unless current_user.respond_to?(:last_active_at)

    # Use Redis to throttle database updates
    redis_key = "user_activity:#{current_user.class.name}:#{current_user.id}"
    
    # Check if we've recently updated this user's activity
    last_update = RedisConnection.with { |conn| conn.get(redis_key) }
    
    if last_update.nil?
      # First activity or throttle period expired - update database
      update_user_activity(current_user)
      
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
