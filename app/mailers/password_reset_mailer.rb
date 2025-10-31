#/app/mailers/password_reset_mailer.rb

class PasswordResetMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  def send_otp_email
    @user = params[:user]
    @otp = params[:otp]
    @user_type = params[:user_type]
    
    # Generate unique subject with timestamp to prevent threading
    timestamp = Time.current.strftime('%Y%m%d%H%M%S')
    unique_subject = "Password Reset Request #{timestamp} - Carbon Cube Kenya"
    
    mail_message = mail(
      to: @user.email,
      subject: unique_subject
    )
    
    # AGGRESSIVE threading prevention (same as SellerCommunicationsMailer)
    mail_message['In-Reply-To'] = nil
    mail_message['References'] = nil
    mail_message['Thread-Topic'] = nil
    mail_message['Thread-Index'] = nil
    
    # Force new conversation
    mail_message['X-Threading'] = 'false'
    mail_message['X-Conversation-ID'] = SecureRandom.uuid
    
    mail_message
  end
end
