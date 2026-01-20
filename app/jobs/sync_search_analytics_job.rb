class SyncSearchAnalyticsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting search analytics sync from Redis to PostgreSQL"

    begin
      # Get current analytics from Redis
      redis_analytics = SearchRedisService.analytics

      # Get popular searches from different timeframes
      popular_searches = {
        all_time: SearchRedisService.popular_searches(50, :all),
        daily: SearchRedisService.popular_searches(20, :daily),
        weekly: SearchRedisService.popular_searches(30, :weekly),
        monthly: SearchRedisService.popular_searches(40, :monthly)
      }

      # Store aggregated data in PostgreSQL (upsert - update if exists, create if not)
      SearchAnalytic.find_or_initialize_by(date: Date.current).tap do |analytic|
        analytic.total_searches_today = redis_analytics[:total_searches_today]
        analytic.unique_search_terms_today = redis_analytics[:unique_search_terms_today]
        analytic.total_search_records = redis_analytics[:total_search_records]
        analytic.popular_searches_all_time = popular_searches[:all_time]
        analytic.popular_searches_daily = popular_searches[:daily]
        analytic.popular_searches_weekly = popular_searches[:weekly]
        analytic.popular_searches_monthly = popular_searches[:monthly]
        analytic.raw_analytics_data = redis_analytics
        analytic.save!
      end

      Rails.logger.info "Search analytics sync completed successfully"

    rescue => e
      Rails.logger.error "Failed to sync search analytics: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end
end