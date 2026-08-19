class ChangeCommentVoteAuthorIdToUuid < ActiveRecord::Migration[7.1]
  def up
    CommentVote.delete_all
    change_column :comment_votes, :author_id, :uuid, using: 'NULL'
  end

  def down
    change_column :comment_votes, :author_id, :bigint
  end
end
