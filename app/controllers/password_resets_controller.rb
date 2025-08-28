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
end
