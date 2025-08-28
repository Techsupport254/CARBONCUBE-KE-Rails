#/app/mailers/password_reset_mailer.rb

class PasswordResetMailer < ApplicationMailer
  default from: ENV['BREVO_EMAIL']

  def send_otp_email
    @user = params[:user]
    @otp = params[:otp]
    @user_type = params[:user_type]
    
    mail(to: @user.email, subject: 'Your Password Reset OTP for CarbonCube-KE')
  end
end
