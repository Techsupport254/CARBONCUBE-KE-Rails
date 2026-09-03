# frozen_string_literal: true

class ReviewPrompt < ApplicationRecord
  STATUSES = %w[pending sent opened completed dismissed].freeze
  CHANNELS = %w[email push].freeze
  MAX_SENDS = 3

  belongs_to :buyer
  belongs_to :ad
  belongs_to :click_event, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :channel, inclusion: { in: CHANNELS }
  validates :buyer_id, uniqueness: { scope: :ad_id }
  validate :not_if_already_reviewed, on: :create

  scope :ready, lambda {
    where('status = ? OR (status = ? AND reminders_count < ?)', 'pending', 'sent', MAX_SENDS)
      .where('scheduled_at <= ?', Time.current)
  }
  scope :for_buyer, ->(buyer) { where(buyer:) }
  scope :not_dismissed_or_completed, -> { where.not(status: %w[completed dismissed]) }

  def mark_sent!(next_scheduled_at: nil)
    new_count = reminders_count + 1
    update!(
      status: 'sent',
      sent_at: Time.current,
      reminders_count: new_count,
      scheduled_at: next_scheduled_at
    )
  end

  def mark_completed!
    update!(status: 'completed', completed_at: Time.current)
  end

  def mark_dismissed!
    update!(status: 'dismissed')
  end

  def sent?
    status == 'sent'
  end

  def completed?
    status == 'completed'
  end

  private

  def not_if_already_reviewed
    return unless buyer_id? && ad_id?

    already_exists = Review.exists?(buyer_id: buyer_id, ad_id: ad_id)
    errors.add(:ad_id, 'already reviewed by this buyer') if already_exists
  end
end
