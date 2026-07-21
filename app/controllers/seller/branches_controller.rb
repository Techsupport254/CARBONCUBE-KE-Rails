class Seller::BranchesController < ApplicationController
  before_action :authenticate_seller
  before_action :set_branch, only: [:show, :update, :destroy]
  before_action :ensure_seller_owns_branch, only: [:show, :update, :destroy]

  # GET /seller/branches
  def index
    @branches = @current_seller.branches.order(created_at: :desc)
    # Ensure we always return an array, even if empty
    render json: @branches.to_a
  end

  # GET /seller/branches/:id
  def show
    render json: @branch
  end

  # POST /seller/branches
  def create
    uploaded_profile_picture_url = nil
    
    # Handle profile picture upload if present
    if params[:branch][:profile_picture].present?
      pic = params[:branch][:profile_picture]
      
      unless pic.respond_to?(:original_filename)
        Rails.logger.error "Profile picture is not a file object: #{pic.class}"
        return render json: { error: "Invalid file format" }, status: :unprocessable_entity
      end
      
      Rails.logger.info "📸 Processing branch profile picture: #{pic.original_filename}"

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

    @branch = @current_seller.branches.build(branch_params)
    @branch.profile_picture = uploaded_profile_picture_url if uploaded_profile_picture_url

    if @branch.save
      render json: @branch, status: :created
    else
      render json: { errors: @branch.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /seller/branches/:id
  def update
    uploaded_profile_picture_url = nil
    
    # Handle profile picture upload if present
    if params[:branch][:profile_picture].present?
      pic = params[:branch][:profile_picture]
      
      unless pic.respond_to?(:original_filename)
        Rails.logger.error "Profile picture is not a file object: #{pic.class}"
        return render json: { error: "Invalid file format" }, status: :unprocessable_entity
      end
      
      Rails.logger.info "📸 Processing branch profile picture: #{pic.original_filename}"

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

    update_params = branch_params
    update_params[:profile_picture] = uploaded_profile_picture_url if uploaded_profile_picture_url

    if @branch.update(update_params)
      render json: @branch
    else
      render json: { errors: @branch.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /seller/branches/:id
  def destroy
    # Prevent deleting the main branch if it's the only branch
    if @branch.is_main_branch? && @current_seller.branches.count == 1
      render json: { error: "Cannot delete the only branch" }, status: :unprocessable_entity
      return
    end

    if @branch.is_main_branch?
      # If deleting main branch, promote another branch to main
      next_branch = @current_seller.branches.where.not(id: @branch.id).first
      if next_branch
        next_branch.update(is_main_branch: true)
      end
    end

    @branch.destroy
    head :no_content
  end

  private

  def set_branch
    @branch = Branch.find(params[:id])
  end

  def ensure_seller_owns_branch
    unless @branch.seller_id == @current_seller.id
      render json: { error: "Unauthorized" }, status: :forbidden
    end
  end

  def branch_params
    params.require(:branch).permit(
      :name,
      :description,
      :location,
      :latitude,
      :longitude,
      :phone,
      :secondary_phone,
      :is_main_branch,
      :county_id,
      :sub_county_id,
      :profile_picture
    )
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
        folder: "branch_profile_pictures",
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
