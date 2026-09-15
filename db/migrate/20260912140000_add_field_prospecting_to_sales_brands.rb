# frozen_string_literal: true

class AddFieldProspectingToSalesBrands < ActiveRecord::Migration[7.1]
  def change
    change_table :sales_brands, bulk: true do |t|
      t.integer :source, default: 0, null: false
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
    end

    add_index :sales_brands, :source

    change_table :sales_brand_activities, bulk: true do |t|
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
    end
  end
end
