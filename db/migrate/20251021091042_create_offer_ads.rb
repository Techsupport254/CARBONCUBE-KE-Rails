class CreateOfferAds < ActiveRecord::Migration[7.1]
  def change
    create_table :offer_ads do |t|
      t.references :offer, null: false, foreign_key: true
      t.references :ad, null: false, foreign_key: true
      t.decimal :discount_percentage, precision: 5, scale: 2, null: false
      t.decimal :original_price, precision: 10, scale: 2, null: false
      t.decimal :discounted_price, precision: 10, scale: 2, null: false
      t.boolean :is_active, default: true, null: false
      t.text :seller_notes # Optional notes from seller about the discount

      t.timestamps
    end
    
    # Add indexes for performance
    add_index :offer_ads, [:offer_id, :ad_id], unique: true
    add_index :offer_ads, :is_active
    add_index :offer_ads, :discount_percentage
    add_index :offer_ads, [:offer_id, :is_active]
  end
end
