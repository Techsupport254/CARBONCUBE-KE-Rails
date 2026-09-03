class AddClickEventTrigramIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    execute "SET search_path TO public, extensions"

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_click_events_on_metadata_device_hash_trgm
        ON click_events USING gin (lower(metadata ->> 'device_hash') gin_trgm_ops)
        WHERE (metadata ->> 'device_hash') IS NOT NULL
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_click_events_on_metadata_user_email
        ON click_events (lower(metadata ->> 'user_email'))
        WHERE (metadata ->> 'user_email') IS NOT NULL
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_click_events_on_metadata_user_email_trgm
        ON click_events USING gin (lower(metadata ->> 'user_email') gin_trgm_ops)
        WHERE (metadata ->> 'user_email') IS NOT NULL
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_click_events_on_metadata_user_agent_trgm
        ON click_events USING gin (lower(metadata ->> 'user_agent') gin_trgm_ops)
        WHERE (metadata ->> 'user_agent') IS NOT NULL
    SQL
  end

  def down
    %w[
      index_click_events_on_metadata_device_hash_trgm
      index_click_events_on_metadata_user_email
      index_click_events_on_metadata_user_email_trgm
      index_click_events_on_metadata_user_agent_trgm
    ].each do |name|
      execute "DROP INDEX IF EXISTS #{name}"
    end
  end
end
