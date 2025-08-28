class CreatePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :payments do |t|
      t.string :transaction_type
      t.string :trans_id
      t.string :trans_time
      t.decimal :trans_amount
      t.string :business_short_code
      t.string :bill_ref_number
      t.string :invoice_number
      t.string :org_account_balance
      t.string :third_party_trans_id
      t.string :msisdn
      t.string :first_name
      t.string :middle_name
      t.string :last_name

      t.timestamps
    end
  end
end
