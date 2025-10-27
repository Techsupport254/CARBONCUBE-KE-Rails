class Seller::AdsController < ApplicationController
  include ExceptionHandler
  
  before_action :authenticate_seller
  before_action :set_ad, only: [:show, :update, :destroy]
  before_action :load_ad_with_offer, only: [:show]


  # app/controllers/seller/ads_controller.rb
  def index
    active_ads = current_seller.ads.active.includes(:category, :reviews)
    deleted_ads = current_seller.ads.deleted.includes(:category, :reviews)

    render json: {
      active_ads: active_ads.as_json(include: [:category, :reviews], methods: [:mean_rating]),
      deleted_ads: deleted_ads.as_json(include: [:category, :reviews], methods: [:mean_rating])
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
    
    # Build ad JSON with offer information
    ad_json = @ad.as_json(include: [:category, :subcategory], methods: [:mean_rating])
    
    # Add offer information if exists (including scheduled offers for seller view)
    active_offer_ad = @ad.offer_ads.joins(:offer)
                        .where(is_active: true)
                        .where('offers.end_time > ?', DateTime.now)
                        .where("offers.status IN ('active', 'scheduled', 'paused')")
                        .includes(:offer)
                        .order('offers.start_time ASC')
                        .first
    
    if active_offer_ad
      ad_json[:discount_percentage] = active_offer_ad.discount_percentage
      ad_json[:discounted_price] = active_offer_ad.discounted_price
      ad_json[:offer_start_date] = active_offer_ad.offer.start_time
      ad_json[:offer_end_date] = active_offer_ad.offer.end_time
      ad_json[:offer_description] = active_offer_ad.seller_notes || active_offer_ad.offer.description
      ad_json[:offer_type] = active_offer_ad.offer.offer_type
      ad_json[:offer_status] = active_offer_ad.offer.status
      ad_json[:offer_name] = active_offer_ad.offer.name
      ad_json[:offer_id] = active_offer_ad.offer.id
      ad_json[:minimum_quantity] = active_offer_ad.offer.minimum_order_amount
    end
    
    # Render the complete ad data with reviews and buyer details
    render json: {
      **ad_json,
      reviews: reviews.as_json(include: [:buyer]),
      buyer_details: buyer_details
    }
  end

  def create
    begin
      Rails.logger.info "🚀 Starting ad creation process"
      Rails.logger.info "📊 Request params: #{params[:ad].inspect}"
      
      seller_tier = current_seller.seller_tier

      unless seller_tier && seller_tier.tier
        Rails.logger.error "❌ No active subscription tier for seller #{current_seller.id}"
        return render json: { error: "You do not have an active subscription tier. Please upgrade your account to post ads." }, status: :forbidden
      end

      ad_limit = seller_tier.tier.ads_limit || 0
      Rails.logger.info "🔍 Current seller tier: #{seller_tier.tier.name} with ad limit: #{ad_limit}"
      current_ads_count = current_seller.ads.count

      if current_ads_count >= ad_limit
        Rails.logger.error "❌ Ad limit reached for seller #{current_seller.id}: #{current_ads_count}/#{ad_limit}"
        return render json: { error: "Ad creation limit reached for your current tier (#{ad_limit} ads max)." }, status: :forbidden
      end

      # Process and upload images if present
      if params[:ad][:media].present?
        Rails.logger.info "📸 Found #{params[:ad][:media].length} images to process"
        begin
          uploaded_media = process_and_upload_images(params[:ad][:media])
          Rails.logger.info "📸 Processed images result: #{uploaded_media.length} URLs"
          params[:ad][:media] = uploaded_media
        rescue => e
          Rails.logger.error "❌ Error processing images: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          return render json: { error: "Failed to process images. Please try again." }, status: :unprocessable_entity
        end
      else
        Rails.logger.info "📸 No images provided for this ad"
      end

      Rails.logger.info "📝 Building ad with params: #{ad_params.inspect}"
      @ad = current_seller.ads.build(ad_params)
      Rails.logger.info "📝 Ad built with media: #{@ad.media.inspect}"

      if @ad.save
        # Update seller's last active timestamp when creating an ad
        current_seller.update_last_active!
        Rails.logger.info "✅ Ad saved successfully with ID: #{@ad.id}"
        render json: @ad.as_json(include: [:category, :reviews], methods: [:mean_rating]), status: :created
      else
        Rails.logger.error "❌ Ad save failed: #{@ad.errors.full_messages.join(', ')}"
        Rails.logger.error "❌ Ad attributes: #{@ad.attributes.inspect}"
        render json: { errors: @ad.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "❌ Error creating ad: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.join("\n")}"
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
      # Update seller's last active timestamp when updating an ad
      current_seller.update_last_active!
      render json: ad.as_json(include: [:category, :reviews], methods: [:mean_rating])
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

  # POST /seller/ads/:id/offer
  def create_offer
    ad = current_seller.ads.find_by(id: params[:id])
    return render json: { error: 'Ad not found' }, status: :not_found unless ad

    begin
      ActiveRecord::Base.transaction do
        # Validate required parameters
        unless params[:discount_percentage].present? && params[:offer_end_date].present?
          return render json: { 
            error: 'discount_percentage and offer_end_date are required' 
          }, status: :unprocessable_entity
        end

        discount = params[:discount_percentage].to_f
        if discount <= 0 || discount >= 100
          return render json: { 
            error: 'Discount percentage must be between 1 and 99' 
          }, status: :unprocessable_entity
        end

        # Parse and validate dates
        begin
          end_time = DateTime.parse(params[:offer_end_date])
        rescue ArgumentError
          return render json: { 
            error: 'Invalid offer_end_date format' 
          }, status: :unprocessable_entity
        end

        # Parse start date or default to now
        start_time = if params[:offer_start_date].present?
          begin
            DateTime.parse(params[:offer_start_date])
          rescue ArgumentError
            return render json: { 
              error: 'Invalid offer_start_date format' 
            }, status: :unprocessable_entity
          end
        else
          DateTime.now
        end

        if end_time <= start_time
          return render json: { 
            error: 'Offer end date must be after start date' 
          }, status: :unprocessable_entity
        end

        # Get offer type and status from params or use defaults
        offer_type = params[:offer_type].presence || 'limited_time_offer'
        offer_status = params[:offer_status].presence || 'active'
        
        # Auto-determine status based on dates if not explicitly set
        if offer_status == 'active'
          if start_time > DateTime.now
            offer_status = 'scheduled'
          elsif end_time < DateTime.now
            offer_status = 'expired'
          end
        end

        # Check if ad already has an active offer
        existing_offer_ad = ad.offer_ads.joins(:offer)
                              .where(is_active: true)
                              .where('offers.end_time > ?', DateTime.now)
                              .first

        if existing_offer_ad
          # Update existing offer
          offer = existing_offer_ad.offer
          offer.update!(
            description: params[:offer_description].presence || offer.description,
            offer_type: offer_type,
            start_time: start_time,
            end_time: end_time,
            status: offer_status,
            discount_percentage: discount
          )
          
          # Update offer_ad discount
          existing_offer_ad.update!(
            discount_percentage: discount,
            original_price: ad.price,
            discounted_price: ad.price * (1 - discount / 100.0),
            seller_notes: params[:offer_description]
          )
        else
          # Create new offer
          offer_name = params[:offer_name].presence || "#{ad.title.truncate(30)} - Special Offer"
          offer = current_seller.offers.create!(
            name: offer_name,
            description: params[:offer_description].presence || "Special discount on #{ad.title}",
            offer_type: offer_type,
            discount_type: 'percentage',
            status: offer_status,
            start_time: start_time,
            end_time: end_time,
            discount_percentage: discount,
            show_on_homepage: false,
            featured: false,
            priority: 0
          )

          # Create offer_ad association
          OfferAd.create!(
            offer: offer,
            ad: ad,
            discount_percentage: discount,
            original_price: ad.price,
            discounted_price: ad.price * (1 - discount / 100.0),
            is_active: true,
            seller_notes: params[:offer_description]
          )
        end

        # Fetch the updated ad with offer information
        ad.reload
        active_offer_ad = ad.offer_ads.joins(:offer)
                            .where(is_active: true)
                            .where('offers.end_time > ?', DateTime.now)
                            .includes(:offer)
                            .first

        ad_json = ad.as_json(include: [:category, :subcategory], methods: [:mean_rating])
        
        if active_offer_ad
          ad_json[:discount_percentage] = active_offer_ad.discount_percentage
          ad_json[:discounted_price] = active_offer_ad.discounted_price
          ad_json[:offer_start_date] = active_offer_ad.offer.start_time
          ad_json[:offer_end_date] = active_offer_ad.offer.end_time
          ad_json[:offer_description] = active_offer_ad.seller_notes || active_offer_ad.offer.description
          ad_json[:offer_type] = active_offer_ad.offer.offer_type
          ad_json[:offer_status] = active_offer_ad.offer.status
          ad_json[:offer_name] = active_offer_ad.offer.name
          ad_json[:offer_id] = active_offer_ad.offer.id
        end

        render json: ad_json, status: :ok
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "Error creating offer: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'Failed to create offer' }, status: :internal_server_error
    end
  end

  # DELETE /seller/ads/:id/offer
  def remove_offer
    ad = current_seller.ads.find_by(id: params[:id])
    return render json: { error: 'Ad not found' }, status: :not_found unless ad

    begin
      # Find active offer_ad for this ad
      offer_ad = ad.offer_ads.joins(:offer)
                    .where(is_active: true)
                    .where('offers.end_time > ?', DateTime.now)
                    .first

      if offer_ad
        # Deactivate the offer_ad
        offer_ad.update!(is_active: false)
        
        # If the offer has no other active ads, deactivate the offer too
        offer = offer_ad.offer
        if offer.offer_ads.where(is_active: true).count == 0
          offer.update!(status: 'paused')
        end
      end

      # Return ad without offer information
      ad_json = ad.as_json(include: [:category, :subcategory], methods: [:mean_rating])
      render json: ad_json, status: :ok
    rescue => e
      Rails.logger.error "Error removing offer: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'Failed to remove offer' }, status: :internal_server_error
    end
  end

  # app/controllers/seller/ads_controller.rb
  def restore
    ad = current_seller.ads.deleted.find_by(id: params[:id])

    if ad.nil?
      return render json: { error: "Ad not found or not deleted" }, status: :not_found
    end

    if ad.update(deleted: false)
      render json: ad.as_json(include: [:category, :reviews], methods: [:mean_rating]), status: :ok
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

  def load_ad_with_offer
    # Preload offer_ads and offers for efficiency
    if @ad
      @ad = Ad.includes(offer_ads: :offer).find(@ad.id)
    end
  end

  def ad_params
    permitted = params.require(:ad).permit(
      :title, :description, :category_id, :subcategory_id, :price, 
      :brand, :manufacturer, :item_length, :item_width, 
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
    Rails.logger.info "🖼️ Processing #{Array(images).length} images for upload"
    Rails.logger.info "🔧 Cloudinary config - Cloud: #{ENV['CLOUDINARY_CLOUD_NAME']}, Preset: #{ENV['UPLOAD_PRESET']}"

    begin
      Array(images).each do |image|
        begin
          Rails.logger.info "📤 Processing image: #{image.original_filename} (#{image.size} bytes)"
          
          # Check if tempfile exists and is readable
          unless image.tempfile && File.exist?(image.tempfile.path)
            Rails.logger.error "❌ Tempfile not found for image: #{image.original_filename}"
            next
          end
          
          # Check Cloudinary configuration
          unless ENV['UPLOAD_PRESET'].present?
            Rails.logger.error "❌ UPLOAD_PRESET environment variable is not set"
            raise "UPLOAD_PRESET not configured"
          end
          
          # Upload original image directly to Cloudinary without any processing
          Rails.logger.info "🚀 Uploading to Cloudinary with preset: #{ENV['UPLOAD_PRESET']}"
          uploaded_image = Cloudinary::Uploader.upload(
            image.tempfile.path, 
            upload_preset: ENV['UPLOAD_PRESET']
          )
          Rails.logger.info "🚀 Uploaded to Cloudinary: #{uploaded_image['secure_url']}"

          uploaded_urls << uploaded_image["secure_url"]
        rescue => e
          Rails.logger.error "❌ Error uploading image #{image.original_filename}: #{e.message}"
          Rails.logger.error "❌ Error class: #{e.class}"
          Rails.logger.error e.backtrace.join("\n")
          # Don't fail completely, just skip this image
        end
      end
    rescue => e
      Rails.logger.error "❌ Error in process_and_upload_images: #{e.message}"
      Rails.logger.error "❌ Error class: #{e.class}"
      Rails.logger.error e.backtrace.join("\n")
      raise e # Re-raise to be caught by the calling method
    end

    Rails.logger.info "✅ Successfully uploaded #{uploaded_urls.length} images"
    uploaded_urls
  end


end
