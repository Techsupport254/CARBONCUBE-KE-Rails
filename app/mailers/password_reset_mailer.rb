#/app/mailers/password_reset_mailer.rb

class PasswordResetMailer < ApplicationMailer
  default from: 'noreply@carboncube-ke.com'

  def send_otp_email
    @user = params[:user]
    @otp = params[:otp]
    @user_type = params[:user_type]
    
    mail(to: @user.email, subject: 'Password Reset Request - Carbon Cube Kenya')
  end
end
