require 'fileutils'

class Seller::ProfilesController < ApplicationController
  before_action :authenticate_seller
  before_action :set_seller, only: [:show, :update]

  # GET /seller/profile
  def show
    # OPTIMIZATION: Eager load associations to avoid N+1 queries
    @seller = Seller.includes(
      :categories,
      :seller_documents,
      { seller_tier: :tier },
      :county,
      :sub_county,
      :age_group,
      :document_type
    ).find(@seller.id)

    seller_data = SellerSerializer.new(@seller).as_json
    # Check if email is verified
    email_verified = EmailOtp.exists?(email: @seller.email, verified: true)
    seller_data[:email_verified] = email_verified
    # Check if user has a password set
    # password_digest will be nil or empty string for OAuth users who haven't set a password
    # It will be present (a bcrypt hash) for users who have set a password
    seller_data[:has_password] = @seller.password_digest.present? && !@seller.password_digest.to_s.strip.empty?

    render json: seller_data
  end

  # PATCH/PUT /seller/profile
  def update
    begin
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
      
      # Additional filtering for empty strings and null values
      update_params = update_params.reject { |k, v| v.nil? || v.to_s.strip.empty? }

      # Add the uploaded URLs if available
      update_params[:profile_picture] = uploaded_profile_picture_url if uploaded_profile_picture_url
      update_params[:document_url] = uploaded_document_url if uploaded_document_url
      
      if @seller.update(update_params)
        seller_data = SellerSerializer.new(@seller).as_json
        # Check if email is verified
        email_verified = EmailOtp.exists?(email: @seller.email, verified: true)
        seller_data[:email_verified] = email_verified
        # Check if user has a password set
        # password_digest will be nil or empty string for OAuth users who haven't set a password
        # It will be present (a bcrypt hash) for users who have set a password
        seller_data[:has_password] = @seller.password_digest.present? && !@seller.password_digest.to_s.strip.empty?
        render json: seller_data
      else
        Rails.logger.error "Seller update failed with errors: #{@seller.errors.full_messages.join(', ')}"
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
    # If user has a password, require current password
    if current_seller.password_digest.present?
      # Check if currentPassword was provided
      unless params[:currentPassword].present?
        render json: { error: 'Current password is required' }, status: :unauthorized
        return
      end
      
      # Authenticate the current password
      unless current_seller.authenticate(params[:currentPassword])
        render json: { error: 'Current password is incorrect' }, status: :unauthorized
        return
      end
    end
    
    # Check if new password matches confirmation
    unless params[:newPassword].present? && params[:confirmPassword].present?
      render json: { error: 'New password and confirmation are required' }, status: :unprocessable_entity
      return
    end
    
    if params[:newPassword] == params[:confirmPassword]
      # Update the password
      if current_seller.update(password: params[:newPassword])
        # Password changed successfully - session should be cleared on frontend
        # Return response indicating session invalidation
        render json: { 
          message: 'Password updated successfully',
          session_invalidated: true
        }, status: :ok
      else
        render json: { errors: current_seller.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: 'New password and confirmation do not match' }, status: :unprocessable_entity
    end
  end

  private

  def set_seller
    @seller = current_seller
  end

  def seller_params
    params.permit(:fullname, :phone_number, :secondary_phone_number, :email, :enterprise_name, :location, :password, :password_confirmation, :business_registration_number, :gender, :city, :zipcode, :username, :description, :county_id, :sub_county_id, :age_group_id, :profile_picture, :document_url, :document_type_id, :document_expiry_date)
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

  # Profile Picture Upload (direct upload, no processing)
  def process_and_upload_profile_picture(image)
    begin
      # Upload directly to Cloudinary without any processing
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

  # Document Upload (direct upload, no processing)
  def process_and_upload_document(document)
    begin
      # Upload directly to Cloudinary without any processing
      uploaded = Cloudinary::Uploader.upload(document.tempfile.path,
        upload_preset: ENV['UPLOAD_PRESET'],
        folder: "seller_documents",
        resource_type: "raw"
      )
      uploaded["secure_url"]
    rescue => e
      Rails.logger.error "Error uploading document: #{e.message}"
      nil
    end
  end
end
