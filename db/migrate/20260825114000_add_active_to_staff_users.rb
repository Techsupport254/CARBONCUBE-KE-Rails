class AddActiveToStaffUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :admins, :active, :boolean, default: true, null: false
    add_column :admins, :deactivated_at, :datetime
    add_index :admins, :active

    add_column :sales_users, :active, :boolean, default: true, null: false
    add_column :sales_users, :deactivated_at, :datetime
    add_index :sales_users, :active

    add_column :marketing_users, :active, :boolean, default: true, null: false
    add_column :marketing_users, :deactivated_at, :datetime
    add_index :marketing_users, :active
  end
end
