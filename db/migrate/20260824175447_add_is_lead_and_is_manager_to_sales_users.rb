class AddIsLeadAndIsManagerToSalesUsers < ActiveRecord::Migration[7.1]
  def up
    add_column :sales_users, :is_lead, :boolean, null: false, default: false
    add_column :sales_users, :is_manager, :boolean, null: false, default: false

    # Migrate old compensation_type values into the new booleans and proper type
    SalesUser.where(compensation_type: 'lead').find_each do |user|
      user.update_columns(is_lead: true, compensation_type: 'employed')
    end

    SalesUser.where(compensation_type: 'manager').find_each do |user|
      user.update_columns(is_manager: true, compensation_type: 'employed')
    end

    SalesUser.where(compensation_type: 'employee').find_each do |user|
      user.update_columns(compensation_type: 'employed')
    end
  end

  def down
    remove_column :sales_users, :is_lead
    remove_column :sales_users, :is_manager
  end
end
