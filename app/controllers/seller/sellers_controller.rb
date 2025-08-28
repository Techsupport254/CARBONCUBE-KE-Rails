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
    # Rails.logger.info "🔍 Checking if buyer exists with email: #{seller_email}"

    if Buyer.exists?(email: seller_email)
      Rails.logger.error "❌ Email already used by buyer: #{seller_email}"
      return render json: { errors: ['Email is already in use by a buyer'] }, status: :unprocessable_entity
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
        Rails.logger.error "❌ Document upload failed"
        return render json: { error: "Failed to upload document" }, status: :unprocessable_entity
      end

      # Rails.logger.info "✅ Document uploaded successfully: #{uploaded_document_url}"
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
        Rails.logger.error "❌ Profile picture upload failed"
        return render json: { error: "Failed to upload profile picture" }, status: :unprocessable_entity
      end

      # Rails.logger.info "✅ Profile picture uploaded successfully: #{uploaded_profile_picture_url}"
    end

    @seller = Seller.new(seller_params)
    @seller.document_url = uploaded_document_url if uploaded_document_url
    @seller.profile_picture = uploaded_profile_picture_url if uploaded_profile_picture_url

    # Rails.logger.info "📝 Seller Params: #{seller_params.to_h.except(:password, :password_confirmation).inspect}"
    # Rails.logger.info "📂 Document URL: #{@seller.document_url}"
    # Rails.logger.info "🖼️ Profile Picture URL: #{@seller.profile_picture}"

    if @seller.save
      SellerTier.create(seller_id: @seller.id, tier_id: 1, duration_months: 0)
      token = JsonWebToken.encode(seller_id: @seller.id, role: 'Seller')
      # Rails.logger.info "✅ Seller created successfully: #{@seller.id}"
      render json: { token: token, seller: @seller }, status: :created
    else
      Rails.logger.error "❌ Seller creation failed: #{@seller.errors.full_messages.inspect}"
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
    Rails.logger.error "❌ Upload failed (#{type}): #{e.message}"
    nil
  end

  # Permit Upload (with optional sharpening)
  def process_and_upload_permit(image)
    temp_folder = Rails.root.join("tmp/uploads/#{Time.now.to_i}")
    FileUtils.mkdir_p(temp_folder)
    begin
      temp_file_path = temp_folder.join(image.original_filename)
      File.binwrite(temp_file_path, image.read)

      sharpen_image(temp_file_path) unless sharp_enough?(temp_file_path)
      optimized_path = optimize_and_convert_to_webp(temp_file_path)

      uploaded = Cloudinary::Uploader.upload(optimized_path, upload_preset: ENV['UPLOAD_PRESET'], folder: "business_permits")
      uploaded["secure_url"]
    rescue => e
      Rails.logger.error "❌ Error processing permit: #{e.message}"
      nil
    ensure
      FileUtils.rm_rf(temp_folder)
    end
  end

  # Profile Picture Upload (with face crop)
  def process_and_upload_profile_picture(image)
    temp_folder = Rails.root.join("tmp/uploads/profile_pictures/#{Time.now.to_i}")
    FileUtils.mkdir_p(temp_folder)
    begin
      temp_file_path = temp_folder.join(image.original_filename)
      File.binwrite(temp_file_path, image.read)

      optimized_path = optimize_profile_picture(temp_file_path)

      uploaded = Cloudinary::Uploader.upload(optimized_path,
        upload_preset: ENV['UPLOAD_PRESET'],
        folder: "profile_pictures",
        transformation: [
          { width: 400, height: 400, crop: "fill", gravity: "face" },
          { quality: "auto", fetch_format: "auto" }
        ]
      )
      uploaded["secure_url"]
    rescue => e
      Rails.logger.error "❌ Error processing profile picture: #{e.message}"
      nil
    ensure
      FileUtils.rm_rf(temp_folder)
    end
  end

  # Optimize and convert to WebP for permits
  def optimize_and_convert_to_webp(image_path)
    webp_path = image_path.to_s.sub(/\.\w+$/, ".webp")
    ImageProcessing::Vips
      .source(image_path)
      .resize_to_limit(1080, nil)
      .convert("webp")
      .saver(quality: 70)
      .call(destination: webp_path)
    webp_path
  end

  # Optimize and convert profile picture
  def optimize_profile_picture(image_path)
    webp_path = image_path.to_s.sub(/\.\w+$/, ".webp")
    ImageProcessing::Vips
      .source(image_path)
      .resize_to_fill(400, 400)
      .convert("webp")
      .saver(quality: 85)
      .call(destination: webp_path)
    webp_path
  end

  # Upload raw PDF file
  def upload_file_only(file)
    uploaded = Cloudinary::Uploader.upload(file.tempfile.path, resource_type: "raw", upload_preset: ENV['UPLOAD_PRESET'], folder: "business_permits")
    uploaded["secure_url"]
  end

  # Sharpness detection using Python script
  def sharp_enough?(image_path)
    script_path = Rails.root.join("scripts/check_sharpness.py")
    result = `python3 "#{script_path}" "#{image_path}"`.strip
    result == "Sharp"
  end

  # Sharpen image using Python script
  def sharpen_image(image_path)
    script_path = Rails.root.join("scripts/sharpen_image.py")
    `python3 "#{script_path}" "#{image_path}"`
  end
end