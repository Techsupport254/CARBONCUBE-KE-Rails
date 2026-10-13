# frozen_string_literal: true

# Tracks the "install the app" email campaign for a single user.
#
# Lifecycle:
#   enrolled → (first send) → active → (installs app) → completed
#                                     → (MAX_SENDS reached) → exhausted
#                                     → (admin action)      → suppressed
#
# The job (SendAppInstallNudgeJob) is the only writer. It calls:
#   campaign.enqueue_send!        after scheduling each email
#   campaign.mark_completed!      when a DeviceToken is detected for the user
#   campaign.mark_exhausted!      when sends_count reaches MAX_SENDS
class AppInstallNudgeCampaign < ApplicationRecord
  # ── Schedule ────────────────────────────────────────────────────────────────
  # Total emails sent per user: 1 initial + 2 reminders = 3 max.
  MAX_SENDS = 3

  # Delay between sends. Index 0 = delay before first email (from enrollment),
  # index 1 = delay from first email to reminder 1,
  # index 2 = delay from reminder 1 to reminder 2 (final).
  SEND_DELAYS = [
    3.days,   # initial: 3 days after signup
    7.days,   # reminder 1: 7 days after initial
    14.days,  # reminder 2: 14 days after reminder 1
  ].freeze

  STATUSES = %w[enrolled active completed exhausted suppressed].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :user, polymorphic: true

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :status,      inclusion: { in: STATUSES }
  validates :sends_count, numericality: { greater_than_or_equal_to: 0 }
  validates :next_send_at, presence: true

  # ── Scopes ───────────────────────────────────────────────────────────────────

  # Campaigns ready to be processed right now: due for a send and not terminal.
  scope :ready_to_send, -> {
    where(status: %w[enrolled active])
      .where('next_send_at <= ?', Time.current)
  }

  # ── Class helpers ────────────────────────────────────────────────────────────

  # Build (but don't save) a campaign record for a newly enrolled user.
  # next_send_at is set so the first email fires SEND_DELAYS[0] from now.
  def self.build_for(user)
    new(
      user:        user,
      status:      'enrolled',
      sends_count: 0,
      next_send_at: Time.current + SEND_DELAYS[0]
    )
  end

  # ── Instance methods ─────────────────────────────────────────────────────────

  # Call after successfully dispatching an email. Advances sends_count and
  # schedules the next send, or marks exhausted if this was the last one.
  def record_send!
    new_count = sends_count + 1
    next_delay = SEND_DELAYS[new_count] # nil when there are no more delays

    if next_delay.nil? || new_count >= MAX_SENDS
      update!(
        status:       'exhausted',
        sends_count:  new_count,
        last_sent_at: Time.current,
        next_send_at: Time.current   # harmless; won't be queried again
      )
    else
      update!(
        status:       'active',
        sends_count:  new_count,
        last_sent_at: Time.current,
        next_send_at: Time.current + next_delay
      )
    end
  end

  # Call when we detect the user has installed the app (DeviceToken present).
  def mark_completed!
    update!(status: 'completed', completed_at: Time.current)
  end

  # Admin/manual suppression — stops all further emails for this user.
  def suppress!
    update!(status: 'suppressed')
  end

  # ── Predicates ───────────────────────────────────────────────────────────────
  def terminal?
    %w[completed exhausted suppressed].include?(status)
  end

  def first_send?
    sends_count.zero?
  end
end
