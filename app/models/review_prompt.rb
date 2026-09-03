# frozen_string_literal: true

class ReviewPrompt < ApplicationRecord
  STATUSES = %w[pending sent opened completed dismissed].freeze
  CHANNELS = %w[email push].freeze
  MAX_SENDS = 3

  belongs_to :buyer, optional: true
  belongs_to :seller, optional: true
  belongs_to :ad
  belongs_to :click_event, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :channel, inclusion: { in: CHANNELS }
  validates :buyer_id, uniqueness: { scope: :ad_id }, if: -> { buyer_id? }
  validates :seller_id, uniqueness: { scope: :ad_id }, if: -> { seller_id? }
  validate :reviewer_present
  validate :not_if_already_reviewed, on: :create

  scope :ready, lambda {
    where('status = ? OR (status = ? AND reminders_count < ?)', 'pending', 'sent', MAX_SENDS)
      .where('scheduled_at <= ?', Time.current)
  }
  scope :for_user, lambda { |user|
    user.is_a?(Seller) ? where(seller: user) : where(buyer: user)
  }
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

  def reviewer_present
    return if buyer_id? || seller_id?

    errors.add(:base, 'Review prompt must have a buyer or a seller')
  end

  def not_if_already_reviewed
    return unless ad_id?

    if buyer_id? && Review.exists?(buyer_id: buyer_id, ad_id: ad_id)
      errors.add(:ad_id, 'already reviewed by this buyer')
    elsif seller_id? && Review.exists?(seller_id: seller_id, ad_id: ad_id)
      errors.add(:ad_id, 'already reviewed by this seller')
    end
  end
end
