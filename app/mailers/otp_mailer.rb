class OtpMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  def send_otp
    @email = params[:email]
    @code = params[:code]
    @fullname = params[:fullname] || @email.split('@').first

    mail(to: @email, subject: 'Email Verification - Carbon Cube Kenya')
  end
end
