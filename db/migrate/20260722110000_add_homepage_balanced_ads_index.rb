class AddHomepageBalancedAdsIndex < ActiveRecord::Migration[7.1]
  def up
    # Partial composite index for the balanced ads query
    # Covers the WHERE clause: deleted = false AND flagged = false AND media IS NOT NULL AND media != ''
    # Ordered by subcategory_id for the PARTITION BY in ROW_NUMBER()
    unless index_exists?(:ads, :subcategory_id, name: 'index_ads_balanced_subcategory')
      add_index :ads, :subcategory_id,
        name: 'index_ads_balanced_subcategory',
        where: "deleted = false AND flagged = false AND media IS NOT NULL AND media != '' AND media::text != '[]'"
    end
  end

  def down
    remove_index :ads, name: 'index_ads_balanced_subcategory' if index_exists?(:ads, name: 'index_ads_balanced_subcategory')
  end
end
