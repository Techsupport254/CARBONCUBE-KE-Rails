require 'cloudinary'
require 'cloudinary/uploader'

class Marketing::CategoriesController < ApplicationController
  before_action :authenticate_marketing_user
  before_action :set_category, only: [:update_image]

  # PUT /marketing/categories/:id/image
  def update_image
    unless params[:image].present?
      return render json: { error: 'No image file provided' }, status: :bad_request
    end

    begin
      # Upload image to Cloudinary
      uploaded_url = process_and_upload_category_image(params[:image])
      
      if uploaded_url
        # Update category with new image URL
        if @category.update(image_url: uploaded_url)
          render json: {
            success: true,
            message: 'Category image updated successfully',
            category: @category.as_json(include: :subcategories)
          }, status: :ok
        else
          render json: {
            error: 'Failed to update category',
            errors: @category.errors.full_messages
          }, status: :unprocessable_entity
        end
      else
        render json: { error: 'Image upload failed' }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error updating category image: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'Failed to upload image' }, status: :internal_server_error
    end
  end

  private

  def set_category
    @category = Category.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Category not found' }, status: :not_found
  end

  def authenticate_marketing_user
    @current_user = AuthorizeApiRequest.new(request.headers).result
    unless @current_user && (@current_user.is_a?(MarketingUser) || @current_user.is_a?(Admin))
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  # Upload category image to Cloudinary
  def process_and_upload_category_image(image)
    begin
      Rails.logger.info "📤 Uploading category image to Cloudinary"
      
      unless image.tempfile && File.exist?(image.tempfile.path)
        Rails.logger.error "❌ Tempfile not found for image"
        return nil
      end
      
      unless ENV['UPLOAD_PRESET'].present?
        Rails.logger.error "❌ UPLOAD_PRESET environment variable is not set"
        raise "UPLOAD_PRESET not configured"
      end
      
      # Upload to Cloudinary with optimizations for category images (1:1 aspect ratio)
      uploaded_image = Cloudinary::Uploader.upload(
        image.tempfile.path,
        upload_preset: ENV['UPLOAD_PRESET'],
        folder: "category_images",
        transformation: [
          { width: 1200, height: 1200, crop: "fill", gravity: "auto" },
          { quality: "auto", fetch_format: "auto" }
        ]
      )
      
      Rails.logger.info "✅ Uploaded category image: #{uploaded_image['secure_url']}"
      uploaded_image["secure_url"]
    rescue => e
      Rails.logger.error "❌ Error uploading category image: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end
  end
end

