# frozen_string_literal: true

class SellerFollowUp < ApplicationRecord
  belongs_to :seller
  belongs_to :seller_verification, optional: true
  belongs_to :sales_user, optional: true

  # A follow-up touchpoint or issue logged against a shop during or after a
  # field verification. Issues stay 'open' until resolved so they surface on
  # the due-follow-up list instead of getting lost in visit notes.
  enum :follow_up_type, {
    note: 0,
    call: 1,
    visit: 2,
    whatsapp: 3,
    email: 4,
    issue: 5
  }, default: :note, scopes: false

  STATUSES = %w[open resolved].freeze

  validates :occurred_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :notes, presence: true, if: -> { issue? || note? }

  before_save :stamp_resolved_at

  scope :recent_first, -> { order(occurred_at: :desc, created_at: :desc) }
  scope :open, -> { where(status: 'open') }
  scope :resolved, -> { where(status: 'resolved') }
  scope :overdue, -> { open.where('follow_up_date < ?', Date.current) }
  scope :due_today, -> { open.where(follow_up_date: Date.current) }
  scope :upcoming, -> { open.where('follow_up_date > ?', Date.current) }
  scope :issues, -> { where(follow_up_type: follow_up_types[:issue]) }

  def resolved?
    status == 'resolved'
  end

  def resolve!
    update!(status: 'resolved')
  end

  def reopen!
    update!(status: 'open')
  end

  private

  def stamp_resolved_at
    if status_changed?
      self.resolved_at = resolved? ? (resolved_at || Time.current) : nil
    end
  end
end
