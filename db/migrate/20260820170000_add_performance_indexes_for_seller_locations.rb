class AddPerformanceIndexesForSellerLocations < ActiveRecord::Migration[7.1]
  def change
    add_index :branches, [:seller_id, :latitude], if_not_exists: true
    add_index :branches, [:latitude, :longitude], if_not_exists: true
    add_index :sellers, [:deleted, :ads_count], if_not_exists: true
    add_index :seller_tiers, [:seller_id, :tier_id], if_not_exists: true
  end
end
