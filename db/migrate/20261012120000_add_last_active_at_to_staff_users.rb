class AddLastActiveAtToStaffUsers < ActiveRecord::Migration[7.1]
  # Presence/last-seen support: buyers and sellers already have the column;
  # staff models lacked it so ConversationsController#online_status and the
  # presence broadcasts could never report a last_seen for them.
  def change
    add_column :admins, :last_active_at, :datetime
    add_column :sales_users, :last_active_at, :datetime
    add_column :marketing_users, :last_active_at, :datetime
  end
end
