class AddParentIdToIssueComments < ActiveRecord::Migration[7.1]
  def change
    add_column :issue_comments, :parent_id, :bigint
    add_index :issue_comments, :parent_id
    add_foreign_key :issue_comments, :issue_comments, column: :parent_id
  end
end
