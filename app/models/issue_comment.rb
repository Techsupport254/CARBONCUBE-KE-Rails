class IssueComment < ApplicationRecord
  include ActionView::Helpers::DateHelper
  
  # Associations
  belongs_to :issue
  belongs_to :author, polymorphic: true, optional: true
  belongs_to :parent, class_name: 'IssueComment', optional: true, inverse_of: :replies
  has_many :replies, class_name: 'IssueComment', foreign_key: 'parent_id', dependent: :destroy, inverse_of: :parent
  has_many :comment_votes, dependent: :destroy, inverse_of: :comment

  # Validations
  validates :content, presence: true, length: { minimum: 1, maximum: 1000 }

  before_validation :set_anonymous_author, on: :create
  
  # Scopes
  scope :recent, -> { order(created_at: :asc) }
  scope :by_author, ->(author) { where(author: author) }
  
  # Callbacks
  after_create :send_comment_notification
  
  # Methods
  def author_name
    case author_type
    when 'Admin', 'Buyer', 'Seller', 'SalesUser', 'MarketingUser'
      resolved_display_name
    when 'Anonymous'
      'Anonymous'
    else
      'Anonymous'
    end
  end

  def author_role
    {
      'Admin' => 'Admin',
      'Buyer' => 'Buyer',
      'Seller' => 'Seller',
      'SalesUser' => 'Sales',
      'MarketingUser' => 'Marketing',
      'Anonymous' => 'Anonymous'
    }[author_type] || 'Anonymous'
  end
  
  def is_internal?
    author_type == 'Admin'
  end
  
  def time_ago
    time_ago_in_words(created_at)
  end
  
  private

  def resolved_display_name
    return 'Anonymous' if author.blank?

    name = author.fullname.presence ||
           (author.respond_to?(:enterprise_name) ? author.enterprise_name.presence : nil) ||
           author.email.presence

    name || author_type
  end

  def set_anonymous_author
    if author_id.blank? && author_type.blank?
      self.author_type = nil
      self.author_id = nil
    end
  end

  def send_comment_notification
    IssueMailer.with(comment: self).comment_added.deliver_later
  end
end
