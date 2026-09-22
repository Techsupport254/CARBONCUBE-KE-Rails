# frozen_string_literal: true

class AddIsBrandKenyaToAds < ActiveRecord::Migration[7.1]
  def up
    add_column :ads, :is_brand_kenya, :boolean, default: false, null: false
    add_index :ads, :is_brand_kenya
    add_index :ads, [:is_brand_kenya, :deleted, :flagged], name: 'index_ads_on_is_brand_kenya_deleted_flagged'

    # Backfill existing ads belonging to onboarded Brand Kenya sellers
    execute <<-SQL.squish
      UPDATE ads
      SET is_brand_kenya = TRUE
      WHERE seller_id IN (
        SELECT seller_id FROM sales_brands
        WHERE status = 4 AND seller_id IS NOT NULL
      );
    SQL
  end

  def down
    remove_index :ads, name: 'index_ads_on_is_brand_kenya_deleted_flagged', if_exists: true
    remove_index :ads, :is_brand_kenya, if_exists: true
    remove_column :ads, :is_brand_kenya, if_exists: true
  end
end
