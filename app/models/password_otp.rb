# app/models/password_otp.rb
class PasswordOtp < ApplicationRecord
  belongs_to :otpable, polymorphic: true

  OTP_VALIDITY_DURATION = 10.minutes

  def self.generate_and_send_otp(user)
    otp = rand(100000..999999).to_s
    otp_digest = BCrypt::Password.create(otp)

    # Use first_or_initialize to either reuse or create new OTP record
    otp_record = PasswordOtp.where(otpable: user, otp_purpose: 'password_reset').first_or_initialize
    otp_record.update!(otp_digest: otp_digest, otp_sent_at: Time.current)

    # Trigger mailer here, passing raw OTP for email content
    PasswordResetMailer.with(user: user, otp: otp, user_type: user.class.name).send_otp_email.deliver_later

    otp_record
  end

  def valid_otp?(otp)
    return false if otp_sent_at < OTP_VALIDITY_DURATION.ago

    BCrypt::Password.new(otp_digest).is_password?(otp)
  end

  def clear_otp
    destroy
  end
end
