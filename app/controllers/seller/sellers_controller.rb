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

    if current_seller.update(deleted: true)
      head :no_content
    else
      render json: { error: 'Failed to delete account' }, status: :unprocessable_entity
    end
  end

  # POST /seller/signup
  def create
    seller_email = params[:seller][:email].downcase.strip
    otp_code = params[:otp]
    
    # Rails.logger.info "🔍 Checking if buyer exists with email: #{seller_email}"

    if Buyer.exists?(email: seller_email)
      Rails.logger.error "Email already used by buyer: #{seller_email}"
      return render json: { errors: ['Email is already in use by a buyer'] }, status: :unprocessable_entity
    end

    # Verify OTP if provided (but don't mark as verified yet)
    if otp_code.present?
      otp_record = EmailOtp.find_by(email: seller_email, otp_code: otp_code)
      
      if otp_record.nil?
        Rails.logger.error "Invalid OTP for email: #{seller_email}"
        return render json: { errors: ['Invalid OTP'] }, status: :unauthorized
      elsif otp_record.verified?
        Rails.logger.error "OTP already used for email: #{seller_email}"
        return render json: { errors: ['OTP has already been used'] }, status: :unauthorized
      elsif otp_record.expires_at <= Time.now
        Rails.logger.error "OTP expired for email: #{seller_email}"
        return render json: { errors: ['OTP has expired'] }, status: :unauthorized
      end
      # Don't mark as verified yet - wait until seller is successfully saved
    end

    uploaded_document_url = nil
    uploaded_profile_picture_url = nil

    if params[:seller][:document_url].present?
      doc = params[:seller][:document_url]
      # Rails.logger.info "📤 Processing business document: #{doc.original_filename}"

      if doc.content_type == "application/pdf"
        # Rails.logger.info "📄 PDF detected. Skipping image processing."
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
        Rails.logger.error "Document upload failed"
        return render json: { error: "Failed to upload document" }, status: :unprocessable_entity
      end

      # Rails.logger.info "Document uploaded successfully: #{uploaded_document_url}"
    end

    if params[:seller][:profile_picture].present?
      pic = params[:seller][:profile_picture]
      # Rails.logger.info "📸 Processing profile picture: #{pic.original_filename}"

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

      # Rails.logger.info "Profile picture uploaded successfully: #{uploaded_profile_picture_url}"
    end

    @seller = Seller.new(seller_params)
    @seller.document_url = uploaded_document_url if uploaded_document_url
    @seller.profile_picture = uploaded_profile_picture_url if uploaded_profile_picture_url

    # Auto-generate username from fullname if not provided
    if @seller.username.blank? && @seller.fullname.present?
      base_username = @seller.fullname.strip.split(/\s+/).first.downcase.gsub(/[^a-z0-9]/, '')
      unique_username = generate_unique_username(base_username)
      @seller.username = unique_username
      Rails.logger.info "🔧 Auto-generated username: #{unique_username}"
    end

    # Rails.logger.info "📝 Seller Params: #{seller_params.to_h.except(:password, :password_confirmation).inspect}"
    # Rails.logger.info "📂 Document URL: #{@seller.document_url}"
    # Rails.logger.info "🖼️ Profile Picture URL: #{@seller.profile_picture}"

    if @seller.save
      # Only mark OTP as verified after successful seller creation
      if otp_code.present?
        otp_record = EmailOtp.find_by(email: seller_email, otp_code: otp_code)
        otp_record.update!(verified: true) if otp_record
        Rails.logger.info "✅ OTP verified for email: #{seller_email}"
      end

      # Send welcome email
      begin
        WelcomeMailer.welcome_email(@seller).deliver_now
        puts "✅ Welcome email sent to: #{@seller.email}"
        Rails.logger.info "✅ Welcome email sent to: #{@seller.email}"
      rescue => e
        puts "❌ Failed to send welcome email: #{e.message}"
        Rails.logger.error "❌ Failed to send welcome email: #{e.message}"
        # Don't fail the registration if email fails
      end
      
      # Assign Premium tier expiring at midnight on January 1, 2026 (last day of 2025) for 2025 registrations
      current_year = Date.current.year
      if current_year == 2025
        # Set exact expiry date to midnight on January 1, 2026 (00:00 2026-01-01)
        expiry_date = DateTime.new(2026, 1, 1, 0, 0, 0)
        
        # Calculate remaining months until end of 2025
        current_date = Time.current
        end_of_2025 = Time.new(2025, 12, 31, 23, 59, 59)
        remaining_days = ((end_of_2025 - current_date) / 1.day).ceil
        duration_months = (remaining_days / 30.44).ceil # Average days per month
        
        Rails.logger.info "🎉 2025 Registration: Assigning Premium tier to seller #{@seller.id}, expires at #{expiry_date} (#{remaining_days} days, ~#{duration_months} months)"
        SellerTier.create(seller_id: @seller.id, tier_id: 4, duration_months: duration_months, expires_at: expiry_date)
      else
        # Default free tier for other years
        Rails.logger.info "📝 #{current_year} Registration: Assigning Free tier to seller #{@seller.id}"
        SellerTier.create(seller_id: @seller.id, tier_id: 1, duration_months: 0)
      end
      # New sellers get remember_me by default for better user experience
      token = JsonWebToken.encode(seller_id: @seller.id, email: @seller.email, role: 'Seller', remember_me: true)
      # Rails.logger.info "Seller created successfully: #{@seller.id}"
      render json: { token: token, seller: @seller }, status: :created
    else
      Rails.logger.error "Seller creation failed: #{@seller.errors.full_messages.inspect}"
      render json: @seller.errors, status: :unprocessable_entity
    end
  end


  private

  def set_seller
    @seller = Seller.find(params[:id])
  end

  def seller_params
    params.require(:seller).permit(
      :fullname, :phone_number, :email, :enterprise_name, :location, :password, :password_confirmation,
      :username, :age_group_id, :zipcode, :city, :gender, :description, :business_registration_number,
      :document_url, :document_type_id, :document_expiry_date, :document_verified,
      :county_id, :sub_county_id, :profile_picture, category_ids: []
    )
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
    Rails.logger.error "Upload failed (#{type}): #{e.message}"
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
      Rails.logger.error "Error uploading permit: #{e.message}"
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
      Rails.logger.error "Error uploading profile picture: #{e.message}"
      nil
    end
  end


  # Upload raw PDF file
  def upload_file_only(file)
    uploaded = Cloudinary::Uploader.upload(file.tempfile.path, resource_type: "raw", upload_preset: ENV['UPLOAD_PRESET'], folder: "business_permits")
    uploaded["secure_url"]
  end

  # Generate a unique username from base username
  def generate_unique_username(base_username)
    # Start with base username
    username = base_username
    counter = 1
    
    # If username already exists, append a number
    while Seller.exists?(username: username) || Buyer.exists?(username: username)
      username = "#{base_username}#{counter}"
      counter += 1
      
      # Add random suffix if counter gets too high (avoid sequential numbers)
      if counter > 100
        random_suffix = SecureRandom.random_number(9999)
        username = "#{base_username}#{random_suffix}"
        break unless Seller.exists?(username: username) || Buyer.exists?(username: username)
      end
    end
    
    username
  end

end