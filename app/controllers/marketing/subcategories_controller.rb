require 'cloudinary'
require 'cloudinary/uploader'

class Marketing::SubcategoriesController < ApplicationController
  before_action :authenticate_marketing_user_or_admin
  before_action :set_subcategory, only: [:update_image]

  # PUT /marketing/subcategories/:id/image
  def update_image
    if params[:image].present?
      image_url = process_and_upload_image(params[:image])
      if image_url
        if @subcategory.update(image_url: image_url)
          render json: { message: 'Subcategory image updated successfully', subcategory: @subcategory }, status: :ok
        else
          render json: { errors: @subcategory.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { error: 'Image upload failed' }, status: :unprocessable_entity
      end
    else
      render json: { error: 'No image file provided' }, status: :bad_request
    end
  end

  private

  def set_subcategory
    @subcategory = Subcategory.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Subcategory not found' }, status: :not_found
  end

  def process_and_upload_image(image)
    Rails.logger.info "📤 Uploading subcategory image to Cloudinary"

    unless image.tempfile && File.exist?(image.tempfile.path)
      Rails.logger.error "❌ Tempfile not found for image"
      return nil
    end

    unless ENV['UPLOAD_PRESET'].present?
      Rails.logger.error "❌ UPLOAD_PRESET environment variable is not set"
      raise "UPLOAD_PRESET not configured"
    end

    # Upload to Cloudinary with optimizations for subcategory images (1:1 aspect ratio)
    uploaded_image = Cloudinary::Uploader.upload(
      image.tempfile.path,
      upload_preset: ENV['UPLOAD_PRESET'],
      folder: "subcategory_images",
      transformation: [
        { width: 1200, height: 1200, crop: "fill", gravity: "auto" }, # 1:1 aspect ratio
        { quality: "auto", fetch_format: "auto" }
      ]
    )

    Rails.logger.info "✅ Uploaded subcategory image: #{uploaded_image['secure_url']}"
    uploaded_image["secure_url"]
  rescue => e
    Rails.logger.error "❌ Error uploading subcategory image: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
  end

  def authenticate_marketing_user_or_admin
    @current_user = AuthorizeApiRequest.new(request.headers).result
    unless @current_user && (@current_user.is_a?(MarketingUser) || @current_user.is_a?(Admin))
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end

