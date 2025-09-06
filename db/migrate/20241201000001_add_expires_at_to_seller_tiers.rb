class AddExpiresAtToSellerTiers < ActiveRecord::Migration[7.0]
  def change
    add_column :seller_tiers, :expires_at, :datetime
    add_column :seller_tiers, :payment_transaction_id, :bigint
    
    add_index :seller_tiers, :expires_at
    add_index :seller_tiers, :payment_transaction_id
  end
end
