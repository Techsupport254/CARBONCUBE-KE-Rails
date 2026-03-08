class Buyer::ReviewsController < ApplicationController
  before_action :authenticate_user
  before_action :set_ad, only: [:index, :create]
  before_action :set_review, only: [:show, :update, :destroy]

  # GET /buyer/ads/:ad_id/reviews
  def index
    @reviews = @ad.reviews.includes(:buyer, :seller)
    
    # Calculate stats
    average_rating = @ad.mean_rating
    total_reviews = @ad.review_count
    reviews_with_images = @reviews.select { |r| r.images.present? && r.images.any? }.count
    
    render json: {
      reviews: @reviews.as_json(include: [:buyer, :seller]),
      stats: {
        average_rating: average_rating,
        total_reviews: total_reviews,
        reviews_with_images: reviews_with_images
      }
    }
  end

  # GET /buyer/ads/:ad_id/reviews/:id
  def show
    render json: @review.as_json(include: [:buyer, :seller])
  end

  # POST /buyer/ads/:ad_id/reviews
  def create
    # Ensure only buyers or sellers can create reviews
    unless current_user.is_a?(Buyer) || current_user.is_a?(Seller)
      render json: { error: 'Only registered accounts can create reviews' }, status: :forbidden
      return
    end

    # Process and upload images if present
    if params[:review][:images].present? && params[:review][:images].is_a?(Array)
      begin
        uploaded_images = process_and_upload_review_images(params[:review][:images])
        params[:review][:images] = uploaded_images
      rescue => e
        Rails.logger.error "Error processing review images: #{e.message}"
        return render json: { error: "Failed to process images. Please try again." }, status: :unprocessable_entity
      end
    else
      params[:review][:images] = []
    end

    @review = @ad.reviews.new(review_params)
    if current_user.is_a?(Buyer)
      @review.buyer = current_user
    else
      @review.seller = current_user
    end

    if @review.save
      render json: @review.as_json(include: [:buyer, :seller]), status: :created
    else
      render json: @review.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /buyer/ads/:ad_id/reviews/:id
  def update
    if @review.update(review_params)
      render json: @review
    else
      render json: @review.errors, status: :unprocessable_entity
    end
  end

  # DELETE /buyer/ads/:ad_id/reviews/:id
  def destroy
    @review.destroy
    head :no_content
  end

  private

  def set_ad
    @ad = Ad.active.find(params[:ad_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ad not found' }, status: :not_found
  end

  def set_review
    reviews_relation = current_user.is_a?(Buyer) ? current_user.reviews : current_user.reviews_written
    @review = reviews_relation.find_by!(id: params[:id], ad_id: params[:ad_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Review not found' }, status: :not_found
  end

  def review_params
    params.require(:review).permit(:rating, :review, images: [])
  end

  def authenticate_user
    @current_user = AuthorizeApiRequest.new(request.headers).result
    unless @current_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end

  # Upload review images to Cloudinary
  def process_and_upload_review_images(images)
    uploaded_urls = []

    begin
      Array(images).each do |image|
        begin
          # Skip if it's already a URL (shouldn't happen, but safety check)
          if image.is_a?(String)
            uploaded_urls << image
            next
          end

          Rails.logger.info "📤 Processing review image: #{image.original_filename} (#{image.size} bytes)"
          
          unless image.tempfile && File.exist?(image.tempfile.path)
            Rails.logger.error "❌ Tempfile not found for image: #{image.original_filename}"
            next
          end
          
          unless ENV['UPLOAD_PRESET'].present?
            Rails.logger.error "❌ UPLOAD_PRESET environment variable is not set"
            raise "UPLOAD_PRESET not configured"
          end
          
          # Upload to Cloudinary
          Rails.logger.info "Uploading review image to Cloudinary"
          uploaded_image = Cloudinary::Uploader.upload(
            image.tempfile.path,
            upload_preset: ENV['UPLOAD_PRESET'],
            folder: "review_images"
          )
          Rails.logger.info "✅ Uploaded review image: #{uploaded_image['secure_url']}"

          uploaded_urls << uploaded_image["secure_url"]
        rescue => e
          Rails.logger.error "❌ Error uploading review image #{image.original_filename}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      end
    rescue => e
      Rails.logger.error "❌ Error in process_and_upload_review_images: #{e.message}"
      raise e
    end

    uploaded_urls
  end
end
