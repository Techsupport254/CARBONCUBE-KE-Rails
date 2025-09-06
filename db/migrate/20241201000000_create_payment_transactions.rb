class CreatePaymentTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :payment_transactions do |t|
      t.references :seller, null: false, foreign_key: true
      t.references :tier, null: false, foreign_key: true
      t.references :tier_pricing, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :phone_number, null: false
      t.string :status, null: false, default: 'initiated'
      t.string :transaction_type, null: false, default: 'tier_upgrade'
      t.string :checkout_request_id, null: false
      t.string :merchant_request_id, null: false
      t.string :mpesa_receipt_number
      t.string :transaction_date
      t.string :callback_phone_number
      t.decimal :callback_amount, precision: 10, scale: 2
      t.string :stk_response_code
      t.string :stk_response_description
      t.text :error_message
      t.datetime :completed_at
      t.datetime :failed_at

      t.timestamps
    end

    add_index :payment_transactions, :checkout_request_id, unique: true
    add_index :payment_transactions, :merchant_request_id, unique: true
    add_index :payment_transactions, :status
    add_index :payment_transactions, :created_at
  end
end
