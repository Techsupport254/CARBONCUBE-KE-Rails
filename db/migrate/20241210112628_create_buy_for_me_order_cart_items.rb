# db/migrate/[timestamp]_create_cart_items.rb
class CreateBuyForMeOrderCartItems < ActiveRecord::Migration[7.1]
  def change
    create_table :buy_for_me_order_cart_items do |t|
      t.references :buyer, null: false, foreign_key: true
      t.references :ad, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.decimal :price, precision: 10, scale: 2, null: false, default: 0

      t.timestamps
    end
  end
end
