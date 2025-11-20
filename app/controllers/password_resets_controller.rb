class PasswordResetsController < ApplicationController
  # Rate limiting: prevent duplicate requests within 60 seconds
  RATE_LIMIT_WINDOW = 60.seconds

  def request_otp
    email = params[:email]
    request_id = params[:request_id] || "default-#{Time.current.to_i}" # Fallback if not provided

    user = find_user_by_email(email)

    if user
      # Rate limiting: Check if we've recently sent an OTP for this email
      # Use email only (not request_id) to prevent spam regardless of request_id changes
      email_cache_key = "password_reset_otp:#{email}"
      
      # Use Redis directly for rate limiting (since Redis is already configured)
      begin
        if RedisConnection.exists?(email_cache_key)
          # Already sent an OTP for this email recently (within rate limit window)
          Rails.logger.info "Password reset OTP rate limited for #{email} (request_id: #{request_id})"
          render json: { message: 'OTP sent' }, status: :ok
          return
        end
        
        # Generate and send OTP
        Rails.logger.info "Generating and sending password reset OTP for #{email} (request_id: #{request_id})"
        otp_record = PasswordOtp.generate_and_send_otp(user)
        
        # Cache this email for 60 seconds to prevent duplicates
        # Only cache if OTP was successfully generated
        if otp_record
          RedisConnection.setex(email_cache_key, RATE_LIMIT_WINDOW.to_i, '1')
          Rails.logger.info "✅ Password reset OTP sent successfully to #{email}"
        else
          Rails.logger.error "❌ Failed to generate OTP record for #{email}"
        end
      rescue => e
        # If Redis fails, still try to send OTP but log the error
        Rails.logger.error "❌ Redis error during password reset OTP: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        # Only send OTP if we haven't already sent it (check if OTP record exists)
        recent_otp = user.password_otps.where(otp_purpose: 'password_reset')
                              .where('otp_sent_at > ?', RATE_LIMIT_WINDOW.ago)
                              .order(created_at: :desc)
                              .first
        
        unless recent_otp
          Rails.logger.info "Sending password reset OTP without Redis rate limiting for #{email}"
          PasswordOtp.generate_and_send_otp(user)
        else
          Rails.logger.info "Skipping OTP send - recent OTP exists for #{email}"
        end
      end
      
      render json: { message: 'OTP sent' }, status: :ok
    else
      # Don't reveal that email doesn't exist (security best practice)
      Rails.logger.info "Password reset requested for non-existent email: #{email}"
      render json: { message: 'OTP sent' }, status: :ok
    end
  end

  def verify_otp
    email = params[:email]
    otp = params[:otp]

    user = find_user_by_email(email)
    return render json: { error: 'User not found' }, status: :not_found unless user

    # Get the most recent OTP record
    otp_record = user.password_otps.order(created_at: :desc).first

    if otp_record&.valid_otp?(otp)
      # OTP is valid - just verify it, don't reset password yet
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
