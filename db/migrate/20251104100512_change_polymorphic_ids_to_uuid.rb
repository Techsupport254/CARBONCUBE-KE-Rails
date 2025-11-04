class ChangePolymorphicIdsToUuid < ActiveRecord::Migration[7.1]
  def up
    # Make columns nullable first to handle conversion
    change_column_null :password_otps, :otpable_id, true
    change_column_null :issue_comments, :author_id, true
    change_column_null :issue_attachments, :uploaded_by_id, true
    change_column_null :issues, :user_id, true
    
    # Remove any invalid records with ID = 0 (these are broken)
    execute "DELETE FROM password_otps WHERE otpable_id = 0"
    execute "DELETE FROM issue_comments WHERE author_id = 0"
    execute "DELETE FROM issue_attachments WHERE uploaded_by_id = 0"
    execute "DELETE FROM issues WHERE user_id = 0"
    
    # Change polymorphic ID columns from bigint to uuid
    # Note: These columns can reference Buyer, Seller, or Admin (all now UUIDs)
    change_column :password_otps, :otpable_id, :uuid, using: 'NULL', null: true
    change_column :issue_comments, :author_id, :uuid, using: 'NULL', null: true
    change_column :issue_attachments, :uploaded_by_id, :uuid, using: 'NULL', null: true
    change_column :issues, :user_id, :uuid, using: 'NULL', null: true
  end

  def down
    # Change back to bigint (losing UUID data)
    change_column :password_otps, :otpable_id, :bigint, using: '0'
    change_column :issue_comments, :author_id, :bigint, using: '0'
    change_column :issue_attachments, :uploaded_by_id, :bigint, using: '0'
    change_column :issues, :user_id, :bigint, using: '0', null: true
  end
end
