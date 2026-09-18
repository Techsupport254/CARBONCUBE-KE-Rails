# frozen_string_literal: true

# Supplier-catalog / inventory fields on ads.
# - sku: supplier product code (from wholesale price lists)
# - units_per_pack: "PCS/CTN" — sellable units per carton/pack
# - stock_quantity: NULL means "not tracked" (ad is treated as in stock),
#   0 means out of stock. Intentionally nullable so existing ads stay IN_STOCK.
class AddInventoryFieldsToAds < ActiveRecord::Migration[7.1]
  def change
    change_table :ads, bulk: true do |t|
      t.string :sku
      t.integer :units_per_pack
      t.integer :stock_quantity
    end

    add_index :ads, [:seller_id, :sku]
  end
end
