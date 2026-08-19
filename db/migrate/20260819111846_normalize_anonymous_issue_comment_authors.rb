class NormalizeAnonymousIssueCommentAuthors < ActiveRecord::Migration[7.1]
  def up
    change_table :issue_comments, bulk: true do |t|
      t.change_null :author_type, true
      t.change_null :author_id, true
    end

    IssueComment.where(author_type: 'Anonymous').update_all(author_type: nil, author_id: nil)
  end

  def down
    # Intentionally left blank.
  end
end
