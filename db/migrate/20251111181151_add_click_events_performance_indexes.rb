class AddClickEventsPerformanceIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # Composite index for filtering by buyer_id and created_at (common in recent_click_events)
    unless index_exists?(:click_events, [:buyer_id, :created_at], name: 'index_click_events_on_buyer_id_created_at')
      add_index :click_events, [:buyer_id, :created_at], 
                name: 'index_click_events_on_buyer_id_created_at',
                algorithm: :concurrently
    end
    
    # Composite index for filtering by created_at and event_type (common in analytics queries)
    unless index_exists?(:click_events, [:created_at, :event_type], name: 'index_click_events_on_created_at_event_type')
      add_index :click_events, [:created_at, :event_type], 
                name: 'index_click_events_on_created_at_event_type',
                algorithm: :concurrently
    end
    
    # Index on metadata JSONB for faster JSON queries (using GIN index)
    unless index_exists?(:click_events, :metadata, name: 'index_click_events_on_metadata')
      add_index :click_events, :metadata, 
                using: :gin,
                name: 'index_click_events_on_metadata',
                algorithm: :concurrently
    end
  end

  def down
    remove_index :click_events, name: 'index_click_events_on_metadata' if index_exists?(:click_events, name: 'index_click_events_on_metadata')
    remove_index :click_events, name: 'index_click_events_on_created_at_event_type' if index_exists?(:click_events, name: 'index_click_events_on_created_at_event_type')
    remove_index :click_events, name: 'index_click_events_on_buyer_id_created_at' if index_exists?(:click_events, name: 'index_click_events_on_buyer_id_created_at')
  end
end
