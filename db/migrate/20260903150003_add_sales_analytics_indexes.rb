class AddSalesAnalyticsIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # Click events metadata keys used by filters, totals, and contact counts
    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_click_events_on_metadata_action
        ON click_events ((metadata ->> 'action'))
        WHERE (metadata ->> 'action') IS NOT NULL
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_click_events_on_metadata_action_type
        ON click_events ((metadata ->> 'action_type'))
        WHERE (metadata ->> 'action_type') IS NOT NULL
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_click_events_on_metadata_converted
        ON click_events ((metadata ->> 'converted_from_guest'))
        WHERE (metadata ->> 'converted_from_guest') IS NOT NULL
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_click_events_on_metadata_post_login
        ON click_events ((metadata ->> 'post_login_reveal'))
        WHERE (metadata ->> 'post_login_reveal') IS NOT NULL
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_click_events_on_metadata_login_modal
        ON click_events ((metadata ->> 'triggered_login_modal'))
        WHERE (metadata ->> 'triggered_login_modal') IS NOT NULL
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_click_events_on_metadata_user_role
        ON click_events ((metadata ->> 'user_role'))
        WHERE (metadata ->> 'user_role') IS NOT NULL
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_click_events_on_metadata_device_hash
        ON click_events ((metadata ->> 'device_hash'))
        WHERE (metadata ->> 'device_hash') IS NOT NULL
    SQL

    # Analytics source and UTM columns used by sales/analytics/sources
    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_analytics_on_created_at
        ON analytics (created_at)
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_analytics_on_source_lower
        ON analytics (LOWER(source))
        WHERE source IS NOT NULL AND source <> ''
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_analytics_on_utm_source_lower
        ON analytics (LOWER(utm_source))
        WHERE utm_source IS NOT NULL AND utm_source <> ''
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_analytics_on_utm_medium_lower
        ON analytics (LOWER(utm_medium))
        WHERE utm_medium IS NOT NULL AND utm_medium <> ''
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_analytics_on_utm_campaign_lower
        ON analytics (LOWER(utm_campaign))
        WHERE utm_campaign IS NOT NULL AND utm_campaign <> ''
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_analytics_on_referrer
        ON analytics (referrer)
        WHERE referrer IS NOT NULL AND referrer <> ''
    SQL
  end

  def down
    %w[
      index_click_events_on_metadata_action
      index_click_events_on_metadata_action_type
      index_click_events_on_metadata_converted
      index_click_events_on_metadata_post_login
      index_click_events_on_metadata_login_modal
      index_click_events_on_metadata_user_role
      index_click_events_on_metadata_device_hash
      index_analytics_on_created_at
      index_analytics_on_source_lower
      index_analytics_on_utm_source_lower
      index_analytics_on_utm_medium_lower
      index_analytics_on_utm_campaign_lower
      index_analytics_on_referrer
    ].each do |name|
      execute "DROP INDEX IF EXISTS #{name}"
    end
  end
end
