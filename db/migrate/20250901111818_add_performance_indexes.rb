class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Indexes for ads table
    add_index :ads, [:deleted, :flagged, :created_at], name: 'index_ads_on_deleted_flagged_created_at'
    add_index :ads, [:category_id, :deleted, :flagged], name: 'index_ads_on_category_deleted_flagged'
    add_index :ads, [:subcategory_id, :deleted, :flagged], name: 'index_ads_on_subcategory_deleted_flagged'
    add_index :ads, [:seller_id, :deleted, :flagged], name: 'index_ads_on_seller_deleted_flagged'
    
    # Indexes for sellers table
    add_index :sellers, :blocked, name: 'index_sellers_on_blocked'
    
    # Indexes for click_events table
    add_index :click_events, [:ad_id, :event_type], name: 'index_click_events_on_ad_id_event_type'
    add_index :click_events, [:event_type, :created_at], name: 'index_click_events_on_event_type_created_at'
    
    # Indexes for categories and subcategories
    add_index :categories, :name, name: 'index_categories_on_name'
    add_index :subcategories, [:category_id, :name], name: 'index_subcategories_on_category_id_name'
    
    # Composite index for ads with seller joins
    add_index :ads, [:deleted, :flagged, :seller_id, :created_at], name: 'index_ads_on_deleted_flagged_seller_created_at'
  end
end
