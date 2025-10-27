class IssueComment < ApplicationRecord
  include ActionView::Helpers::DateHelper
  
  # Associations
  belongs_to :issue
  belongs_to :author, polymorphic: true
  
  # Validations
  validates :content, presence: true, length: { minimum: 1, maximum: 1000 }
  validates :author_type, presence: true
  validates :author_id, presence: true
  
  # Scopes
  scope :recent, -> { order(created_at: :asc) }
  scope :by_author, ->(author) { where(author: author) }
  
  # Callbacks
  after_create :send_comment_notification
  
  # Methods
  def author_name
    case author_type
    when 'Admin'
      author.fullname || author.email
    when 'User'
      author.fullname || author.email
    else
      'Anonymous'
    end
  end
  
  def author_role
    case author_type
    when 'Admin'
      'Admin'
    when 'User'
      'User'
    else
      'Anonymous'
    end
  end
  
  def is_internal?
    author_type == 'Admin'
  end
  
  def time_ago
    time_ago_in_words(created_at)
  end
  
  private
  
  def send_comment_notification
    IssueMailer.comment_added(self).deliver_now
  end
end
