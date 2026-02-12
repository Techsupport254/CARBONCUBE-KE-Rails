class Notification < ApplicationRecord
  belongs_to :recipient, polymorphic: true
  
  # notifiable is the object that triggered the notification (e.g., Message, Order, etc.)
  belongs_to :notifiable, polymorphic: true, optional: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def mark_as_read!
    update(read_at: Time.current)
  end

  def read?
    read_at.present?
  end
end
