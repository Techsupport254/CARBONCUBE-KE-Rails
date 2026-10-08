class EmailOtp < ApplicationRecord
  # Emails are stored/compared case-insensitively — Seller and Buyer
  # normalize email to lowercase on save, so OTP rows follow the same rule.
  normalizes :email, with: ->(e) { e.to_s.strip.downcase }

  # LOWER() comparison also matches rows written before normalization existed.
  scope :for_email, ->(email) { where('LOWER(TRIM(email)) = ?', email.to_s.strip.downcase) }

  # Minimum seconds between OTP sends to the same email — client timers are
  # bypassable, so senders enforce this server-side before creating a new row.
  RESEND_COOLDOWN = 60

  # Seconds until the given email may request another code (0 = allowed now).
  def self.resend_wait_seconds(email)
    last = for_email(email).order(created_at: :desc).first
    return 0 unless last

    (RESEND_COOLDOWN - (Time.current - last.created_at)).ceil.clamp(0, RESEND_COOLDOWN)
  end

  # Ensure verified defaults to false
  before_validation :set_default_verified, on: :create

  def verified?
    verified == true
  end

  private

  def set_default_verified
    self.verified = false if verified.nil?
  end
end
