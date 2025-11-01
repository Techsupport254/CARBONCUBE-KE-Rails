# app/controllers/buyer/profiles_controller.rb
require 'fileutils'

class Buyer::ProfilesController < ApplicationController
  before_action :authenticate_buyer

  # GET /buyer/profile
  def show
    buyer_data = current_buyer.as_json
    buyer_data[:profile_completion_percentage] = current_buyer.profile_completion_percentage
    # Check if email is verified
    email_verified = EmailOtp.exists?(email: current_buyer.email, verified: true)
    buyer_data[:email_verified] = email_verified
    # Ensure timestamps are included
    buyer_data[:created_at] = current_buyer.created_at
    buyer_data[:updated_at] = current_buyer.updated_at
    render json: buyer_data
  end

  # PATCH/PUT /buyer/profile
  def update
    begin
      Rails.logger.info "Received params: #{params.inspect}"
      
      uploaded_profile_picture_url = nil
      
      # Handle profile picture upload if present
      if params[:profile_picture].present?
        pic = params[:profile_picture]
        
        # Check if it's actually a file object
        unless pic.respond_to?(:original_filename)
          Rails.logger.error "Profile picture is not a file object: #{pic.class}"
          return render json: { error: "Invalid file format" }, status: :unprocessable_entity
        end
        
        Rails.logger.info "📸 Processing profile picture: #{pic.original_filename}"

        uploaded_profile_picture_url = handle_upload(
          file: pic,
          type: :profile_picture,
          max_size: 2.megabytes,
          accepted_types: ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'],
          processing_method: :process_and_upload_profile_picture
        )

        if uploaded_profile_picture_url.nil?
          Rails.logger.error "Profile picture upload failed"
          return render json: { error: "Failed to upload profile picture" }, status: :unprocessable_entity
        end

        Rails.logger.info "Profile picture uploaded successfully: #{uploaded_profile_picture_url}"
      end

      # Only update fields that are provided and valid
      update_params = buyer_params.reject { |k, v| v.blank? }
      
      # Remove any unexpected fields that might cause issues
      unexpected_fields = ['created_at', 'updated_at', 'id']
      unexpected_fields.each { |field| update_params.delete(field) }
      
      # Additional filtering for empty strings and null values
      update_params = update_params.reject { |k, v| v.nil? || v.to_s.strip.empty? }
      
      Rails.logger.info "Update params after filtering: #{update_params.inspect}"
      
      # Add the uploaded URL if available
      update_params[:profile_picture] = uploaded_profile_picture_url if uploaded_profile_picture_url
      
      if current_buyer.update(update_params)
        buyer_data = current_buyer.as_json
        buyer_data[:profile_completion_percentage] = current_buyer.profile_completion_percentage
        # Check if email is verified
        email_verified = EmailOtp.exists?(email: current_buyer.email, verified: true)
        buyer_data[:email_verified] = email_verified
        # Ensure timestamps are included
        buyer_data[:created_at] = current_buyer.created_at
        buyer_data[:updated_at] = current_buyer.updated_at
        render json: buyer_data
      else
        Rails.logger.error "Update failed: #{current_buyer.errors.full_messages}"
        render json: current_buyer.errors, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Unexpected error in update: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: "An unexpected error occurred" }, status: :internal_server_error
    end
  end

  # POST /buyer/change-password
  def change_password
    # Check if the current password is correct
    if current_buyer.authenticate(params[:currentPassword])
      # Check if new password matches confirmation
      if params[:newPassword] == params[:confirmPassword]
        # Update the password
        if current_buyer.update(password: params[:newPassword])
          # Password changed successfully - session should be cleared on frontend
          # Return response indicating session invalidation
          render json: { 
            message: 'Password updated successfully',
            session_invalidated: true
          }, status: :ok
        else
          render json: { errors: current_buyer.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { error: 'New password and confirmation do not match' }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Current password is incorrect' }, status: :unauthorized
    end
  end

  # POST /buyer/profile/request-verification
  def request_verification
    email = current_buyer.email
    fullname = current_buyer.fullname
    otp_code = rand.to_s[2..7] # 6-digit code
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
      Rails.logger.info "✅ Verification OTP email sent successfully to #{email}"
    rescue => e
      Rails.logger.error "❌ Failed to send verification OTP email: #{e.message}"
      # Don't fail the request if email fails
    end

    response = { message: "Verification code sent to your email" }
    render json: response, status: :ok
  end

  # POST /buyer/profile/verify-email
  def verify_email
    email = current_buyer.email
    otp_code = params[:otp_code]

    record = EmailOtp.find_by(email: email, otp_code: otp_code)

    if record.nil?
      render json: { verified: false, error: "Invalid verification code" }, status: :unprocessable_entity
    elsif record.verified == true
      render json: { verified: false, error: "This code has already been used" }, status: :unprocessable_entity
    elsif record.expires_at.present? && record.expires_at <= Time.now
      render json: { verified: false, error: "Verification code has expired" }, status: :unprocessable_entity
    else
      record.update!(verified: true)
      render json: { verified: true, message: "Email verified successfully" }, status: :ok
    end
  end
  

  private

  def authenticate_buyer
    @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Buyer)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_buyer
    @current_user
  end

  # Updated buyer_params to permit top-level parameters
  def buyer_params
    params.permit(:fullname, :username, :phone_number, :email, :location, :zipcode, :gender, :city, 
                  :county_id, :sub_county_id, :age_group_id, :income_id, :employment_id, 
                  :education_id, :sector_id)
  end

  # DRY Upload Handler
  def handle_upload(file:, type:, max_size:, accepted_types:, processing_method:)
    raise "#{type.to_s.humanize} is too large" if file.size > max_size
    unless accepted_types.include?(file.content_type)
      raise "#{type.to_s.humanize} must be one of: #{accepted_types.join(', ')}"
    end
    send(processing_method, file)
  rescue => e
    Rails.logger.error "Upload failed (#{type}): #{e.message}"
    nil
  end

  # Profile Picture Upload (direct upload, no processing)
  def process_and_upload_profile_picture(image)
    begin
      # Upload directly to Cloudinary without any processing
      uploaded = Cloudinary::Uploader.upload(image.tempfile.path,
        upload_preset: ENV['UPLOAD_PRESET'],
        folder: "buyer_profile_pictures",
        transformation: [
          { width: 400, height: 400, crop: "fill", gravity: "face" },
          { quality: "auto", fetch_format: "auto" }
        ]
      )
      uploaded["secure_url"]
    rescue => e
      Rails.logger.error "Error uploading profile picture: #{e.message}"
      nil
    end
  end
end
