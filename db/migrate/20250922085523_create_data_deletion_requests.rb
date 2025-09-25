class CreateDataDeletionRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :data_deletion_requests do |t|
      t.string :full_name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :account_type, null: false
      t.text :reason
      t.string :status, null: false, default: 'pending'
      t.string :token, null: false
      t.datetime :requested_at, null: false
      t.datetime :verified_at
      t.datetime :processed_at
      t.text :rejection_reason
      t.text :admin_notes

      t.timestamps
    end
    
    add_index :data_deletion_requests, :email
    add_index :data_deletion_requests, :token, unique: true
    add_index :data_deletion_requests, :status
    add_index :data_deletion_requests, :requested_at
  end
end
