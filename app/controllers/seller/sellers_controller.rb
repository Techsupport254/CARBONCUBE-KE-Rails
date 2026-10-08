class Seller::SellersController < ApplicationController
  before_action :set_seller, only: [:show, :update]
  before_action :authenticate_seller, only: [:identify, :show, :update, :destroy]

  def identify
    render json: { seller_id: current_seller.id }
  end

  # GET /seller/profile
  def show
    render json: current_seller
  end

  # PATCH/PUT /seller/profile
  def update
    if current_seller.update(seller_params)
      render json: current_seller
    else
      render json: current_seller.errors, status: :unprocessable_entity
    end
  end

  # DELETE /seller/:id
  def destroy
    if current_seller.nil?
      render json: { error: 'Not Authorized' }, status: :unauthorized
      return
    end

    AppleAuthService.revoke_tokens_for(current_seller) if current_seller.provider == 'apple'

    if current_seller.destroy
      head :no_content
    else
      render json: { error: 'Failed to delete account' }, status: :unprocessable_entity
    end
  end

  # POST /seller/signup
  def create
    unless params[:seller].present? && params[:seller][:email].present?
      return render json: { errors: ['Seller email is required'] }, status: :unprocessable_entity
    end
    
    seller_email = params[:seller][:email].to_s.downcase.strip
    otp_code = params[:otp_code]

    # If OTP is not provided, just validate and return success (don't create account or send OTP yet)
    if otp_code.blank?
      if Buyer.exists?(email: seller_email)
        return render json: { errors: ['Email is already in use'] }, status: :unprocessable_entity
      end

      if Seller.exists?(email: seller_email)
        return render json: { errors: ['Email is already in use'] }, status: :unprocessable_entity
      end

      # Validate basic seller params
      if params[:seller][:fullname].blank? || params[:seller][:email].blank? || params[:seller][:password].blank?
        return render json: { errors: ['Fullname, email, and password are required'] }, status: :unprocessable_entity
      end

      return render json: {
        success: true,
        message: "Please request a verification code on the onboarding page to complete registration."
      }, status: :ok
    end

    # OTP is provided - verify and issue a pending registration token.
    # No account is created here: the seller record is only persisted inside
    # complete_onboarding's transaction, together with the first ad. If the
    # user abandons onboarding, nothing is left behind.
    if Buyer.exists?(email: seller_email)
      return render json: { errors: ['Email is already in use'] }, status: :unprocessable_entity
    end

    if Seller.exists?(email: seller_email)
      return render json: { errors: ['Email is already in use'] }, status: :unprocessable_entity
    end

    # Verify OTP
    otp_record = EmailOtp.for_email(seller_email).find_by(otp_code: otp_code.to_s.strip)

    if otp_record.nil?
      return render json: { errors: ['Invalid OTP'] }, status: :unauthorized
    elsif otp_record.verified == true
      return render json: { errors: ['OTP has already been used'] }, status: :unauthorized
    elsif otp_record.expires_at.present? && otp_record.expires_at <= Time.now
      return render json: { errors: ['OTP has expired'] }, status: :unauthorized
    end

    # Validate the password now — it is never validated later because only its
    # bcrypt digest is cached for the deferred Seller creation.
    password = params[:seller][:password].to_s
    password_confirmation = params[:seller][:password_confirmation].to_s
    if password.blank?
      return render json: { errors: ['Password is required'] }, status: :unprocessable_entity
    elsif password.length < 8
      return render json: { errors: ['Password must be at least 8 characters'] }, status: :unprocessable_entity
    elsif password != password_confirmation
      return render json: { errors: ['Passwords do not match'] }, status: :unprocessable_entity
    end

    # Handle carbon code (validated now, applied when the seller is created)
    carbon_code = nil
    if params[:carbon_code].present?
      carbon_code = CarbonCode.find_by("UPPER(TRIM(code)) = ?", params[:carbon_code].to_s.strip.upcase)
      if carbon_code.nil?
        return render json: { errors: { carbon_code: ["Carbon code is invalid."] } }, status: :unprocessable_entity
      end
      unless carbon_code.valid_for_use?
        msg = carbon_code.expired? ? "This Carbon code has expired." : "This Carbon code has reached its usage limit."
        return render json: { errors: { carbon_code: [msg] } }, status: :unprocessable_entity
      end
    end

    # Handle document upload
    uploaded_document_url = nil
    if params[:seller][:document_url].present?
      doc = params[:seller][:document_url]
      if doc.content_type == "application/pdf"
        uploaded_document_url = upload_file_only(doc)
      else
        uploaded_document_url = handle_upload(
          file: doc,
          type: :document,
          max_size: 5.megabytes,
          accepted_types: ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'],
          processing_method: :process_and_upload_permit
        )
      end

      if uploaded_document_url.nil?
        return render json: { error: "Failed to upload document" }, status: :unprocessable_entity
      end
    end

    # Handle profile picture upload
    uploaded_profile_picture_url = nil
    if params[:seller][:profile_picture].present?
      pic = params[:seller][:profile_picture]
      uploaded_profile_picture_url = handle_upload(
        file: pic,
        type: :profile_picture,
        max_size: 2.megabytes,
        accepted_types: ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'],
        processing_method: :process_and_upload_profile_picture
      )

      if uploaded_profile_picture_url.nil?
        return render json: { error: "Failed to upload profile picture" }, status: :unprocessable_entity
      end
    end

    # OTP is consumed now — the pending token becomes the credential.
    otp_record.update!(verified: true)

    # Stash the signup under a pending token (same deferred-registration
    # mechanism as Google OAuth). The raw password is never stored — only its
    # bcrypt digest.
    pending_token = SecureRandom.hex(32)
    cache_key = "pending_seller_registration_#{pending_token}"
    pending_data = {
      role: 'seller',
      provider: nil,
      name: params[:seller][:fullname],
      email: seller_email,
      username: params[:seller][:username],
      phone_number: params[:seller][:phone_number],
      secondary_phone_number: params[:seller][:secondary_phone_number],
      password_digest: BCrypt::Password.create(password).to_s,
      carbon_code_id: carbon_code&.id,
      document_url: uploaded_document_url,
      picture: uploaded_profile_picture_url,
      device_hash: params[:device_hash],
      created_at: Time.current.to_s
    }
    Rails.cache.write(cache_key, pending_data, expires_in: 1.hour)

    render json: {
      success: true,
      pending_registration: true,
      pending_token: pending_token,
      email: seller_email,
      name: pending_data[:name],
      phone_number: pending_data[:phone_number],
      message: "Pending registration - complete onboarding to create your account."
    }, status: :ok
  rescue => e
    render json: { errors: ["An error occurred during registration"] }, status: :internal_server_error
  end


  private

  def set_seller
    @seller = Seller.find_by(slug: params[:id]) || Seller.find(params[:id])
  end

  def seller_params
    params.require(:seller).permit(
      :fullname, :phone_number, :secondary_phone_number, :email, :enterprise_name, :location, :password, :password_confirmation,
      :username, :age_group_id, :zipcode, :city, :gender, :description, :business_registration_number,
      :document_url, :document_type_id, :document_expiry_date, :document_verified,
      :county_id, :sub_county_id, :profile_picture, category_ids: []
    )
  end

  def process_and_upload_ad_images(images)
    uploaded_urls = []

    begin
      Array(images).each do |image|
        begin
          # Check if tempfile exists and is readable
          unless image.tempfile && File.exist?(image.tempfile.path)
            next
          end

          # Check Cloudinary configuration
          unless ENV['UPLOAD_PRESET'].present?
            raise "UPLOAD_PRESET not configured"
          end

          # Upload original image directly to Cloudinary without any processing
          uploaded_image = Cloudinary::Uploader.upload(
            image.tempfile.path,
            upload_preset: ENV['UPLOAD_PRESET'],
            format: nil,               # Keep original format
            background: "transparent"  # Ensure no colored background is added
          )

          uploaded_urls << uploaded_image["secure_url"]
        rescue => e
          # Don't fail completely, just skip this image
        end
      end
    rescue => e
      raise e # Re-raise to be caught by the calling method
    end

    uploaded_urls
  end

  def authenticate_seller
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result

    if @current_seller.nil?
      render json: { error: 'Not Authorized' }, status: :unauthorized
    elsif @current_seller.deleted?
      render json: { error: 'Account has been deleted' }, status: :unauthorized
    end
  end

  def current_seller
    @current_seller
  end

  # DRY Upload Handler
  def handle_upload(file:, type:, max_size:, accepted_types:, processing_method:)
    raise "#{type.to_s.humanize} is too large" if file.size > max_size
    unless accepted_types.include?(file.content_type)
      raise "#{type.to_s.humanize} must be one of: #{accepted_types.join(', ')}"
    end
    send(processing_method, file)
  rescue => e
    nil
  end

  # Permit Upload (direct to Cloudinary)
  def process_and_upload_permit(image)
    begin
      uploaded = Cloudinary::Uploader.upload(image.tempfile.path,
        upload_preset: ENV['UPLOAD_PRESET'],
        folder: "business_permits",
        transformation: [
          { width: 1080, crop: "limit" },
          { quality: "auto", fetch_format: "auto" }
        ]
      )
      uploaded["secure_url"]
    rescue => e
      nil
    end
  end

  # Profile Picture Upload (direct to Cloudinary)
  def process_and_upload_profile_picture(image)
    begin
      uploaded = Cloudinary::Uploader.upload(image.tempfile.path,
        upload_preset: ENV['UPLOAD_PRESET'],
        folder: "profile_pictures",
        transformation: [
          { width: 400, height: 400, crop: "fill", gravity: "face" },
          { quality: "auto", fetch_format: "auto" }
        ]
      )
      uploaded["secure_url"]
    rescue => e
      nil
    end
  end


  # Upload PDF file as an image resource so Cloudinary can extract pages for previews.
  def upload_file_only(file)
    uploaded = Cloudinary::Uploader.upload(file.tempfile.path, resource_type: "image", upload_preset: ENV['UPLOAD_PRESET'], folder: "business_permits")
    uploaded["secure_url"]
  end

end