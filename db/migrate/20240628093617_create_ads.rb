class CreateAds < ActiveRecord::Migration[7.1]
  def change
    create_table :ads do |t|
      t.references :seller, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.references :subcategory, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.text :media
      t.decimal :price, precision: 10, scale: 2
      t.integer :quantity
      t.string :brand
      t.integer :condition, default: 0, null: false  # 0: brand new, 1: second hand
      t.string :manufacturer
      t.decimal :item_weight, precision: 10, scale: 2
      t.string :weight_unit, default: 'Grams' # Add weight unit field
      t.decimal :item_length, precision: 10, scale: 2
      t.decimal :item_width, precision: 10, scale: 2
      t.decimal :item_height, precision: 10, scale: 2
      t.boolean :flagged, default: false 
      
      t.datetime :created_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.datetime :updated_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end
  end
end
