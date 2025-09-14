class AddBestSellersPerformanceIndexes < ActiveRecord::Migration[7.1]
  def up
    # Indexes for order_items to optimize sales queries
    add_index :order_items, [:ad_id, :quantity], name: 'index_order_items_on_ad_id_quantity' unless index_exists?(:order_items, [:ad_id, :quantity], name: 'index_order_items_on_ad_id_quantity')
    
    # Indexes for reviews to optimize review queries
    add_index :reviews, [:ad_id, :rating], name: 'index_reviews_on_ad_id_rating' unless index_exists?(:reviews, [:ad_id, :rating], name: 'index_reviews_on_ad_id_rating')
    
    # Indexes for click_events to optimize click queries
    add_index :click_events, [:ad_id, :created_at], name: 'index_click_events_on_ad_id_created_at' unless index_exists?(:click_events, [:ad_id, :created_at], name: 'index_click_events_on_ad_id_created_at')
    
    # Composite index for ads with seller joins for best sellers queries (only if deleted column exists)
    if column_exists?(:ads, :deleted)
      add_index :ads, [:deleted, :flagged, :seller_id, :created_at, :id], name: 'index_ads_best_sellers_perf' unless index_exists?(:ads, [:deleted, :flagged, :seller_id, :created_at, :id], name: 'index_ads_best_sellers_perf')
    end
    
    # Index for wish_lists
    add_index :wish_lists, :ad_id, name: 'index_wish_lists_on_ad_id' unless index_exists?(:wish_lists, :ad_id, name: 'index_wish_lists_on_ad_id')
    
    # Index for seller_tiers
    add_index :seller_tiers, [:seller_id, :tier_id], name: 'index_seller_tiers_on_seller_id_tier_id' unless index_exists?(:seller_tiers, [:seller_id, :tier_id], name: 'index_seller_tiers_on_seller_id_tier_id')
  end

  def down
    # Remove indexes in reverse order
    remove_index :seller_tiers, name: 'index_seller_tiers_on_seller_id_tier_id' if index_exists?(:seller_tiers, name: 'index_seller_tiers_on_seller_id_tier_id')
    remove_index :wish_lists, name: 'index_wish_lists_on_ad_id' if index_exists?(:wish_lists, name: 'index_wish_lists_on_ad_id')
    remove_index :ads, name: 'index_ads_best_sellers_perf' if index_exists?(:ads, name: 'index_ads_best_sellers_perf')
    remove_index :click_events, name: 'index_click_events_on_ad_id_created_at' if index_exists?(:click_events, name: 'index_click_events_on_ad_id_created_at')
    remove_index :reviews, name: 'index_reviews_on_ad_id_rating' if index_exists?(:reviews, name: 'index_reviews_on_ad_id_rating')
    remove_index :order_items, name: 'index_order_items_on_ad_id_quantity' if index_exists?(:order_items, name: 'index_order_items_on_ad_id_quantity')
  end
end
