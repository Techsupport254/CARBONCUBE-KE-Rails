class Issue < ApplicationRecord
  include ActionView::Helpers::DateHelper
  # Enums for status and priority
  enum status: { 
    pending: 'pending', 
    in_progress: 'in_progress', 
    completed: 'completed', 
    closed: 'closed',
    rejected: 'rejected'
  }
  
  enum priority: { 
    low: 'low', 
    medium: 'medium', 
    high: 'high', 
    urgent: 'urgent'
  }
  
  enum category: {
    bug: 'bug',
    feature_request: 'feature_request',
    improvement: 'improvement',
    security: 'security',
    performance: 'performance',
    ui_ux: 'ui_ux',
    other: 'other'
  }
  
  # Validations
  validates :title, presence: true, length: { minimum: 5, maximum: 200 }
  validates :description, presence: true, length: { minimum: 10, maximum: 2000 }
  validates :reporter_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :reporter_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :status, presence: true
  validates :priority, presence: true
  validates :category, presence: true
  validates :device_uuid, presence: true
  
  # Associations
  belongs_to :user, polymorphic: true, optional: true # Can be submitted by logged-in or anonymous users
  belongs_to :assigned_to, class_name: 'Admin', optional: true
  has_many :issue_comments, dependent: :destroy
  has_many :issue_attachments, dependent: :destroy
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_category, ->(category) { where(category: category) }
  scope :assigned_to_admin, ->(admin_id) { where(assigned_to_id: admin_id) }
  scope :public_visible, -> { where(public_visible: true) }
  scope :internal, -> { where.not(user_id: nil) } # Issues from logged-in users
  scope :external, -> { where(user_id: nil) } # Issues from anonymous users
  
  # Callbacks
  before_create :generate_issue_number
  after_create :send_confirmation_email
  after_update :send_status_update_email, if: :saved_change_to_status?
  
  # Methods
  def issue_number
    "CC-#{id.to_s.rjust(6, '0')}"
  end
  
  def status_badge_color
    case status
    when 'pending'
      'bg-yellow-100 text-yellow-800'
    when 'in_progress'
      'bg-blue-100 text-blue-800'
    when 'completed'
      'bg-green-100 text-green-800'
    when 'closed'
      'bg-gray-100 text-gray-800'
    when 'rejected'
      'bg-red-100 text-red-800'
    end
  end
  
  def priority_badge_color
    case priority
    when 'low'
      'bg-gray-100 text-gray-800'
    when 'medium'
      'bg-blue-100 text-blue-800'
    when 'high'
      'bg-orange-100 text-orange-800'
    when 'urgent'
      'bg-red-100 text-red-800'
    end
  end
  
  def category_badge_color
    case category
    when 'bug'
      'bg-red-100 text-red-800'
    when 'feature_request'
      'bg-green-100 text-green-800'
    when 'improvement'
      'bg-blue-100 text-blue-800'
    when 'security'
      'bg-purple-100 text-purple-800'
    when 'performance'
      'bg-yellow-100 text-yellow-800'
    when 'ui_ux'
      'bg-pink-100 text-pink-800'
    when 'other'
      'bg-gray-100 text-gray-800'
    end
  end
  
  def can_be_updated_by?(user)
    return true if user.is_a?(Admin)
    return false unless public_visible?
    # Users can only update their own issues if they're still pending
    reporter_email == user.email && pending?
  end
  
  def time_since_created
    time_ago_in_words(created_at)
  end
  
  def time_since_updated
    time_ago_in_words(updated_at)
  end
  
  # Helper methods for user tracking
  def internal_user?
    user_id.present?
  end

  def external_user?
    user_id.nil?
  end

  def user_role
    return 'anonymous' unless user
    return 'admin' if user.is_a?(Admin)
    return 'buyer' if user.is_a?(Buyer)
    return 'seller' if user.is_a?(Seller)
    'unknown'
  end

  def reporter_name
    return user.fullname if user
    read_attribute(:reporter_name)
  end

  def reporter_email
    return user.email if user
    read_attribute(:reporter_email)
  end
  
  private
  
  def generate_issue_number
    # This will be set after the record is created
  end
  
  def send_confirmation_email
    IssueMailer.with(issue: self).issue_created.deliver_now
  end

  def send_status_update_email
    IssueMailer.with(issue: self).status_updated.deliver_now
  end
end
