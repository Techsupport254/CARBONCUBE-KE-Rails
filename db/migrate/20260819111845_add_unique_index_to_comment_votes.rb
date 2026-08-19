class AddUniqueIndexToCommentVotes < ActiveRecord::Migration[7.1]
  def change
    add_index :comment_votes,
              %i[comment_id author_type author_id],
              unique: true,
              where: 'author_id IS NOT NULL',
              name: 'index_comment_votes_on_comment_and_author'
  end
end
