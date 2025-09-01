class OtpMailer < ApplicationMailer
  default from: ENV['BREVO_EMAIL']  # update as needed

  def send_otp
    @email = params[:email]
    @code = params[:code]

    mail(to: @email, subject: 'Your OTP Code for CarbonCube-KE')
  end
end
