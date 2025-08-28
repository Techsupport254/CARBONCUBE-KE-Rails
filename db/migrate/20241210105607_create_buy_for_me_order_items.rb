class CreateBuyForMeOrderItems < ActiveRecord::Migration[7.1]
  def change
    create_table :buy_for_me_order_items do |t|
      t.references :buy_for_me_order, null: false, foreign_key: true
      t.references :ad, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.decimal :price, precision: 10, scale: 2, default: "0.0", null: false
      t.decimal :total_price, precision: 10, scale: 2, default: "0.0", null: false


      t.datetime :created_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.datetime :updated_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end
  end
end