# app/controllers/email_otps_controller.rb
class EmailOtpsController < ApplicationController
  def create
    email = params[:email]
    fullname = params[:fullname]
    otp_code = rand.to_s[2..7] # 6-digit code
    expires_at = 10.minutes.from_now

    EmailOtp.where(email: email).delete_all # remove old OTPs

    EmailOtp.create!(
      email: email, 
      otp_code: otp_code, 
      expires_at: expires_at,
      verified: false # Explicitly set to false
    )

    # Send email (you can use ActionMailer or external provider)
    begin
      mail = OtpMailer.with(email: email, code: otp_code, fullname: fullname).send_otp
      Rails.logger.info "Attempting to send OTP email to #{email}..."
      mail.deliver_now
      Rails.logger.info "✅ OTP email sent successfully to #{email}"
      Rails.logger.info "OTP Code: #{otp_code}"
    rescue => e
      Rails.logger.error "❌ Failed to send OTP email to #{email}: #{e.message}"
      Rails.logger.error "Error class: #{e.class}"
      Rails.logger.error "Error backtrace: #{e.backtrace.first(5).join('\n')}"
      # Don't fail the request if email fails - still return success
    end

    response = { message: "OTP sent to #{email}" }
    render json: response, status: :ok
  end

  def verify
    email = params[:email]
    otp_code = params[:otp]

    record = EmailOtp.find_by(email: email, otp_code: otp_code)

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
