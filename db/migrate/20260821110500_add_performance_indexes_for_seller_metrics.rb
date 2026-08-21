class AddPerformanceIndexesForSellerMetrics < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    # ClickEvents indexes
    add_index :click_events, :seller_id, algorithm: :concurrently, if_not_exists: true
    add_index :click_events, [:seller_id, :event_type], algorithm: :concurrently, if_not_exists: true
    add_index :click_events, [:ad_id, :event_type, :created_at], algorithm: :concurrently, if_not_exists: true, name: "index_click_events_on_ad_event_created"

    # Sellers indexes for filtering and sorting
    add_index :sellers, :created_at, algorithm: :concurrently, if_not_exists: true
    add_index :sellers, [:deleted, :blocked, :created_at], algorithm: :concurrently, if_not_exists: true, name: "index_sellers_on_status_created_at"
    add_index :sellers, [:carbon_code_id, :created_at], algorithm: :concurrently, if_not_exists: true, name: "index_sellers_on_carbon_code_created_at"

    # Reviews indexes for seller rating aggregations
    add_index :reviews, [:seller_id, :rating], algorithm: :concurrently, if_not_exists: true, name: "index_reviews_on_seller_rating"
    add_index :reviews, [:ad_id, :rating], algorithm: :concurrently, if_not_exists: true, name: "index_reviews_on_ad_rating"

    # WishLists index
    add_index :wish_lists, [:ad_id, :created_at], algorithm: :concurrently, if_not_exists: true, name: "index_wish_lists_on_ad_created_at"
  end
end
