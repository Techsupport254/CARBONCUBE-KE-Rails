class AdStat < ApplicationRecord
  self.table_name = 'ad_stats'
  self.primary_key = 'ad_id'

  belongs_to :ad, foreign_key: 'ad_id', inverse_of: false # rubocop:disable Rails/RedundantForeignKey

  REFRESH_LOCK_KEY = 'ad_stats:refresh_lock'

  def self.refresh!
    connection.execute('REFRESH MATERIALIZED VIEW CONCURRENTLY ad_stats')
  end

  # Enqueues a refresh only if one is not already scheduled in the last 5 minutes.
  # Called from event models (ClickEvent, Conversation, WishList, CartItem, Review)
  # so best-seller/recommendation rankings react to new activity quickly.
  def self.schedule_refresh_if_stale
    return unless Rails.cache.write(REFRESH_LOCK_KEY, true, expires_in: 5.minutes, unless_exist: true)

    RefreshAdStatsJob.perform_later
  end
end
