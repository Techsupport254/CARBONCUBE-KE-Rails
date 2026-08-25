class AddCompensationTypeToSalesUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :sales_users, :compensation_type, :string
  end
end
