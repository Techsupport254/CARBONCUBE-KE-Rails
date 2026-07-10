class MigrateCallQueueToArray < ActiveRecord::Migration[7.1]
  def up
    # Migrate existing CallQueue entries to use reasons array
    # Use raw SQL to bypass validations
    
    # For sellers with single entry, convert queue_type to reasons array
    execute <<-SQL
      UPDATE call_queues 
      SET reasons = JSON_BUILD_ARRAY(queue_type)
      WHERE reasons = '[]' AND queue_type IS NOT NULL
    SQL
    
    # For sellers with multiple entries, consolidate them
    # First, identify sellers with duplicates
    execute <<-SQL
      WITH duplicates AS (
        SELECT seller_id, ARRAY_AGG(DISTINCT queue_type) as all_reasons, MIN(id) as keep_id
        FROM call_queues
        WHERE queue_type IS NOT NULL
        GROUP BY seller_id
        HAVING COUNT(*) > 1
      )
      UPDATE call_queues 
      SET reasons = (SELECT all_reasons::text FROM duplicates WHERE call_queues.id = duplicates.keep_id)
      WHERE id IN (SELECT keep_id FROM duplicates)
    SQL
    
    # Delete duplicate entries, keeping only the first one for each seller
    execute <<-SQL
      DELETE FROM call_queues
      WHERE id NOT IN (
        SELECT DISTINCT ON (seller_id) id
        FROM call_queues
        ORDER BY seller_id, created_at
      )
    SQL
  end
  
  def down
    # This migration is one-way, so we can't easily rollback
    # In production, you'd want to backup before running this
    raise ActiveRecord::IrreversibleMigration
  end
end
