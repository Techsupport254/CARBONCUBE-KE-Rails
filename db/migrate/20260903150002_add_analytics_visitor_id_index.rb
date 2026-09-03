class AddAnalyticsVisitorIdIndex < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_analytics_on_created_at_visitor_id
        ON analytics (created_at, ((data ->> 'visitor_id')))
        WHERE data ->> 'visitor_id' IS NOT NULL
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP INDEX IF EXISTS index_analytics_on_created_at_visitor_id
    SQL
  end
end
