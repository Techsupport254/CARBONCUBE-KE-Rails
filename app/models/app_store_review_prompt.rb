# frozen_string_literal: true

# Tracks whether a user should be shown the native App Store / Play Store
# review dialog inside the mobile app.
#
# One row per user (enforced by unique index on user_type/user_id).
# The backend controls when each user is eligible (scheduled_at), and the
# mobile app checks /app_store_review_prompt to know whether to show the dialog.
#
# Statuses:
#   pending  – prompt has been scheduled but not yet shown
#   shown    – the app reported the dialog was triggered (user may or may not have rated)
#   dismissed – manually suppressed via admin or after the user rated
class AppStoreReviewPrompt < ApplicationRecord
  STATUSES = %w[pending shown dismissed].freeze

  belongs_to :user, polymorphic: true

  validates :status, inclusion: { in: STATUSES }
  validates :scheduled_at, presence: true

  scope :ready, -> { where(status: 'pending').where('scheduled_at <= ?', Time.current) }

  def mark_shown!
    update!(status: 'shown', shown_at: Time.current)
  end

  def mark_dismissed!
    update!(status: 'dismissed')
  end
end
