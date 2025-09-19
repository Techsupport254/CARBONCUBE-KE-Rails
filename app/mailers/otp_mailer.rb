class OtpMailer < ApplicationMailer
  default from: ENV['BREVO_EMAIL']

  def send_otp
    @email = params[:email]
    @code = params[:code]

    mail(to: @email, subject: 'Email Verification - Carbon Cube Kenya')
  end
end
