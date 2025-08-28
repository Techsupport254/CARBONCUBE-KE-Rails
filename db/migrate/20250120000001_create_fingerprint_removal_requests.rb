class CreateFingerprintRemovalRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :fingerprint_removal_requests do |t|
      t.string :requester_name, null: false
      t.text :device_description, null: false
      t.string :device_hash, null: false
      t.text :user_agent, null: false
      t.string :status, default: 'pending', null: false
      t.text :rejection_reason
      t.datetime :approved_at
      t.datetime :rejected_at
      t.text :additional_info

      t.timestamps
    end

    add_index :fingerprint_removal_requests, :device_hash
    add_index :fingerprint_removal_requests, :status
    add_index :fingerprint_removal_requests, :created_at
  end
end
