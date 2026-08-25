class AddLeadAndManagerToSalesUsers < ActiveRecord::Migration[7.1]
  def change
    add_reference :sales_users, :lead, type: :uuid, foreign_key: { to_table: :sales_users }, null: true
    add_column :sales_users, :manager_email, :string
  end
end
