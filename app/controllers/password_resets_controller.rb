class PasswordResetsController < ApplicationController
  def request_otp
    email = params[:email]
    user = find_user_by_email(email)

    if user
      PasswordOtp.generate_and_send_otp(user)
      render json: { message: 'OTP sent' }, status: :ok
    else
      render json: { error: 'Email not found' }, status: :not_found
    end
  end

  def verify_otp
    email = params[:email]
    otp = params[:otp]
    new_password = params[:new_password]

    user = find_user_by_email(email)
    return render json: { error: 'User not found' }, status: :not_found unless user

    # Validate password strength before proceeding
    password_errors = validate_password_strength(new_password, user)
    if password_errors.any?
      return render json: { errors: password_errors }, status: :unprocessable_entity
    end

    # Get the most recent OTP record
    otp_record = user.password_otps.order(created_at: :desc).first

    if otp_record&.valid_otp?(otp)
      user.password = new_password
      if user.save
        otp_record.clear_otp
        render json: { message: 'Password reset successful' }, status: :ok
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Invalid or expired OTP' }, status: :unauthorized
    end
  end

  private

  def find_user_by_email(email)
    Buyer.find_by(email: email) || Seller.find_by(email: email) || Admin.find_by(email: email)
  end

  def validate_password_strength(password, user)
    errors = []
    
    return ['Password is required'] if password.blank?
    
    # Check minimum length
    if password.length < 8
      errors << 'Password must be at least 8 characters long'
    end
    
    # Check against common passwords
    common_passwords = %w[
      password 123456 123456789 qwerty abc123 password123 admin 12345678
      letmein welcome monkey dragon master hello login passw0rd 123123
      welcome123 1234567 12345 1234 111111 000000 1234567890
    ]
    
    if common_passwords.include?(password.downcase)
      errors << 'Password is too common. Please choose a more unique password.'
    end
    
    # Check for repeated characters
    if password.match?(/(.)\1{3,}/)
      errors << 'Password contains too many repeated characters.'
    end
    
    # Check for sequential characters
    if password.match?(/(0123456789|abcdefghijklmnopqrstuvwxyz|qwertyuiopasdfghjklzxcvbnm)/i)
      errors << 'Password contains sequential characters which are easy to guess.'
    end
    
    # Check if password contains user's email or username
    if user.email.present? && password.downcase.include?(user.email.split('@').first.downcase)
      errors << 'Password should not contain your email address.'
    end
    
    if user.respond_to?(:username) && user.username.present? && password.downcase.include?(user.username.downcase)
      errors << 'Password should not contain your username.'
    end
    
    errors
  end
end
