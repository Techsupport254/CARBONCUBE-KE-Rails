class CreateSellerPricingTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :seller_pricing_templates do |t|
      t.references :seller, type: :uuid, null: false, foreign_key: true
      t.references :category, type: :bigint, null: true, foreign_key: true
      t.references :subcategory, type: :bigint, null: true, foreign_key: true

      t.string :pricing_unit, null: false, default: 'piece'
      t.string :price_display_mode, null: false, default: 'public'
      t.jsonb :price_tiers, null: false, default: []

      t.timestamps
    end

    add_index :seller_pricing_templates, [:category_id, :subcategory_id], name: 'idx_spt_category_subcategory'
  end
end
