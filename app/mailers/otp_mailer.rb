class OtpMailer < ApplicationMailer
  default from: 'noreply@carboncube-ke.com'

  def send_otp
    @email = params[:email]
    @code = params[:code]

    mail(to: @email, subject: 'Email Verification - Carbon Cube Kenya')
  end
end
