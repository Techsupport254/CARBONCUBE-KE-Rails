# app/models/password_otp.rb
class PasswordOtp < ApplicationRecord
  belongs_to :otpable, polymorphic: true

  OTP_VALIDITY_DURATION = 10.minutes

  def self.generate_and_send_otp(user)
    otp = rand(100000..999999).to_s
    otp_digest = BCrypt::Password.create(otp)

    # Use first_or_initialize to either reuse or create new OTP record
    otp_record = PasswordOtp.where(otpable: user, otp_purpose: 'password_reset').first_or_initialize
    
    begin
      otp_record.update!(otp_digest: otp_digest, otp_sent_at: Time.current)
      Rails.logger.info "✅ OTP record created/updated for #{user.email}"
    rescue => e
      Rails.logger.error "❌ Failed to save OTP record: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e # Re-raise to prevent sending email without saved OTP
    end

    # Trigger mailer here, passing raw OTP for email content
    # Send immediately for password reset emails (critical functionality)
    begin
      mailer = PasswordResetMailer.with(user: user, otp: otp, user_type: user.class.name).send_otp_email

      # Send immediately - password reset is critical and should not be queued
      # Force synchronous delivery by bypassing ActiveJob
      mailer.delivery_method = :smtp
      mailer.delivery_method.settings = ActionMailer::Base.smtp_settings
      mailer.deliver_now!
      Rails.logger.info "✅ Password reset OTP email sent immediately to #{user.email}"

      if Rails.env.development?
        puts "✅ Password reset OTP email sent immediately to #{user.email} - OTP: #{otp}"
      end
    rescue => e
      Rails.logger.error "❌ Failed to send password reset email to #{user.email}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Log the OTP for debugging (only in development)
      if Rails.env.development?
        Rails.logger.error "DEBUG: OTP that failed to send: #{otp}"
        puts "DEBUG: OTP that failed to send: #{otp}"
      end
      # Don't fail the request if email fails - still return the record so user can retry
    end

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
