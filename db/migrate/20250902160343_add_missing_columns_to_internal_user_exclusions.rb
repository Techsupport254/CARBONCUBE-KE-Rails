class AddMissingColumnsToInternalUserExclusions < ActiveRecord::Migration[7.1]
  def change
    # Add removal request fields to internal_user_exclusions table (only if they don't exist)
    add_column :internal_user_exclusions, :requester_name, :string unless column_exists?(:internal_user_exclusions, :requester_name)
    add_column :internal_user_exclusions, :device_description, :text unless column_exists?(:internal_user_exclusions, :device_description)
    add_column :internal_user_exclusions, :user_agent, :text unless column_exists?(:internal_user_exclusions, :user_agent)
    add_column :internal_user_exclusions, :status, :string, default: 'pending' unless column_exists?(:internal_user_exclusions, :status)
    add_column :internal_user_exclusions, :rejection_reason, :text unless column_exists?(:internal_user_exclusions, :rejection_reason)
    add_column :internal_user_exclusions, :approved_at, :datetime unless column_exists?(:internal_user_exclusions, :approved_at)
    add_column :internal_user_exclusions, :rejected_at, :datetime unless column_exists?(:internal_user_exclusions, :rejected_at)
    add_column :internal_user_exclusions, :additional_info, :text unless column_exists?(:internal_user_exclusions, :additional_info)
    
    # Add indexes for removal request fields (only if they don't exist)
    add_index :internal_user_exclusions, :requester_name unless index_exists?(:internal_user_exclusions, :requester_name)
    add_index :internal_user_exclusions, :status unless index_exists?(:internal_user_exclusions, :status)
    add_index :internal_user_exclusions, :approved_at unless index_exists?(:internal_user_exclusions, :approved_at)
    add_index :internal_user_exclusions, :rejected_at unless index_exists?(:internal_user_exclusions, :rejected_at)
  end
end
