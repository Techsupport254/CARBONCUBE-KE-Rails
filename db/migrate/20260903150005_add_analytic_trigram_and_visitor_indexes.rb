class AddAnalyticTrigramAndVisitorIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_analytics_on_data_user_email_trgm
        ON analytics USING gin (lower(data ->> 'user_email') gin_trgm_ops)
        WHERE (data ->> 'user_email') IS NOT NULL
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_analytics_on_data_email_trgm
        ON analytics USING gin (lower(data ->> 'email') gin_trgm_ops)
        WHERE (data ->> 'email') IS NOT NULL
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_analytics_on_data_device_fingerprint_trgm
        ON analytics USING gin (lower(data ->> 'device_fingerprint') gin_trgm_ops)
        WHERE (data ->> 'device_fingerprint') IS NOT NULL
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_analytics_on_user_agent_trgm
        ON analytics USING gin (lower(user_agent) gin_trgm_ops)
        WHERE user_agent IS NOT NULL
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_analytics_on_visitor_id_created_at
        ON analytics (((data ->> 'visitor_id')), created_at)
        WHERE (data ->> 'visitor_id') IS NOT NULL
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS index_analytics_on_data_user_email_trgm"
    execute "DROP INDEX IF EXISTS index_analytics_on_data_email_trgm"
    execute "DROP INDEX IF EXISTS index_analytics_on_data_device_fingerprint_trgm"
    execute "DROP INDEX IF EXISTS index_analytics_on_user_agent_trgm"
    execute "DROP INDEX IF EXISTS index_analytics_on_visitor_id_created_at"
  end
end
