class Sales::ProfilesController < ApplicationController
  before_action :authenticate_sales_user
  before_action :set_sales_user, only: [:show, :update, :request_verification, :verify_email]

  # GET /sales/profile
  def show
    sales_user_data = @sales_user.as_json
    sales_user_data[:role] = 'sales'
    sales_user_data[:has_password] = @sales_user.password_digest.present?
    sales_user_data[:email_verified] = email_verified?(@sales_user)
    render json: sales_user_data
  end

  # PATCH/PUT /sales/profile
  def update
    uploaded_profile_picture_url = process_and_upload_profile_picture
    return if performed?

    update_attrs = sales_user_params.to_h
    update_attrs[:profile_picture] = uploaded_profile_picture_url if uploaded_profile_picture_url

    if @sales_user.update(update_attrs)
      sales_user_data = @sales_user.as_json
      sales_user_data[:role] = 'sales'
      sales_user_data[:has_password] = @sales_user.password_digest.present?
      sales_user_data[:email_verified] = email_verified?(@sales_user)
      render json: sales_user_data
    else
      render json: @sales_user.errors, status: :unprocessable_entity
    end
  end

  # POST /sales/profile/change-password
  def change_password
    # For Google OAuth users without a password, skip current password check
    is_google_user_without_password = current_sales_user.provider == 'google' && current_sales_user.password_digest.blank?

    # If user has a password, require current password
    if current_sales_user.password_digest.present?
      unless params[:currentPassword].present? && current_sales_user.authenticate(params[:currentPassword])
        render json: { error: 'Current password is incorrect' }, status: :unauthorized
        return
      end
    end

    # Check if new password matches confirmation
    if params[:newPassword] == params[:confirmPassword]
      # Update the password
      if current_sales_user.update(password: params[:newPassword])
        # Password changed successfully - session should be cleared on frontend
        # Return response indicating session invalidation
        render json: {
          message: 'Password updated successfully',
          session_invalidated: true
        }, status: :ok
      else
        render json: { errors: current_sales_user.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: 'New password and confirmation do not match' }, status: :unprocessable_entity
    end
  end

  # POST /sales/profile/request-verification
  def request_verification
    email = @sales_user.email
    fullname = @sales_user.fullname

    # Google OAuth users are automatically verified and do not need an OTP
    if @sales_user.respond_to?(:provider) && @sales_user.provider.to_s.downcase == 'google'
      render json: { message: 'Email is already verified via Google.' }, status: :ok
      return
    end

    otp_code = SecureRandom.random_number(100_000..999_999).to_s
    expires_at = 10.minutes.from_now

    # Anti-spam cooldown — must run before delete_all wipes the previous row.
    wait = EmailOtp.resend_wait_seconds(email)
    if wait.positive?
      render json: { error: "Please wait #{wait}s before requesting another code.", retry_after: wait }, status: :too_many_requests
      return
    end

    EmailOtp.for_email(email).delete_all

    # Create new OTP
    EmailOtp.create!(
      email: email,
      otp_code: otp_code,
      expires_at: expires_at,
      verified: false
    )

    # Send email
    begin
      OtpMailer.with(email: email, code: otp_code, fullname: fullname).send_otp.deliver_later(queue: 'critical')
    rescue => e
      # Don't fail the request if email fails
      Rails.logger.warn "Failed to send verification email: #{e.message}"
    end

    render json: { message: 'Verification code sent to your email' }, status: :ok
  end

  # POST /sales/profile/verify-email
  def verify_email
    email = @sales_user.email

    # Google OAuth users are automatically verified
    if @sales_user.respond_to?(:provider) && @sales_user.provider.to_s.downcase == 'google'
      render json: { verified: true, message: 'Email is already verified via Google' }, status: :ok
      return
    end

    otp_code = params[:otp_code]

    record = EmailOtp.for_email(email).find_by(otp_code: otp_code.to_s.strip)

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

  def set_sales_user
    @sales_user = current_sales_user
  end

  def sales_user_params
    params.permit(:fullname, :email, :phone_number, :location, :city, :zipcode,
                  :county_id, :sub_county_id, :profile_picture)
  end

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_sales_user
    @current_sales_user
  end

  def email_verified?(sales_user)
    return true if sales_user.respond_to?(:provider) && sales_user.provider.to_s.downcase == 'google'

    EmailOtp.for_email(sales_user.email).exists?(verified: true)
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
      folder: 'sales_profile_pictures',
      transformation: [
        { width: 400, height: 400, crop: 'fill', gravity: 'face' },
        { quality: 'auto', fetch_format: 'auto' }
      ]
    )
    uploaded['secure_url']
  rescue => e
    Rails.logger.error "Error uploading sales profile picture: #{e.message}"
    render json: { error: 'Failed to upload profile picture' }, status: :unprocessable_entity
    nil
  end
end
