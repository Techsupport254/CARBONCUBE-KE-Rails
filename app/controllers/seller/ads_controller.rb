class Seller::AdsController < ApplicationController
  include ExceptionHandler
  
  before_action :authenticate_seller
  before_action :set_ad, only: [:show, :update, :destroy]


  # app/controllers/seller/ads_controller.rb
  def index
    active_ads = current_seller.ads.active.includes(:category, :reviews)
    deleted_ads = current_seller.ads.deleted.includes(:category, :reviews)

    render json: {
      active_ads: active_ads.as_json(include: [:category, :reviews], methods: [:quantity_sold, :mean_rating]),
      deleted_ads: deleted_ads.as_json(include: [:category, :reviews], methods: [:quantity_sold, :mean_rating])
    }
  end

  def show
    # Get reviews
    reviews = @ad.reviews.includes(:buyer)
    
    # Get buyer details using the BuyerDetailsUtility
    buyer_details = nil
    begin
      buyer_details = BuyerDetailsUtility.get_ad_reviewers_details(@ad.id)
    rescue => e
      Rails.logger.error "Error fetching buyer details: #{e.message}"
      buyer_details = { error: "Failed to fetch buyer details" }
    end
    
    # Render the complete ad data with reviews and buyer details
    render json: {
      **@ad.as_json(include: [:category, :subcategory], methods: [:quantity_sold, :mean_rating]),
      reviews: reviews.as_json(include: [:buyer]),
      buyer_details: buyer_details
    }
  end

  def create
    begin
      seller_tier = current_seller.seller_tier

      unless seller_tier && seller_tier.tier
        return render json: { error: "You do not have an active subscription tier. Please upgrade your account to post ads." }, status: :forbidden
      end

      ad_limit = seller_tier.tier.ads_limit || 0
      # Rails.logger.info "🔍 Current seller tier: #{seller_tier.tier.name} with ad limit: #{ad_limit}"
      current_ads_count = current_seller.ads.count

      if current_ads_count >= ad_limit
        return render json: { error: "Ad creation limit reached for your current tier (#{ad_limit} ads max)." }, status: :forbidden
      end

      # Process and upload images if present
      if params[:ad][:media].present?
        begin
          params[:ad][:media] = process_and_upload_images(params[:ad][:media])
        rescue => e
          Rails.logger.error "Error processing images: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          return render json: { error: "Failed to process images. Please try again." }, status: :unprocessable_entity
        end
      end

      @ad = current_seller.ads.build(ad_params)

      if @ad.save
        render json: @ad.as_json(include: [:category, :reviews], methods: [:quantity_sold, :mean_rating]), status: :created
      else
        Rails.logger.error "Ad save failed: #{@ad.errors.full_messages.join(', ')}"
        render json: { errors: @ad.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error creating ad: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: "Failed to create ad. Please try again." }, status: :internal_server_error
    end
  end

  def update
    ad = current_seller.ads.find(params[:id])
    media_param = params[:ad][:media]
    existing_media_param = params[:ad][:existing_media]

    # Handle image updates based on whether we have new files and/or existing media
    if media_param.present? || existing_media_param.present?
      # Start with existing media URLs that should be kept
      final_media = existing_media_param.present? ? existing_media_param : []

      # Add new uploaded files if any
      if media_param.present?
        new_files = media_param.select { |m| m.is_a?(ActionDispatch::Http::UploadedFile) }
        if new_files.any?
          uploaded_urls = process_and_upload_images(new_files)
          final_media += uploaded_urls
        end
      end

      # Update with final media array
      updated = ad.update(ad_params.except(:media, :existing_media).merge(media: final_media))
    else
      # No media changes, just update other fields
      updated = ad.update(ad_params.except(:media, :existing_media))
    end

    if updated
      render json: ad.as_json(include: [:category, :reviews], methods: [:quantity_sold, :mean_rating])
    else
      render json: { error: ad.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @ad.update(deleted: true)
      head :no_content
    else
      render json: { error: 'Unable to delete ad' }, status: :unprocessable_entity
    end
  end

  # app/controllers/seller/ads_controller.rb
  def restore
    ad = current_seller.ads.deleted.find_by(id: params[:id])

    if ad.nil?
      return render json: { error: "Ad not found or not deleted" }, status: :not_found
    end

    if ad.update(deleted: false)
      render json: ad.as_json(include: [:category, :reviews], methods: [:quantity_sold, :mean_rating]), status: :ok
    else
      render json: { error: ad.errors.full_messages }, status: :unprocessable_entity
    end
  end


  private


  def authenticate_seller
    @current_user = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_seller
    @current_user
  end

  def set_ad
    @seller = current_seller
    return render json: { error: 'Seller not found' }, status: :not_found unless @seller

    @ad = @seller.ads.find_by(id: params[:id])
    render json: { error: 'Ad not found' }, status: :not_found unless @ad
  end

  def ad_params
    permitted = params.require(:ad).permit(
      :title, :description, :category_id, :subcategory_id, :price, 
      :quantity, :brand, :manufacturer, :item_length, :item_width, 
      :item_height, :item_weight, :weight_unit, :flagged, :condition,
      media: [], existing_media: []
    )

    # Convert empty strings to nil for optional numeric fields (only for fields that are present in params)
    %i[item_length item_width item_height item_weight].each do |field|
      if params[:ad].key?(field) && permitted[field].blank?
        permitted[field] = nil
      end
    end

    # Set default weight_unit if empty or invalid (only when field is present in params)
    if params[:ad].key?(:weight_unit)
      if permitted[:weight_unit].blank? || !['Grams', 'Kilograms'].include?(permitted[:weight_unit])
        permitted[:weight_unit] = 'Grams'
      end
    end

    permitted
  end


  # Uploads images to Cloudinary as-is (no preprocessing)
  def process_and_upload_images(images)
    uploaded_urls = []

    begin
      Parallel.each(Array(images), in_threads: 4) do |image|
        begin
          # Upload original image directly to Cloudinary without any processing
          uploaded_image = Cloudinary::Uploader.upload(image.tempfile.path, upload_preset: ENV['UPLOAD_PRESET'])
          Rails.logger.info "🚀 Uploaded to Cloudinary: #{uploaded_image['secure_url']}"

          uploaded_urls << uploaded_image["secure_url"]
        rescue => e
          Rails.logger.error "Error uploading image: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      end
    rescue => e
      Rails.logger.error "Error in process_and_upload_images: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return [] # Return empty array instead of failing
    end

    uploaded_urls
  end


end
