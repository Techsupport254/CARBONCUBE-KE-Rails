class ReviewRequest < ApplicationRecord
  belongs_to :seller
  belongs_to :reviewed_by, polymorphic: true, optional: true

  validates :status, inclusion: { in: ['pending', 'approved', 'rejected', 'in_review'] }
  
  scope :pending, -> { where(status: 'pending') }
  scope :recent, -> { order(requested_at: :desc) }

  before_create :set_requested_at

  private

  def set_requested_at
    self.requested_at ||= Time.current
  end
end
