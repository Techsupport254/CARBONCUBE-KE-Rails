class CreateCommentVotes < ActiveRecord::Migration[7.1]
  def change
    create_table :comment_votes do |t|
      t.bigint :comment_id, null: false
      t.string :author_type
      t.bigint :author_id
      t.integer :value, null: false

      t.timestamps
    end

    add_index :comment_votes, :comment_id
    add_index :comment_votes, %i[author_type author_id]
    add_foreign_key :comment_votes, :issue_comments, column: :comment_id
  end
end
