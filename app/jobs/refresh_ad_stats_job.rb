# Refreshes the ad_stats materialized view every 15 minutes.
class RefreshAdStatsJob < ApplicationJob
  queue_as :low

  def perform
    Rails.logger.info '[RefreshAdStatsJob] Starting refresh'
    AdStat.refresh!

    # Pre-warm the global best-seller cache so homepage users never hit a cold cache.
    Rails.logger.info '[RefreshAdStatsJob] Pre-warming best-seller cache'
    Buyer::AdsController.new.send(:calculate_best_sellers_fast, 20)

    Rails.logger.info '[RefreshAdStatsJob] Refresh complete'
  end
end
