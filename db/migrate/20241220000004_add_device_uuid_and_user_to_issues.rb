class AddDeviceUuidAndUserToIssues < ActiveRecord::Migration[7.1]
  def change
    add_column :issues, :device_uuid, :string, null: false
    add_column :issues, :user_id, :bigint, null: true
    add_column :issues, :user_type, :string, null: true # To support polymorphic association
    
    add_index :issues, :device_uuid
    add_index :issues, :user_id
    add_index :issues, [:user_id, :user_type]
    
    # Skip foreign key constraint since this is a polymorphic association
    # add_foreign_key :issues, :users, column: :user_id, on_delete: :nullify
  end
end
