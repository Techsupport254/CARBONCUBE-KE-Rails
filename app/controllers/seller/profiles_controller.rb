require 'fileutils'

class Seller::ProfilesController < ApplicationController
  before_action :authenticate_seller
  before_action :set_seller, only: [:show, :update]

  # GET /seller/profile
  def show
    render json: @seller
  end

  # PATCH/PUT /seller/profile
  def update
    begin
      Rails.logger.info "Received params: #{params.inspect}"
      
      uploaded_profile_picture_url = nil
      uploaded_document_url = nil
      
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

      # Handle document upload if present
      if params[:document].present?
        doc = params[:document]
        
        # Check if it's actually a file object
        unless doc.respond_to?(:original_filename)
          Rails.logger.error "Document is not a file object: #{doc.class}"
          return render json: { error: "Invalid document format" }, status: :unprocessable_entity
        end
        
        Rails.logger.info "📄 Processing document: #{doc.original_filename}"

        uploaded_document_url = handle_upload(
          file: doc,
          type: :document,
          max_size: 10.megabytes,
          accepted_types: ['application/pdf', 'image/jpeg', 'image/jpg', 'image/png'],
          processing_method: :process_and_upload_document
        )

        if uploaded_document_url.nil?
          Rails.logger.error "Document upload failed"
          return render json: { error: "Failed to upload document" }, status: :unprocessable_entity
        end

        Rails.logger.info "Document uploaded successfully: #{uploaded_document_url}"
      end

      # Only update fields that are provided and valid
      update_params = seller_params.reject { |k, v| v.blank? }
      
      # Remove any unexpected fields that might cause issues
      unexpected_fields = ['birthdate', 'created_at', 'updated_at', 'id']
      unexpected_fields.each { |field| update_params.delete(field) }
      
      Rails.logger.info "Update params after filtering: #{update_params.inspect}"
      
      # Add the uploaded URLs if available
      update_params[:profile_picture] = uploaded_profile_picture_url if uploaded_profile_picture_url
      update_params[:document_url] = uploaded_document_url if uploaded_document_url
      
      if @seller.update(update_params)
        render json: @seller
      else
        render json: { errors: @seller.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Profile update error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: "Failed to update profile: #{e.message}" }, status: :internal_server_error
    end
  end

  # POST /seller/change-password
  def change_password
    # Check if the current password is correct
    if current_seller.authenticate(params[:currentPassword])
      # Check if new password matches confirmation
      if params[:newPassword] == params[:confirmPassword]
        # Update the password
        if current_seller.update(password: params[:newPassword])
          render json: { message: 'Password updated successfully' }, status: :ok
        else
          render json: { errors: current_seller.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { error: 'New password and confirmation do not match' }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Current password is incorrect' }, status: :unauthorized
    end
  end

  private

  def set_seller
    @seller = current_seller
  end

  def seller_params
    params.permit(:fullname, :phone_number, :email, :enterprise_name, :location, :password, :password_confirmation, :business_registration_number, :gender, :city, :zipcode, :username, :description, :county_id, :sub_county_id, :age_group_id, :profile_picture, :document_url, :document_type_id, :document_expiry_date)
  end

  def authenticate_seller
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_seller && @current_seller.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
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
      Rails.logger.error "Error processing profile picture: #{e.message}"
      nil
    ensure
      FileUtils.rm_rf(temp_folder)
    end
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

  # Document Upload
  def process_and_upload_document(document)
    temp_folder = Rails.root.join("tmp/uploads/documents/#{Time.now.to_i}")
    FileUtils.mkdir_p(temp_folder)
    begin
      temp_file_path = temp_folder.join(document.original_filename)
      File.binwrite(temp_file_path, document.read)

      uploaded = Cloudinary::Uploader.upload(temp_file_path,
        upload_preset: ENV['UPLOAD_PRESET'],
        folder: "seller_documents",
        resource_type: "raw"
      )
      uploaded["secure_url"]
    rescue => e
      Rails.logger.error "Error processing document: #{e.message}"
      nil
    ensure
      FileUtils.rm_rf(temp_folder)
    end
  end
end
