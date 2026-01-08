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

    # Send password reset email synchronously using direct SMTP
    # This bypasses ActionMailer's queuing system for critical functionality
    begin
      require 'net/smtp'
      require 'mail'

      # Create the email content manually
      subject = "Password Reset Request #{Time.current.strftime('%Y%m%d%H%M%S')} - Carbon Cube Kenya"
      body = <<-EMAIL
Dear #{user.fullname},

You requested a password reset for your Carbon Cube Kenya account.

Your OTP (One-Time Password) is: #{otp}

This OTP will expire in 10 minutes. Please use it to reset your password.

If you did not request this password reset, please ignore this email.

Best regards,
Carbon Cube Kenya Team
EMAIL

      # Create mail object
      mail = Mail.new do
        from    ENV['BREVO_EMAIL']
        to      user.email
        subject subject
        body    body
      end

      # Send via SMTP directly
      smtp_settings = {
        address: 'smtp-relay.brevo.com',
        port: 587,
        domain: 'carboncube-ke.com',
        user_name: ENV['BREVO_SMTP_USER'],
        password: ENV['BREVO_SMTP_PASSWORD'],
        authentication: :plain,
        enable_starttls_auto: true
      }

      Net::SMTP.start(smtp_settings[:address], smtp_settings[:port], smtp_settings[:domain],
                     smtp_settings[:user_name], smtp_settings[:password], smtp_settings[:authentication]) do |smtp|
        smtp.enable_starttls if smtp_settings[:enable_starttls_auto]
        smtp.send_message(mail.to_s, mail.from.first, mail.to)
      end

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
