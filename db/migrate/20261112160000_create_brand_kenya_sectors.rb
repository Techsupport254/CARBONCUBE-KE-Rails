class CreateBrandKenyaSectors < ActiveRecord::Migration[7.1]
  # Brand Kenya sector taxonomy — a SECONDARY classification for Brand Kenya
  # ads only. ads.category_id/subcategory_id stay untouched; sectors only
  # drive grouping on /brand-kenya.
  def change
    create_table :brand_kenya_sectors do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :manufacturers_scope
      t.text :artisans_scope
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end
    add_index :brand_kenya_sectors, :slug, unique: true

    add_column :ads, :brand_kenya_sector_id, :bigint
    add_column :ads, :brand_kenya_lane, :string
    add_foreign_key :ads, :brand_kenya_sectors, column: :brand_kenya_sector_id
    add_index :ads, :brand_kenya_sector_id,
              where: 'is_brand_kenya',
              name: 'index_ads_on_brand_kenya_sector'
  end
end
