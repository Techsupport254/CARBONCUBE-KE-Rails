class Seller::AdsController < ApplicationController
  include ExceptionHandler
  
  before_action :authenticate_seller, except: [:prefill]
  before_action :set_ad, only: [:show, :update, :destroy]
  before_action :load_ad_with_offer, only: [:show]


  # app/controllers/seller/ads_controller.rb
  def index
    active_ads = current_seller.ads.active.includes(:category, :reviews)
    deleted_ads = current_seller.ads.deleted.includes(:category, :reviews)

    # Get device_hash if available to exclude seller's own clicks
    device_hash = params[:device_hash] || request.headers['X-Device-Hash']
    
    # Get click event stats for all ads
    active_ads_with_stats = add_click_event_stats(active_ads, device_hash)
    deleted_ads_with_stats = add_click_event_stats(deleted_ads, device_hash)

    render json: {
      active_ads: active_ads_with_stats,
      deleted_ads: deleted_ads_with_stats
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

  # GET /seller/ads/conditions
  def conditions
    condition_options = Ad.conditions.keys.map do |condition|
      {
        value: condition,
        label: condition.to_s.humanize
      }
    end

    render json: { conditions: condition_options }
  end

  # GET /seller/ads/prefill
  # Category-aware prefill for add/edit forms using existing catalog ads.
  def prefill
    model_query = params[:model].presence || params[:title].presence || params[:query].presence
    return render json: { error: 'model, title, or query is required' }, status: :unprocessable_entity if model_query.blank?

    category = Category.find_by(id: params[:category_id])
    subcategory = Subcategory.find_by(id: params[:subcategory_id])
    if subcategory.present? && category.present? && subcategory.category_id != category.id
      return render json: { error: 'subcategory does not belong to selected category' }, status: :unprocessable_entity
    end

    strategy = prefill_strategy_for(category&.name, subcategory&.name)
    candidates = prefill_candidates_for(
      query: model_query,
      category_id: category&.id,
      subcategory_id: subcategory&.id,
      strategy: strategy
    )

    if candidates.empty? && subcategory.present?
      # Fallback from subcategory to category scope to avoid empty responses.
      candidates = prefill_candidates_for(
        query: model_query,
        category_id: category&.id,
        subcategory_id: nil,
        strategy: strategy
      )
    end

    # Fetch Specifications (Favoring local catalog for speed)
    gsm_specs = nil
    if strategy == 'phones_computers' || (category&.name.to_s.downcase.include?('phone'))
      matching_phones = DeviceCatalogService.search(model_query, subcategory&.name)
      if matching_phones.any?
        best = matching_phones.first
        gsm_specs = {
          title: best['title'],
          brand: best['brand'],
          specifications: best['specifications'] || {}
        }
      elsif subcategory&.name.to_s.downcase.match?(/phone|mobile|tablet|ipad/i)
        # Fallback to external scraping if not found in local catalog, only for mobiles
        gsm_specs = GsmArenaService.fetch_device_specs(model_query)
      end
    end

    ranked_candidates = rank_prefill_candidates(candidates, model_query)
    best_match = ranked_candidates.first

    brand_options = top_prefill_values(ranked_candidates.map(&:brand))
    manufacturer_options = top_prefill_values(ranked_candidates.map(&:manufacturer))
    price_stats = build_price_stats(ranked_candidates)

    render json: {
      strategy: strategy,
      confidence: prefill_confidence(best_match, ranked_candidates.length),
      total_matches: ranked_candidates.length,
      suggestions: {
        title: gsm_specs&.dig(:title) || best_match&.title,
        brand: gsm_specs&.dig(:brand) || best_match&.brand.presence || brand_options.first,
        manufacturer: best_match&.manufacturer.presence || manufacturer_options.first,
        description: build_prefill_description(
          model_query: model_query,
          category_name: category&.name,
          subcategory_name: subcategory&.name,
          strategy: strategy,
          best_match: best_match
        ),
        price: price_stats[:median],
        specifications: gsm_specs&.dig(:specifications) || {}
      },
      options: {
        brands: brand_options,
        manufacturers: manufacturer_options,
        catalog_suggestions: DeviceCatalogService.search(model_query, subcategory&.name).map { |p| { title: p['title'], slug: p['slug'], brand: p['brand'] } }
      },
      price_stats: price_stats
    }
  end

  def create
    begin
      
      seller_tier = current_seller.seller_tier

      unless seller_tier && seller_tier.tier
        Rails.logger.error "❌ No active subscription tier for seller #{current_seller.id}"
        return render json: { error: "You do not have an active subscription tier. Please upgrade your account to post ads." }, status: :forbidden
      end

      ad_limit = seller_tier.tier.ads_limit || 0
      current_ads_count = current_seller.ads.count

      if current_ads_count >= ad_limit
        Rails.logger.error "❌ Ad limit reached for seller #{current_seller.id}: #{current_ads_count}/#{ad_limit}"
        return render json: { error: "Ad creation limit reached for your current tier (#{ad_limit} ads max)." }, status: :forbidden
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
      else
      end

      @ad = current_seller.ads.build(ad_params)
      @ad.is_added_by_sales = false # Set to false when seller creates ad themselves

      if @ad.save
        # Update seller's last active timestamp when creating an ad
        current_seller.update_last_active!
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

  def prefill_strategy_for(category_name, subcategory_name)
    text = [category_name, subcategory_name].compact.join(' ').downcase
    return 'phones_computers' if text.match?(/phone|mobile|laptop|computer|tablet|ipad|network|storage|peripheral|tv|television|smart tv/i)
    return 'automotive' if text.match?(/automotive|tyre|battery|spare|lubricant/i)
    return 'filtration' if text.match?(/filter|filtration/i)
    return 'hardware_tools' if text.match?(/hardware|tool|electrical|plumbing|safety/i)
    return 'equipment_leasing' if text.match?(/equipment|leasing|earth moving|drilling|lifting|concrete|compacting/i)

    'general'
  end

  def prefill_candidates_for(query:, category_id:, subcategory_id:, strategy:)
    normalized_query = query.to_s.strip.downcase
    tokens = normalized_query.split(/\s+/).reject(&:blank?)
    like_query = "%#{normalized_query}%"

    scope = Ad.active
              .from_active_sellers
              .where(ads: { flagged: false })
              .where.not(title: [nil, ''])
              .select(:title, :brand, :manufacturer, :description, :price, :category_id, :subcategory_id)

    scope = scope.where(category_id: category_id) if category_id.present?
    scope = scope.where(subcategory_id: subcategory_id) if subcategory_id.present?

    case strategy
    when 'phones_computers'
      scope = scope.where(
        "LOWER(ads.title) LIKE :q OR LOWER(COALESCE(ads.brand, '')) LIKE :q OR LOWER(COALESCE(ads.manufacturer, '')) LIKE :q",
        q: like_query
      )
    when 'automotive', 'hardware_tools', 'filtration'
      scope = scope.where(
        "LOWER(ads.title) LIKE :q OR LOWER(COALESCE(ads.description, '')) LIKE :q OR LOWER(COALESCE(ads.brand, '')) LIKE :q",
        q: like_query
      )
    else
      scope = scope.where(
        "LOWER(ads.title) LIKE :q OR LOWER(COALESCE(ads.description, '')) LIKE :q OR LOWER(COALESCE(ads.brand, '')) LIKE :q OR LOWER(COALESCE(ads.manufacturer, '')) LIKE :q",
        q: like_query
      )
    end

    tokens.each do |token|
      scope = scope.where(
        "LOWER(ads.title) LIKE :t OR LOWER(COALESCE(ads.brand, '')) LIKE :t OR LOWER(COALESCE(ads.manufacturer, '')) LIKE :t",
        t: "%#{token}%"
      )
    end

    scope.limit(60).to_a
  end

  def rank_prefill_candidates(candidates, query)
    normalized_query = query.to_s.downcase.strip
    tokens = normalized_query.split(/\s+/).reject(&:blank?)

    candidates.sort_by do |ad|
      title = ad.title.to_s.downcase
      token_hits = tokens.count { |token| title.include?(token) }
      exact_bonus = title.include?(normalized_query) ? 1 : 0
      score = (token_hits * 10) + (exact_bonus * 20)
      -score
    end
  end

  def top_prefill_values(values)
    values
      .map { |value| value.to_s.strip }
      .reject(&:blank?)
      .group_by(&:itself)
      .sort_by { |_value, group| -group.length }
      .map(&:first)
      .first(5)
  end

  def build_price_stats(candidates)
    prices = candidates
             .map { |ad| ad.price.to_f }
             .select { |price| price.positive? }
             .sort

    return { min: nil, max: nil, median: nil } if prices.empty?

    middle = prices.length / 2
    median = if prices.length.odd?
      prices[middle]
    else
      (prices[middle - 1] + prices[middle]) / 2.0
    end

    {
      min: prices.first.round(2),
      max: prices.last.round(2),
      median: median.round(2)
    }
  end

  def prefill_confidence(best_match, total_matches)
    return 'low' if best_match.blank? || total_matches <= 1
    return 'high' if total_matches >= 8

    'medium'
  end

  def build_prefill_description(model_query:, category_name:, subcategory_name:, strategy:, best_match:)
    return best_match.description.to_s.strip if best_match&.description.to_s.strip.length >= 120

    category_label = category_name.presence || 'Product'
    subcategory_label = subcategory_name.presence || 'General'
    model_label = model_query.to_s.strip

    opening = case strategy
    when 'phones_computers'
      "### #{model_label} - #{subcategory_label}\n\nReliable #{subcategory_label.downcase} from #{category_label.downcase}, suitable for daily use, business, and long-term performance."
    when 'automotive'
      "### #{model_label} - #{subcategory_label}\n\nQuality #{subcategory_label.downcase} designed for dependable performance in demanding automotive use."
    when 'filtration'
      "### #{model_label} - #{subcategory_label}\n\nHigh-quality #{subcategory_label.downcase} built for efficient filtration and long service life."
    when 'hardware_tools'
      "### #{model_label} - #{subcategory_label}\n\nDurable #{subcategory_label.downcase} suitable for workshop, site, and professional use."
    when 'equipment_leasing'
      "### #{model_label} - #{subcategory_label}\n\nWell-maintained #{subcategory_label.downcase} available for project-based and long-term operational needs."
    else
      "### #{model_label} - #{subcategory_label}\n\nQuality #{subcategory_label.downcase} in the #{category_label.downcase} segment."
    end

    "#{opening}\n\n- Key features and condition details available on request.\n- Suitable for buyers seeking value, reliability, and verified seller support.\n- Contact seller for delivery options, warranty terms, and availability."
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
  # Add click event statistics to ads
  def add_click_event_stats(ads, device_hash = nil)
    return [] if ads.empty?
    
    ad_ids = ads.map(&:id)
    
    # Get click event counts grouped by ad_id and event_type
    # Note: We don't filter by deleted status here since we want stats for all ads (including deleted ones)
    click_stats = ClickEvent
      .excluding_internal_users
      .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
      .where(ad_id: ad_ids)
      .left_joins(:buyer)
      .where("buyers.id IS NULL OR buyers.deleted = ?", false)
      .group(:ad_id, :event_type)
      .count
    
    # Get wishlist counts (include deleted ads for historical data)
    wishlist_counts = WishList
      .joins(:ad)
      .where(ads: { id: ad_ids })
      .group(:ad_id)
      .count
    
    # Get contact interaction stats
    contact_interaction_events = ClickEvent
      .excluding_internal_users
      .excluding_seller_own_clicks(device_hash: device_hash, seller_id: current_seller.id)
      .where(ad_id: ad_ids, event_type: 'Reveal-Seller-Details')
      .where("metadata->>'action' = ?", 'seller_contact_interaction')
      .left_joins(:buyer)
      .where("buyers.id IS NULL OR buyers.deleted = ?", false)
    
    copy_clicks = contact_interaction_events
      .where("metadata->>'action_type' IN ('copy_phone', 'copy_email')")
      .group(:ad_id)
      .count
    
    call_clicks = contact_interaction_events
      .where("metadata->>'action_type' = ?", 'call_phone')
      .group(:ad_id)
      .count
    
    whatsapp_clicks = contact_interaction_events
      .where("metadata->>'action_type' = ?", 'whatsapp')
      .group(:ad_id)
      .count
    
    location_clicks = contact_interaction_events
      .where("metadata->>'action_type' = ?", 'view_location')
      .group(:ad_id)
      .count
    
    # Build stats hash for each ad
    ads.map do |ad|
      ad_json = ad.as_json(include: [:category, :reviews], methods: [:mean_rating])
      
      # Extract click event counts
      ad_clicks = click_stats.select { |(ad_id, event_type), _| ad_id == ad.id && event_type == 'Ad-Click' }.values.sum || 0
      reveal_clicks = click_stats.select { |(ad_id, event_type), _| ad_id == ad.id && event_type == 'Reveal-Seller-Details' }.values.sum || 0
      wishlist_clicks = click_stats.select { |(ad_id, event_type), _| ad_id == ad.id && event_type == 'Add-to-Wish-List' }.values.sum || 0
      cart_clicks = click_stats.select { |(ad_id, event_type), _| ad_id == ad.id && event_type == 'Add-to-Cart' }.values.sum || 0
      wishlist_count = wishlist_counts[ad.id] || 0
      
      # Add stats to ad JSON
      ad_json.merge(
        ad_clicks: ad_clicks,
        reveal_clicks: reveal_clicks,
        wishlist_clicks: wishlist_clicks,
        cart_clicks: cart_clicks,
        wishlist_count: wishlist_count,
        copy_clicks: copy_clicks[ad.id] || 0,
        call_clicks: call_clicks[ad.id] || 0,
        whatsapp_clicks: whatsapp_clicks[ad.id] || 0,
        location_clicks: location_clicks[ad.id] || 0
      )
    end
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
