class PasswordResetsController < ApplicationController
  RATE_LIMIT_WINDOW = 60.seconds

  def request_otp
    email = params[:email]
    request_id = params[:request_id] || "default-#{Time.current.to_i}"

    user = find_user_by_email(email)

    if user
      email_cache_key = "password_reset_otp:#{email}"
      begin
        if RedisConnection.exists?(email_cache_key)
          render json: { message: 'OTP sent' }, status: :ok
          return
        end
        
        otp_record = PasswordOtp.generate_and_send_otp(user)
        
        if otp_record
          RedisConnection.setex(email_cache_key, RATE_LIMIT_WINDOW.to_i, '1')
        else
          Rails.logger.error "Failed to generate OTP record for #{email}"
        end
      rescue => e
        Rails.logger.error "Redis error during password reset OTP: #{e.message}"
        
        recent_otp = user.password_otps.where(otp_purpose: 'password_reset')
                              .where('otp_sent_at > ?', RATE_LIMIT_WINDOW.ago)
                              .order(created_at: :desc)
                              .first
        
        PasswordOtp.generate_and_send_otp(user) unless recent_otp
      end
      
      render json: { message: 'OTP sent' }, status: :ok
    else
      Rails.logger.info "Password reset requested for non-existent email: #{email}"
      render json: { message: 'OTP sent' }, status: :ok
    end
  end

  def verify_otp
    email = params[:email]
    otp = params[:otp]

    user = find_user_by_email(email)
    return render json: { error: 'User not found' }, status: :not_found unless user

    otp_record = user.password_otps.order(created_at: :desc).first

    if otp_record&.valid_otp?(otp)
      render json: { message: 'OTP verified successfully' }, status: :ok
    else
      render json: { error: 'Invalid or expired OTP' }, status: :unauthorized
    end
  end

  def reset_password
    email = params[:email]
    otp = params[:otp]
    new_password = params[:new_password]

    user = find_user_by_email(email)
    return render json: { error: 'User not found' }, status: :not_found unless user

    password_errors = validate_password_strength(new_password, user)
    if password_errors.any?
      return render json: { errors: password_errors }, status: :unprocessable_entity
    end

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
    normalized_email = email.to_s.strip.downcase
    Buyer.find_by('lower(email) = ?', normalized_email) ||
      Seller.find_by('lower(email) = ?', normalized_email) ||
      Admin.find_by('lower(email) = ?', normalized_email) ||
      SalesUser.find_by('lower(email) = ?', normalized_email) ||
      MarketingUser.find_by('lower(email) = ?', normalized_email)
  end

  def validate_password_strength(password, user)
    errors = []
    
    return ['Password is required'] if password.blank?
    
    if password.length < 8
      errors << 'Password must be at least 8 characters long'
    end
    
    common_passwords = %w[
      password 123456 123456789 qwerty abc123 password123 admin 12345678
      letmein welcome monkey dragon master hello login passw0rd 123123
      welcome123 1234567 12345 1234 111111 000000 1234567890
    ]
    
    if common_passwords.include?(password.downcase)
      errors << 'Password is too common. Please choose a more unique password.'
    end
    
    if password.match?(/(.)\1{3,}/)
      errors << 'Password contains too many repeated characters.'
    end
    
    if password.match?(/(0123456789|abcdefghijklmnopqrstuvwxyz|qwertyuiopasdfghjklzxcvbnm)/i)
      errors << 'Password contains sequential characters which are easy to guess.'
    end
    
    errors
  end
end
