class Sales::AdsController < ApplicationController
  before_action :authenticate_sales_user, except: [:conditions]
  before_action :set_ad, only: [:show, :update, :flag, :restore, :destroy, :create_offer, :remove_offer]

  EFFECTIVE_IS_ADDED_BY_SALES_SQL = Ad.effective_is_added_by_sales_sql
  
  # GET /sales/ads
  def index
    per_page = params[:per_page]&.to_i || 20
    page = params[:page]&.to_i || 1
    
    # Build base query without select for counting
    base_query = Ad.joins(seller: :seller_tier)
         .joins(:category, :subcategory)
         .where(sellers: { blocked: false, deleted: false }) # Only active sellers

    # Handle status filtering
    # Default to 'all' status when searching, so you can find deleted/flagged items easily
    status = params[:status].presence || (params[:query].present? ? 'all' : 'active')

    case status
    when 'active'
      base_query = base_query.where(flagged: false, deleted: false)
    when 'flagged'
      base_query = base_query.where(flagged: true, deleted: false)
    when 'deleted'
      base_query = base_query.where(deleted: true)
    when 'all'
      # Do nothing, show all including deleted and flagged
    else
      base_query = base_query.where(deleted: false)
    end
    if params[:category_id].present?
      base_query = base_query.where(category_id: params[:category_id])
    end

    if params[:subcategory_id].present?
      base_query = base_query.where(subcategory_id: params[:subcategory_id])
    end

    # Search functionality
    if params[:query].present?
      search_terms = params[:query].downcase.split(/\s+/)
      title_description_conditions = search_terms.map do |term|
        "(LOWER(ads.title) LIKE ? OR LOWER(ads.description) LIKE ?)"
      end.join(" AND ")
      
      base_query = base_query.where(title_description_conditions, *search_terms.flat_map { |term| ["%#{term}%", "%#{term}%"] })
    end

    if params[:added_by].present? && params[:query].blank?
      case params[:added_by]
      when 'sales'
        base_query = base_query.where("#{EFFECTIVE_IS_ADDED_BY_SALES_SQL} = TRUE")
      when 'seller'
        base_query = base_query.where("#{EFFECTIVE_IS_ADDED_BY_SALES_SQL} = FALSE")
      end
    end

    # Get total count before applying select and pagination
    total_count = base_query.count
    
    # Apply select, order, and pagination
    offset = (page - 1) * per_page
    @ads = base_query
         .order('ads.created_at DESC')  # Sort by latest first
         .select("ads.*, seller_tiers.tier_id AS seller_tier, #{EFFECTIVE_IS_ADDED_BY_SALES_SQL} AS derived_is_added_by_sales")
         .limit(per_page)
         .offset(offset)
    
    flagged_ads = @ads.select { |ad| ad.flagged }
    non_flagged_ads = @ads.reject { |ad| ad.flagged }

    render json: {
      flagged: serialize_ads(flagged_ads),
      non_flagged: serialize_ads(non_flagged_ads),
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end
  

  # GET /sales/ads/:id
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
    ad_json = @ad.as_json(include: [:category, :subcategory], methods: [:mean_rating, :media_urls, :first_media_url])
    
    # Add offer information if exists (including scheduled offers for sales view)
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

    # Add seller email for convenience in the sales edit form
    ad_json[:seller_email] = @ad.seller.email
    
    # Render the complete ad data with reviews and buyer details
    render json: {
      **ad_json,
      reviews: reviews.as_json(include: [:buyer]),
      buyer_details: buyer_details
    }
  end

  # PATCH /sales/ads/:id/flag
  def flag
    if @ad.update(flagged: true)
      render json: { status: 'success', message: 'Ad flagged successfully' }
    else
      render json: { status: 'error', message: 'Failed to flag ad' }, status: :unprocessable_entity
    end
  end

  # PATCH /sales/ads/:id/restore
  def restore
    if @ad.update(flagged: false, deleted: false)
      render json: { status: 'success', message: 'Ad restored successfully' }
    else
      render json: { status: 'error', message: 'Failed to restore ad' }, status: :unprocessable_entity
    end
  end

  # PUT /sales/ads/:id
  def update
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
      updated = @ad.update(ad_params.except(:media, :existing_media).merge(media: final_media))
    else
      # No media changes, just update other fields
      updated = @ad.update(ad_params.except(:media, :existing_media))
    end

    if updated
      # Update seller's last active timestamp when updating an ad
      @ad.seller.update_last_active!
      render json: @ad.as_json(include: [:category, :reviews], methods: [:mean_rating])
    else
      render json: { error: @ad.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /sales/ads/:id - Permanent delete
  def destroy
    # Standard destroy performs permanent deletion in this app's architecture
    if @ad.destroy
      render json: { message: "Ad '#{@ad.title}' permanently deleted successfully" }, status: :ok
    else
      render json: { error: "Failed to delete ad permanently", details: @ad.errors.full_messages }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "❌ Error permanently deleting ad: #{e.message}"
    render json: { error: "Internal server error during deletion", details: e.message }, status: :internal_server_error
  end

  # POST /sales/ads/bulk_flag
  def bulk_flag
    ids = Array(params[:ids])
    if ids.empty?
      return render json: { error: 'No ad IDs provided' }, status: :unprocessable_entity
    end

    ads = Ad.where(id: ids)
    count = ads.count
    ads.update_all(flagged: true)
    
    render json: { 
      status: 'success', 
      message: "Successfully flagged #{count} ads",
      affected_count: count
    }
  end

  # POST /sales/ads/bulk_restore
  def bulk_restore
    ids = Array(params[:ids])
    if ids.empty?
      return render json: { error: 'No ad IDs provided' }, status: :unprocessable_entity
    end

    ads = Ad.where(id: ids)
    count = ads.count
    ads.update_all(flagged: false, deleted: false)
    
    render json: { 
      status: 'success', 
      message: "Successfully restored #{count} ads",
      affected_count: count
    }
  end

  # POST /sales/ads/bulk_destroy
  def bulk_destroy
    ids = Array(params[:ids])
    if ids.empty?
      return render json: { error: 'No ad IDs provided' }, status: :unprocessable_entity
    end

    # Use destroy_all to ensure callbacks/associations are handled
    # Though performance might be slightly slower than delete_all
    ads = Ad.where(id: ids)
    count = ads.count
    ads.destroy_all
    
    render json: { 
      status: 'success', 
      message: "Successfully deleted #{count} ads permanently",
      affected_count: count
    }
  end

  # GET /sales/ads/stats
  def stats
    # Use a single efficient SQL query with conditional aggregation
    base_query = Ad.joins(seller: :seller_tier)
             .joins(:category, :subcategory)
             .where(deleted: false)
             .where(sellers: { blocked: false, deleted: false })
    
    # Get the date when explicit sales-added tracking started.
    first_tracked_ad = Ad.where(is_added_by_sales: true)
                         .order('ads.created_at ASC')
                         .select('ads.created_at')
                         .first
    
    tracking_start_date = first_tracked_ad&.created_at&.to_date || Date.today
    
    # Execute a single SQL query with all aggregations
    sql = base_query.select(
      'COUNT(*) as total',
      'SUM(CASE WHEN ads.flagged = true THEN 1 ELSE 0 END) as flagged',
      'SUM(CASE WHEN ads.flagged = false THEN 1 ELSE 0 END) as active',
      "SUM(CASE WHEN #{Ad.effective_is_added_by_sales_sql} = TRUE THEN 1 ELSE 0 END) as sales_added",
      "SUM(CASE WHEN #{Ad.effective_is_added_by_sales_sql} = FALSE THEN 1 ELSE 0 END) as seller_added",
      "SUM(CASE WHEN #{Ad.is_legacy_sales_added_sql} = TRUE THEN 1 ELSE 0 END) as legacy_sales_added",
      "SUM(CASE WHEN #{Ad.is_window_sales_added_sql} = TRUE THEN 1 ELSE 0 END) as window_sales_added",
      "SUM(CASE WHEN #{Ad.is_explicit_sales_added_sql} = TRUE THEN 1 ELSE 0 END) as explicit_sales_added"
    ).unscope(:order).to_sql
    
    result = ActiveRecord::Base.connection.execute(sql).first
    
    get_value = ->(key) { result[key] || result[key.to_sym] || result[key.to_s] }
    
    render json: {
      total: get_value.call('total').to_i,
      active: get_value.call('active').to_i,
      flagged: get_value.call('flagged').to_i,
      sales_added: get_value.call('sales_added').to_i,
      seller_added: get_value.call('seller_added').to_i,
      legacy_sales_added: get_value.call('legacy_sales_added').to_i,
      window_sales_added: get_value.call('window_sales_added').to_i,
      explicit_sales_added: get_value.call('explicit_sales_added').to_i,
      tracking_start_date: tracking_start_date.iso8601
    }
  end

  # GET /sales/ads/flagged
  def flagged
    per_page = params[:per_page]&.to_i || 20
    page = params[:page]&.to_i || 1
    
    base_query = Ad.joins(seller: :seller_tier)
             .joins(:category, :subcategory)
             .where(deleted: false)
             .where(sellers: { blocked: false, deleted: false })
             .where(flagged: true)

    if params[:category_id].present?
      base_query = base_query.where(category_id: params[:category_id])
    end

    if params[:subcategory_id].present?
      base_query = base_query.where(subcategory_id: params[:subcategory_id])
    end

    if params[:query].present?
      search_terms = params[:query].downcase.split(/\s+/)
      title_description_conditions = search_terms.map do |term|
        "(LOWER(ads.title) LIKE ? OR LOWER(ads.description) LIKE ?)"
      end.join(" AND ")

      base_query = base_query.where(
        title_description_conditions,
        *search_terms.flat_map { |term| ["%#{term}%", "%#{term}%"] }
      )
    end
    
    if params[:added_by].present? && params[:query].blank?
      case params[:added_by]
      when 'sales'
        base_query = base_query.where("#{EFFECTIVE_IS_ADDED_BY_SALES_SQL} = TRUE")
      when 'seller'
        base_query = base_query.where("#{EFFECTIVE_IS_ADDED_BY_SALES_SQL} = FALSE")
      end
    end

    total_count = base_query.count
    
    offset = (page - 1) * per_page
    @ads = base_query
             .order('ads.created_at DESC')
             .select("ads.*, seller_tiers.tier_id AS seller_tier, #{EFFECTIVE_IS_ADDED_BY_SALES_SQL} AS derived_is_added_by_sales")
             .limit(per_page)
             .offset(offset)
    
    render json: {
      ads: serialize_ads(@ads),
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  # GET /sales/ads/conditions
  def conditions
    options = Ad.conditions.keys.map do |condition|
      {
        value: condition,
        label: condition.to_s.humanize
      }
    end

    render json: { conditions: options }
  end

  # POST /sales/ads - Create ad on behalf of a seller
  def create
    begin
      seller_email = params[:seller_email]
      
      unless seller_email.present?
        return render json: { error: "Seller email is required" }, status: :unprocessable_entity
      end

      # Find seller by email
      seller = Seller.find_by(email: seller_email)
      
      unless seller
        return render json: { error: "Seller with email #{seller_email} not found. Please ensure the seller has an account." }, status: :not_found
      end

      # Check if seller has an active tier
      seller_tier = seller.seller_tier
      unless seller_tier && seller_tier.tier
        return render json: { error: "Seller does not have an active subscription tier. Please upgrade the seller's account to post ads." }, status: :forbidden
      end

      # Check ad limit
      ad_limit = seller_tier.tier.ads_limit || 0
      current_ads_count = seller.ads.count

      if current_ads_count >= ad_limit
        return render json: { error: "Ad creation limit reached for seller's current tier (#{ad_limit} ads max)." }, status: :forbidden
      end

      # Process and upload images if present
      if params[:ad][:media].present?
        begin
          uploaded_media = process_and_upload_images(params[:ad][:media])
          params[:ad][:media] = uploaded_media
        rescue => e
          Rails.logger.error "❌ Error processing images: #{e.message}"
          return render json: { error: "Failed to process images. Please try again." }, status: :unprocessable_entity
        end
      end

      @ad = seller.ads.build(ad_params)
      @ad.is_added_by_sales = true

      if @ad.save
        seller.update_last_active!
        render json: @ad.as_json(include: [:category, :reviews], methods: [:mean_rating]), status: :created
      else
        render json: { errors: @ad.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "❌ Error creating ad: #{e.message}"
      render json: { error: "Failed to create ad. Please try again." }, status: :internal_server_error
    end
  end

  # POST /sales/ads/:id/offer
  def create_offer
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

        begin
          end_time = DateTime.parse(params[:offer_end_date])
        rescue ArgumentError
          return render json: { 
            error: 'Invalid offer_end_date format' 
          }, status: :unprocessable_entity
        end

        start_time = params[:offer_start_date].present? ? DateTime.parse(params[:offer_start_date]) : DateTime.now rescue DateTime.now

        if end_time <= start_time
          return render json: { 
            error: 'Offer end date must be after start date' 
          }, status: :unprocessable_entity
        end

        offer_type = params[:offer_type].presence || 'limited_time_offer'
        offer_status = params[:offer_status].presence || 'active'
        
        if offer_status == 'active'
          if start_time > DateTime.now
            offer_status = 'scheduled'
          elsif end_time < DateTime.now
            offer_status = 'expired'
          end
        end

        existing_offer_ad = @ad.offer_ads.joins(:offer)
                              .where(is_active: true)
                              .where('offers.end_time > ?', DateTime.now)
                              .first

        if existing_offer_ad
          offer = existing_offer_ad.offer
          offer.update!(
            description: params[:offer_description].presence || offer.description,
            offer_type: offer_type,
            start_time: start_time,
            end_time: end_time,
            status: offer_status,
            discount_percentage: discount
          )
          
          existing_offer_ad.update!(
            discount_percentage: discount,
            original_price: @ad.price,
            discounted_price: @ad.price * (1 - discount / 100.0),
            seller_notes: params[:offer_description]
          )
        else
          offer_name = params[:offer_name].presence || "#{@ad.title.truncate(30)} - Special Offer"
          offer = @ad.seller.offers.create!(
            name: offer_name,
            description: params[:offer_description].presence || "Special discount on #{@ad.title}",
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

          OfferAd.create!(
            offer: offer,
            ad: @ad,
            discount_percentage: discount,
            original_price: @ad.price,
            discounted_price: @ad.price * (1 - discount / 100.0),
            is_active: true,
            seller_notes: params[:offer_description]
          )
        end

        @ad.reload
        active_offer_ad = @ad.offer_ads.joins(:offer)
                            .where(is_active: true)
                            .where('offers.end_time > ?', DateTime.now)
                            .includes(:offer)
                            .first

        ad_json = @ad.as_json(include: [:category, :subcategory], methods: [:mean_rating])
        
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
    rescue => e
      Rails.logger.error "Error creating offer: #{e.message}"
      render json: { error: 'Failed to create offer' }, status: :internal_server_error
    end
  end

  # DELETE /sales/ads/:id/offer
  def remove_offer
    begin
      offer_ad = @ad.offer_ads.joins(:offer)
                    .where(is_active: true)
                    .where('offers.end_time > ?', DateTime.now)
                    .first

      if offer_ad
        offer_ad.update!(is_active: false)
        offer = offer_ad.offer
        offer.update!(status: 'paused') if offer.offer_ads.where(is_active: true).count == 0
      end

      render json: @ad.as_json(include: [:category, :subcategory], methods: [:mean_rating]), status: :ok
    rescue => e
      Rails.logger.error "Error removing offer: #{e.message}"
      render json: { error: 'Failed to remove offer' }, status: :internal_server_error
    end
  end

  private

  def serialize_ads(ads)
    ads.map do |ad|
      ad.as_json(methods: :seller_tier)
        .merge("is_added_by_sales" => ad.respond_to?(:derived_is_added_by_sales) ? ad.derived_is_added_by_sales : ad.effective_is_added_by_sales)
    end
  end

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def set_ad
    @ad = Ad.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ad not found' }, status: :not_found
  end

  def ad_params
    permitted = params.require(:ad).permit(
      :title, :description, :category_id, :subcategory_id, :price, 
      :brand, :manufacturer, :item_length, :item_width, :model, :specifications,
      :item_height, :item_weight, :weight_unit, :flagged, :condition,
      media: [], existing_media: []
    )

    %i[item_length item_width item_height item_weight].each do |field|
      permitted[field] = nil if params[:ad].key?(field) && permitted[field].blank?
    end

    if params[:ad].key?(:weight_unit)
      permitted[:weight_unit] = 'Grams' if permitted[:weight_unit].blank? || !['Grams', 'Kilograms'].include?(permitted[:weight_unit])
    end

    permitted
  end

  def process_and_upload_images(images)
    uploaded_urls = []
    Array(images).each do |image|
      begin
        next unless image.tempfile && File.exist?(image.tempfile.path)
        raise "UPLOAD_PRESET not configured" unless ENV['UPLOAD_PRESET'].present?
        
        uploaded_image = Cloudinary::Uploader.upload(image.tempfile.path, upload_preset: ENV['UPLOAD_PRESET'])
        uploaded_urls << uploaded_image["secure_url"]
      rescue => e
        Rails.logger.error "❌ Error uploading image: #{e.message}"
      end
    end
    uploaded_urls
  end
end
