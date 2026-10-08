# app/controllers/email_otps_controller.rb
class EmailOtpsController < ApplicationController
  def create
    email = params[:email]
    fullname = params[:fullname]
    otp_code = SecureRandom.random_number(100_000..999_999).to_s # 6-digit code
    expires_at = 10.minutes.from_now

    # Anti-spam cooldown — must run before delete_all wipes the previous row.
    wait = EmailOtp.resend_wait_seconds(email)
    if wait.positive?
      render json: { error: "Please wait #{wait}s before requesting another code.", retry_after: wait },
             status: :too_many_requests
      return
    end

    EmailOtp.for_email(email).delete_all # remove old OTPs

    EmailOtp.create!(
      email: email, 
      otp_code: otp_code, 
      expires_at: expires_at,
      verified: false # Explicitly set to false
    )

    # Send email (you can use ActionMailer or external provider)
    begin
      OtpMailer.with(email: email, code: otp_code, fullname: fullname).send_otp.deliver_later(queue: 'critical')
    rescue => e
      # Don't fail the request if email fails - still return success
    end

    # Surface the code in the server log only — never in the HTTP response.
    Rails.logger.info "[DEV] OTP for #{email}: #{otp_code}" if Rails.env.development?
    render json: { message: "OTP sent to #{email}" }, status: :ok
  end

  def verify
    email = params[:email]
    otp_code = params[:otp]

    record = EmailOtp.for_email(email).find_by(otp_code: otp_code.to_s.strip)

    if record.nil?
      render json: { verified: false, error: "Invalid OTP" }, status: :unauthorized
    elsif record.verified == true
      render json: { verified: false, error: "OTP has already been used" }, status: :unauthorized
    elsif record.expires_at.present? && record.expires_at <= Time.now
      render json: { verified: false, error: "OTP has expired" }, status: :unauthorized
    else
      record.update!(verified: true)
      render json: { verified: true }
    end
  end
end
