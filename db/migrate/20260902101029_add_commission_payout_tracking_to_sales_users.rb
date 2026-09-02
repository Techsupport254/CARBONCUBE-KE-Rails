class AddCommissionPayoutTrackingToSalesUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :sales_users, :paid_commission_batches, :integer, default: 0, null: false
    add_column :sales_users, :last_commission_paid_at, :datetime
  end
end
