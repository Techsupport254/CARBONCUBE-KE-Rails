class DataDeletionRequest < ApplicationRecord
  validates :full_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :account_type, presence: true, inclusion: { in: %w[buyer seller] }
  validates :token, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[pending verified completed rejected] }
  
  before_validation :generate_token, on: :create
  before_validation :set_default_status, on: :create
  
  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :rejected, -> { where(status: 'rejected') }
  
  def self.find_by_email(email)
    where(email: email.downcase.strip)
  end
  
  def self.find_by_token(token)
    find_by(token: token)
  end
  
  def pending?
    status == 'pending'
  end
  
  def completed?
    status == 'completed'
  end
  
  def rejected?
    status == 'rejected'
  end
  
  def verified?
    status == 'verified'
  end
  
  def mark_as_verified!
    update!(status: 'verified', verified_at: Time.current)
  end
  
  def mark_as_completed!
    update!(status: 'completed', processed_at: Time.current)
  end
  
  def mark_as_rejected!(reason = nil)
    update!(status: 'rejected', processed_at: Time.current, rejection_reason: reason)
  end
  
  def processing_time
    return nil unless processed_at && requested_at
    processed_at - requested_at
  end
  
  def days_since_requested
    return nil unless requested_at
    (Time.current - requested_at) / 1.day
  end
  
  private
  
  def generate_token
    self.token = SecureRandom.hex(16) if token.blank?
  end
  
  def set_default_status
    self.status = 'pending' if status.blank?
  end
end
