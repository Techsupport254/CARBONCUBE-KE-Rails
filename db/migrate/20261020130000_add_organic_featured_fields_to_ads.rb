class AddOrganicFeaturedFieldsToAds < ActiveRecord::Migration[7.1]
  def change
    add_column :ads, :featured_at, :datetime
    add_column :ads, :featured_until, :datetime
    add_column :ads, :last_featured_at, :datetime
    add_column :ads, :organic_quality_score, :decimal, precision: 6, scale: 2, default: 0.0

    add_index :ads, [:featured_until, :deleted, :flagged], name: 'index_ads_on_featured_until_deleted_flagged'
    add_index :ads, [:category_id, :featured_until], name: 'index_ads_on_category_and_featured_until'
  end
end
