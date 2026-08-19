class CommentVote < ApplicationRecord
  belongs_to :comment, class_name: 'IssueComment', inverse_of: :comment_votes
  belongs_to :author, polymorphic: true, optional: true

  validates :value, presence: true, inclusion: { in: [-1, 1] }
  validates :author_id, presence: true, if: -> { author_type.present? }
end
