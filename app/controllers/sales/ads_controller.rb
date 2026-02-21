class Sales::AdsController < ApplicationController
  before_action :authenticate_sales_user
  
  # GET /sales/ads
  def index
    per_page = params[:per_page]&.to_i || 20
    page = params[:page]&.to_i || 1
    
    # Build base query without select for counting
    base_query = Ad.joins(seller: :seller_tier)
         .joins(:category, :subcategory)
         .where(sellers: { blocked: false, deleted: false }) # Only active sellers

    # Handle status filtering
    if params[:status].present?
      case params[:status]
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
    else
      # Default: show non-deleted ads
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

    if params[:added_by].present?
      case params[:added_by]
      when 'sales'
        base_query = base_query.where(is_added_by_sales: true)
      when 'seller'
        base_query = base_query.where(is_added_by_sales: false)
      end
    end

    # Get total count before applying select and pagination
    total_count = base_query.count
    
    # Apply select, order, and pagination
    offset = (page - 1) * per_page
    @ads = base_query
         .order('ads.created_at DESC')  # Sort by latest first
         .select('ads.*, seller_tiers.tier_id AS seller_tier')  # Select tier_id from seller_tiers
         .limit(per_page)
         .offset(offset)
    
    flagged_ads = @ads.select { |ad| ad.flagged }
    non_flagged_ads = @ads.reject { |ad| ad.flagged }

    render json: {
      flagged: flagged_ads.as_json(methods: :seller_tier),
      non_flagged: non_flagged_ads.as_json(methods: :seller_tier),
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end
  

  def show
    @ad = Ad.includes(:seller, :category, :subcategory, :reviews => :buyer)
                      .find(params[:id])
                      .tap do |ad|
                        ad.define_singleton_method(:mean_rating) do
                          # Use cached reviews if available, otherwise calculate
                          if reviews.loaded?
                            reviews.any? ? reviews.sum(&:rating).to_f / reviews.size : 0.0
                          else
                            reviews.average(:rating).to_f
                          end
                        end
                      end
    render json: @ad.as_json(
      include: {
        seller: { only: [:fullname, :email] },
        category: { only: [:name] },
        subcategory: { only: [:name] },
        reviews: {
          include: {
            buyer: { only: [:fullname] }
          },
          only: [:rating, :review, :created_at]
        }
      },
      methods: [:mean_rating, :media_urls, :first_media_url],
      except: [:deleted]
    )
  end

  # Update flagged status
  def flag
    @ad = Ad.find(params[:id])
    @ad.update(flagged: true)  # Set flagged to true
    head :no_content
  end

  # Update flagged status
  def restore
    @ad = Ad.find(params[:id])
    @ad.update(flagged: false, deleted: false)
    head :no_content
  end

  # DELETE /sales/ads/:id - Permanent delete
  def destroy
    begin
      @ad = Ad.find(params[:id])
      # Standard destroy performs permanent deletion in this app's architecture
      # unless specific soft-delete logic is added to the model
      if @ad.destroy
        render json: { message: "Ad '#{@ad.title}' permanently deleted successfully" }, status: :ok
      else
        render json: { error: "Failed to delete ad permanently", details: @ad.errors.full_messages }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Ad not found" }, status: :not_found
    rescue => e
      Rails.logger.error "❌ Error permanently deleting ad: #{e.message}"
      render json: { error: "Internal server error during deletion", details: e.message }, status: :internal_server_error
    end
  end

  # GET /sales/ads/stats
  def stats
    # Use a single efficient SQL query with conditional aggregation
    # This performs all counts in one database query instead of multiple queries
    base_query = Ad.joins(seller: :seller_tier)
             .joins(:category, :subcategory)
             .where(deleted: false)
             .where(sellers: { blocked: false, deleted: false })
    
    # Get the date when tracking started (first ad with is_added_by_sales not null)
    first_tracked_ad = Ad.where.not(is_added_by_sales: nil)
                         .order('ads.created_at ASC')
                         .select('ads.created_at')
                         .first
    
    tracking_start_date = first_tracked_ad&.created_at&.to_date || Date.today
    
    # Execute a single SQL query with all aggregations
    sql = base_query.select(
      'COUNT(*) as total',
      'SUM(CASE WHEN ads.flagged = true THEN 1 ELSE 0 END) as flagged',
      'SUM(CASE WHEN ads.flagged = false THEN 1 ELSE 0 END) as active',
      'SUM(CASE WHEN ads.is_added_by_sales = true THEN 1 ELSE 0 END) as sales_added',
      'SUM(CASE WHEN ads.is_added_by_sales = false THEN 1 ELSE 0 END) as seller_added'
    ).unscope(:order).to_sql
    
    result = ActiveRecord::Base.connection.execute(sql).first
    
    # Handle both string and symbol keys (different database adapters)
    get_value = ->(key) { result[key] || result[key.to_sym] || result[key.to_s] }
    
    render json: {
      total: get_value.call('total').to_i,
      active: get_value.call('active').to_i,
      flagged: get_value.call('flagged').to_i,
      sales_added: get_value.call('sales_added').to_i,
      seller_added: get_value.call('seller_added').to_i,
      tracking_start_date: tracking_start_date.iso8601
    }
  end

  # GET /sales/ads/flagged
  def flagged
    per_page = params[:per_page]&.to_i || 20
    page = params[:page]&.to_i || 1
    
    # Build base query without select for counting
    base_query = Ad.joins(seller: :seller_tier)
             .joins(:category, :subcategory)
             .where(deleted: false)
             .where(sellers: { blocked: false, deleted: false })
             .where(flagged: true)

    # Apply same filters as index (category, subcategory, search)
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
    
    # Filter by who added the ad (sales vs seller) if requested
    if params[:added_by].present?
      case params[:added_by]
      when 'sales'
        base_query = base_query.where(is_added_by_sales: true)
      when 'seller'
        base_query = base_query.where(is_added_by_sales: false)
      end
    end

    # Get total count before applying select and pagination
    total_count = base_query.count
    
    # Apply select, order, and pagination
    offset = (page - 1) * per_page
    @ads = base_query
             .order('ads.created_at DESC')  # Sort by latest first
             .select('ads.*, seller_tiers.tier_id AS seller_tier')
             .limit(per_page)
             .offset(offset)
    
    render json: {
      ads: @ads.as_json(methods: :seller_tier),
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
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
          Rails.logger.error e.backtrace.join("\n")
          return render json: { error: "Failed to process images. Please try again." }, status: :unprocessable_entity
        end
      end

      @ad = seller.ads.build(ad_params)
      @ad.is_added_by_sales = true # Set to true when sales team creates ad

      if @ad.save
        # Update seller's last active timestamp when creating an ad
        seller.update_last_active!
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

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_sales_user
    @current_sales_user
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

  def process_and_upload_images(images)
    uploaded_urls = []

    begin
      Array(images).each do |image|
        begin
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
          uploaded_image = Cloudinary::Uploader.upload(
            image.tempfile.path,
            upload_preset: ENV['UPLOAD_PRESET']
          )

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

    uploaded_urls
  end
end
