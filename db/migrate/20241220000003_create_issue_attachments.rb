class CreateIssueAttachments < ActiveRecord::Migration[7.0]
  def change
    create_table :issue_attachments do |t|
      t.references :issue, null: false, foreign_key: true
      t.string :file_name, null: false
      t.integer :file_size, null: false
      t.string :file_type, null: false
      t.string :file_url, null: false
      t.references :uploaded_by, null: false, polymorphic: true
      
      t.timestamps
    end
    
    # add_index :issue_attachments, :issue_id  # Already created by references
    add_index :issue_attachments, [:uploaded_by_type, :uploaded_by_id]
    add_index :issue_attachments, :file_type
    add_index :issue_attachments, :created_at
  end
end
