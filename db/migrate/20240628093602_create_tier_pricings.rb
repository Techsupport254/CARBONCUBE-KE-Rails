class CreateTierPricings < ActiveRecord::Migration[7.1]
  def change
    create_table :tier_pricings do |t|
      t.references :tier, null: false, foreign_key: true
      t.integer :duration_months, null: false
      t.decimal :price, null: false, precision: 10, scale: 2
      t.timestamps
    end
  end
end
