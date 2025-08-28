# db/migrate/XXXX_create_seller_tiers.rb
class CreateSellerTiers < ActiveRecord::Migration[7.1]
  def change
    create_table :seller_tiers do |t|
      t.references :seller, null: false, foreign_key: true
      t.references :tier, null: false, foreign_key: true
      t.integer :duration_months, null: false

      t.timestamps
    end
  end
end
