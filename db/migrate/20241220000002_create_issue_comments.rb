class CreateIssueComments < ActiveRecord::Migration[7.0]
  def change
    create_table :issue_comments do |t|
      t.references :issue, null: false, foreign_key: true
      t.text :content, null: false, limit: 1000
      t.references :author, null: false, polymorphic: true
      t.boolean :is_internal, default: false
      
      t.timestamps
    end
    
    add_index :issue_comments, :issue_id
    add_index :issue_comments, [:author_type, :author_id]
    add_index :issue_comments, :created_at
    add_index :issue_comments, :is_internal
  end
end
