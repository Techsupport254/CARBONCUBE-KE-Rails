class OtpMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  def send_otp
    email = params[:email]
    fullname = params[:fullname] || email.split('@').first

    mail(
      to: email,
      subject: 'Email Verification - Carbon Cube Kenya',
      react: {
        email: email,
        code: params[:code],
        fullname: fullname
      }
    )
  end
end
