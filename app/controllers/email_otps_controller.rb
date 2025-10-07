# app/controllers/email_otps_controller.rb
class EmailOtpsController < ApplicationController
  def create
    email = params[:email]
    fullname = params[:fullname]
    otp_code = rand.to_s[2..7] # 6-digit code
    expires_at = 10.minutes.from_now

    EmailOtp.where(email: email).delete_all # remove old OTPs

    EmailOtp.create!(email: email, otp_code: otp_code, expires_at: expires_at)

    # Send email (you can use ActionMailer or external provider)
    OtpMailer.with(email: email, code: otp_code, fullname: fullname).send_otp.deliver_now

    render json: { message: "OTP sent to #{email}" }, status: :ok
  end

  def verify
    email = params[:email]
    otp_code = params[:otp]

    record = EmailOtp.find_by(email: email, otp_code: otp_code)

    if record.nil?
      render json: { verified: false, error: "Invalid OTP" }, status: :unauthorized
    elsif record.verified?
      render json: { verified: false, error: "OTP has already been used" }, status: :unauthorized
    elsif record.expires_at <= Time.now
      render json: { verified: false, error: "OTP has expired" }, status: :unauthorized
    else
      record.update!(verified: true)
      render json: { verified: true }
    end
  end
end
