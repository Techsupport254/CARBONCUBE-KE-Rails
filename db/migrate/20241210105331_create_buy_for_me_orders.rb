class CreateBuyForMeOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :buy_for_me_orders do |t|
      t.references :buyer, null: false, foreign_key: true
      # t.string :status, default: 'Processing'  # Default status is 'processing'
      t.decimal :total_amount, precision: 10, scale: 2
      t.decimal :processing_fee, precision: 10, scale: 2  # New column for processing fee
      t.decimal :delivery_fee, precision: 10, scale: 2    # New column for delivery fee
      t.string :mpesa_transaction_code

      t.datetime :created_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.datetime :updated_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end
  end
end
