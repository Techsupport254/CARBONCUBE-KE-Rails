class Admin::ProfilesController < ApplicationController
  before_action :authenticate_admin
  before_action :set_admin, only: [:show, :update, :request_verification, :verify_email]

  # GET /admin/profile
  def show
    admin_data = @admin.as_json
    admin_data[:role] = 'admin'
    admin_data[:has_password] = @admin.password_digest.present?
    admin_data[:email_verified] = email_verified?(@admin)
    render json: admin_data
  end

  # PATCH/PUT /admin/profile
  def update
    uploaded_profile_picture_url = process_and_upload_profile_picture
    return if performed?

    update_attrs = admin_params.to_h
    update_attrs[:profile_picture] = uploaded_profile_picture_url if uploaded_profile_picture_url

    if @admin.update(update_attrs)
      admin_data = @admin.as_json
      admin_data[:role] = 'admin'
      admin_data[:has_password] = @admin.password_digest.present?
      admin_data[:email_verified] = email_verified?(@admin)
      render json: admin_data
    else
      render json: @admin.errors, status: :unprocessable_entity
    end
  end

  # POST /admin/profile/change-password
  def change_password
    # For Google OAuth users without a password, skip current password check
    is_google_user_without_password = current_admin.provider == 'google' && current_admin.password_digest.blank?

    # If user has a password, require current password
    if current_admin.password_digest.present?
      unless params[:currentPassword].present? && current_admin.authenticate(params[:currentPassword])
        render json: { error: 'Current password is incorrect' }, status: :unauthorized
        return
      end
    end

    # Check if new password matches confirmation
    if params[:newPassword] == params[:confirmPassword]
      # Update the password
      if current_admin.update(password: params[:newPassword])
        # Password changed successfully - session should be cleared on frontend
        # Return response indicating session invalidation
        render json: {
          message: 'Password updated successfully',
          session_invalidated: true
        }, status: :ok
      else
        render json: { errors: current_admin.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: 'New password and confirmation do not match' }, status: :unprocessable_entity
    end
  end

  # POST /admin/profile/request-verification
  def request_verification
    email = @admin.email
    fullname = @admin.fullname

    # Google OAuth users are automatically verified and do not need an OTP
    if @admin.respond_to?(:provider) && @admin.provider.to_s.downcase == 'google'
      render json: { message: 'Email is already verified via Google.' }, status: :ok
      return
    end

    otp_code = rand.to_s[2..7]
    expires_at = 10.minutes.from_now

    # Remove old OTPs for this email
    EmailOtp.where(email: email).delete_all

    # Create new OTP
    EmailOtp.create!(
      email: email,
      otp_code: otp_code,
      expires_at: expires_at,
      verified: false
    )

    # Send email
    begin
      OtpMailer.with(email: email, code: otp_code, fullname: fullname).send_otp.deliver_now
    rescue => e
      # Don't fail the request if email fails
      Rails.logger.warn "Failed to send verification email: #{e.message}"
    end

    render json: { message: 'Verification code sent to your email' }, status: :ok
  end

  # POST /admin/profile/verify-email
  def verify_email
    email = @admin.email

    # Google OAuth users are automatically verified
    if @admin.respond_to?(:provider) && @admin.provider.to_s.downcase == 'google'
      render json: { verified: true, message: 'Email is already verified via Google' }, status: :ok
      return
    end

    otp_code = params[:otp_code]

    record = EmailOtp.find_by(email: email, otp_code: otp_code)

    if record.nil?
      render json: { verified: false, error: 'Invalid verification code' }, status: :unprocessable_entity
    elsif record.verified == true
      render json: { verified: false, error: 'This code has already been used' }, status: :unprocessable_entity
    elsif record.expires_at.present? && record.expires_at <= Time.now
      render json: { verified: false, error: 'Verification code has expired' }, status: :unprocessable_entity
    else
      record.update!(verified: true)
      render json: { verified: true, message: 'Email verified successfully' }, status: :ok
    end
  end

  private

  def set_admin
    @admin = current_admin
  end

  def admin_params
    params.permit(:fullname, :username, :email, :phone_number, :location, :city, :zipcode,
                  :county_id, :sub_county_id, :profile_picture)
  end

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_admin
    @current_user
  end

  def email_verified?(admin)
    return true if admin.respond_to?(:provider) && admin.provider.to_s.downcase == 'google'

    EmailOtp.exists?(email: admin.email, verified: true)
  end

  def process_and_upload_profile_picture
    pic = params[:profile_picture]
    return nil if pic.blank?

    unless pic.respond_to?(:original_filename)
      render json: { error: 'Invalid file format' }, status: :unprocessable_entity
      return nil
    end

    uploaded = Cloudinary::Uploader.upload(
      pic.tempfile.path,
      upload_preset: ENV['UPLOAD_PRESET'],
      folder: 'admin_profile_pictures',
      transformation: [
        { width: 400, height: 400, crop: 'fill', gravity: 'face' },
        { quality: 'auto', fetch_format: 'auto' }
      ]
    )
    uploaded['secure_url']
  rescue => e
    Rails.logger.error "Error uploading admin profile picture: #{e.message}"
    render json: { error: 'Failed to upload profile picture' }, status: :unprocessable_entity
    nil
  end
end
