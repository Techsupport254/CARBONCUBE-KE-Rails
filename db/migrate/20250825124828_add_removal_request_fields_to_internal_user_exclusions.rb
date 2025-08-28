class AddRemovalRequestFieldsToInternalUserExclusions < ActiveRecord::Migration[7.0]
  def change
    # Add removal request fields to internal_user_exclusions table
    add_column :internal_user_exclusions, :requester_name, :string
    add_column :internal_user_exclusions, :device_description, :text
    add_column :internal_user_exclusions, :user_agent, :text
    add_column :internal_user_exclusions, :status, :string, default: 'pending'
    add_column :internal_user_exclusions, :rejection_reason, :text
    add_column :internal_user_exclusions, :approved_at, :datetime
    add_column :internal_user_exclusions, :rejected_at, :datetime
    add_column :internal_user_exclusions, :additional_info, :text
    
    # Add indexes for removal request fields
    add_index :internal_user_exclusions, :requester_name
    add_index :internal_user_exclusions, :status
    add_index :internal_user_exclusions, :approved_at
    add_index :internal_user_exclusions, :rejected_at
    
    # Drop the fingerprint_removal_requests table
    drop_table :fingerprint_removal_requests do |t|
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
  end
end
