# frozen_string_literal: true

# A researched business that is not yet on the platform, queued for a cold
# seller-recruitment email. Rows are imported from CSV via
# `rake prospect_outreach:import[path]` and drained by
# ProspectOutreachBatchJob on a daily schedule.
class OutreachProspect < ApplicationRecord
  STATUSES = %w[pending sent failed bounced skipped].freeze
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  before_validation :normalize_email

  validates :business_name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :email, format: { with: EMAIL_FORMAT, allow_blank: true }
  validates :email, uniqueness: { case_sensitive: false }, allow_nil: true

  scope :pending, -> { where(status: 'pending') }
  scope :emailable, -> { pending.where.not(email: nil).where.not(email: '') }

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end
end
