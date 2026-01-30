# frozen_string_literal: true

class CarbonCode < ApplicationRecord
  # Dynamic association: code can be linked to SalesUser (or later Admin, MarketingUser, etc.)
  belongs_to :associable, polymorphic: true
  has_many :sellers, dependent: :nullify

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :associable_type, presence: true
  validates :associable_id, presence: true
  validate :associable_type_allowed

  before_validation :normalize_code

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  # Check if code can still be used (active and under max_uses if set)
  def valid_for_use?
    return false if expires_at.present? && expires_at <= Time.current
    return true if max_uses.nil?
    times_used < max_uses
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def at_limit?
    max_uses.present? && times_used >= max_uses
  end

  private

  def normalize_code
    self.code = code.to_s.strip.upcase if code.present?
  end

  def associable_type_allowed
    return if associable_type.blank?
    allowed = %w[SalesUser]
    allowed << "Admin" if defined?(Admin)
    allowed << "MarketingUser" if defined?(MarketingUser)
    unless allowed.include?(associable_type)
      errors.add(:associable_type, "must be one of: #{allowed.join(', ')}")
    end
  end
end
