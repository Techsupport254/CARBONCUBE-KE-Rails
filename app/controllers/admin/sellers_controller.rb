class Admin::SellersController < ApplicationController
  before_action :authenticate_admin_or_sales, only: [:index, :show]
  before_action :authenticate_admin, except: [:index, :show]
  before_action :set_seller, only: [:block, :unblock, :flag, :unflag, :show, :update, :destroy, :analytics, :orders, :ads, :reviews]

  def index
    # Base query - show all sellers including deleted, flagged, and blocked
    sellers_query = Seller.unscoped
    
    # Enhanced search functionality
    if params[:query].present?
      search_term = params[:query].strip
      sellers_query = sellers_query.where(
        "fullname ILIKE :search OR 
         phone_number ILIKE :search OR 
         email ILIKE :search OR 
         enterprise_name ILIKE :search OR 
         location ILIKE :search OR 
         id::text = :exact_search",
        search: "%#{search_term}%",
        exact_search: search_term
      )
    end
    
    # Filter by status
    if params[:status].present?
      case params[:status]
      when 'active'
        sellers_query = sellers_query.where(blocked: false, deleted: false, flagged: false)
      when 'blocked'
        sellers_query = sellers_query.where(blocked: true)
      when 'deleted'
        sellers_query = sellers_query.where(deleted: true)
      when 'flagged'
        sellers_query = sellers_query.where(flagged: true)
      when 'all'
        # Show all - no filter (already using unscoped)
      end
    else
      # Default: show all sellers when no filter is selected
      # (already using unscoped, so this is fine)
    end
    
    # Sorting - default to last_active_at desc to show most recently active users first
    sort_by = params[:sort_by] || 'last_active_at'
    sort_order = params[:sort_order] || 'desc'
    
    # Validate sort parameters
    allowed_sort_fields = %w[id fullname email enterprise_name location created_at updated_at last_active_at]
    allowed_sort_orders = %w[asc desc]
    
    sort_by = 'id' unless allowed_sort_fields.include?(sort_by)
    sort_order = 'asc' unless allowed_sort_orders.include?(sort_order)
    
    # Handle sorting - use last_active_at instead of last_activity
    sort_by = 'last_active_at' if sort_by == 'last_activity'
    sellers_query = sellers_query.order("#{sort_by} #{sort_order}")
    
    # Pagination
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    
    # Validate pagination parameters
    page = 1 if page < 1
    per_page = [per_page, 100].min # Max 100 per page
    per_page = 20 if per_page < 1
    
    total_count = sellers_query.count
    offset = (page - 1) * per_page
    
    @sellers = sellers_query.limit(per_page).offset(offset)
    
    # Cutoff for onboarding classification (sellers before this had no Carbon code option)
    carbon_code_cutoff = Time.zone.parse('2026-02-01').beginning_of_day

    # Prepare sellers data with last_active_at, carbon_code, and onboarding_type
    @sellers_data = @sellers.map do |seller|
      row = seller.as_json(only: [:id, :fullname, :phone_number, :email, :enterprise_name, :location, :blocked, :deleted, :flagged, :created_at, :updated_at, :last_active_at, :profile_picture, :provider, :carbon_code_id], include: { carbon_code: { only: [:id, :code, :label] } })
      row['onboarding_type'] = if seller.carbon_code_id.present?
        'added_by_sales'
      elsif seller.created_at && seller.created_at >= carbon_code_cutoff
        'self_onboarded'
      else
        'legacy'
      end
      row
    end
    
    # Calculate pagination metadata
    total_pages = (total_count.to_f / per_page).ceil
    has_next_page = page < total_pages
    has_prev_page = page > 1
    
    render json: {
      sellers: @sellers_data,
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: total_pages,
        has_next_page: has_next_page,
        has_prev_page: has_prev_page,
        next_page: has_next_page ? page + 1 : nil,
        prev_page: has_prev_page ? page - 1 : nil
      }
    }
  end
  

  def show
    seller_data = @seller.as_json(
      only: [
        :id, :fullname, :username, :description, :phone_number, :email, 
        :enterprise_name, :location, :blocked, :profile_picture, :zipcode, 
        :city, :gender, :business_registration_number, :document_url,
        :document_verified, :document_expiry_date, :created_at, :updated_at,
        :last_active_at, :deleted, :provider, :uid, :ads_count, :carbon_code_id
      ],
      methods: [:category_names],
      include: {
        county: { only: [:id, :name, :capital, :county_code] },
        sub_county: { only: [:id, :name] },
        age_group: { only: [:id, :name] },
        document_type: { only: [:id, :name] },
        tier: { only: [:id, :name] },
        carbon_code: { only: [:id, :code, :label] }
      }
    )
    analytics_data = fetch_analytics(@seller)
    seller_data.merge!(analytics: analytics_data)
    render json: seller_data
  end

  def create
    @seller = Seller.new(seller_params)
    if @seller.save
      # Ensure every seller has a tier (admin-created sellers get Free by default)
      assign_default_tier_for_seller(@seller) if @seller.seller_tier.blank?
      render json: @seller.as_json(only: [:id, :fullname, :enterprise_name, :location, :blocked]), status: :created
    else
      render json: @seller.errors, status: :unprocessable_entity
    end
  end

  def update
    if @seller.update(seller_params)
      render json: @seller.as_json(only: [:id, :fullname, :phone_number, :email, :enterprise_name, :location, :blocked])
    else
      render json: @seller.errors, status: :unprocessable_entity
    end
  end

  def verify_document
    seller = Seller.find(params[:id])
    seller.update(document_verified: true)
    render json: { message: 'Seller document verified.' }, status: :ok
  end

  def destroy
    @seller.destroy
    head :no_content
  end

  def reviews
    reviews = @seller.reviews.joins(:ad, :buyer)
                           .where(ads: { id: @seller.ads.pluck(:id) })
                           .select('reviews.*, buyers.fullname AS buyer_name, ads.title AS ad_title')
    render json: reviews.as_json(only: [:id, :rating, :review, :created_at],
                                 methods: [:buyer_name, :ad_title])
  end
  

  def ads
    ads = @seller.ads
    render json: ads
  end

  def block
    if @seller
      mean_rating = @seller.reviews.average(:rating).to_f

      if mean_rating < 3.0
        if @seller.update(blocked: true)
          render json: @seller.as_json(only: [:id, :fullname, :enterprise_name, :location, :blocked]), status: :ok
        else
          render json: @seller.errors, status: :unprocessable_entity
        end
      else
        render json: { error: 'Seller cannot be blocked because their mean rating is above 3.0' }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Seller not found' }, status: :not_found
    end
  end

  def unblock
    if @seller
      if @seller.update(blocked: false)
        render json: @seller.as_json(only: [:id, :fullname, :enterprise_name, :location, :blocked]), status: :ok
      else
        render json: @seller.errors, status: :unprocessable_entity
      end
    else
      render json: { error: 'Seller not found' }, status: :not_found
    end
  end

  def flag
    if @seller
      if @seller.update(flagged: true)
        render json: @seller.as_json(only: [:id, :fullname, :enterprise_name, :location, :flagged]), status: :ok
      else
        render json: @seller.errors, status: :unprocessable_entity
      end
    else
      render json: { error: 'Seller not found' }, status: :not_found
    end
  end

  def unflag
    if @seller
      if @seller.update(flagged: false)
        render json: @seller.as_json(only: [:id, :fullname, :enterprise_name, :location, :flagged]), status: :ok
      else
        render json: @seller.errors, status: :unprocessable_entity
      end
    else
      render json: { error: 'Seller not found' }, status: :not_found
    end
  end

  def bulk_actions
    action = params[:action_type]
    seller_ids = params[:seller_ids] || []
    
    if seller_ids.empty?
      render json: { error: 'No sellers selected' }, status: :bad_request
      return
    end

    # Ensure seller_ids is an array and filter out any nil/empty values
    seller_ids = Array(seller_ids).compact.reject(&:blank?)
    
    if seller_ids.empty?
      render json: { error: 'No valid seller IDs provided' }, status: :bad_request
      return
    end

    # Normalize seller_ids to strings for UUID comparison
    seller_ids_normalized = seller_ids.map(&:to_s).reject(&:blank?)
    
    # Find all sellers - use unscoped to include deleted/blocked sellers
    sellers = Seller.unscoped.where(id: seller_ids_normalized)
    found_ids = sellers.pluck(:id).map(&:to_s)
    missing_ids = seller_ids_normalized - found_ids
    
    updated_count = 0
    errors = []

    # Log for debugging
    Rails.logger.info "Bulk action '#{action}' - Requested IDs: #{seller_ids_normalized.inspect}"
    Rails.logger.info "Bulk action '#{action}' - Found #{sellers.count} sellers"
    Rails.logger.info "Bulk action '#{action}' - Found IDs: #{found_ids.inspect}"
    Rails.logger.info "Bulk action '#{action}' - Missing IDs: #{missing_ids.inspect}" if missing_ids.any?

    if sellers.empty?
      errors << "No sellers found with the provided IDs"
      render json: {
        message: "Bulk action '#{action}' failed",
        updated_count: 0,
        total_selected: seller_ids_normalized.count,
        found_count: 0,
        missing_count: missing_ids.count,
        errors: errors
      }, status: :not_found
      return
    end

    # Use update_all for better performance and reliability
    begin
      case action
      when 'flag'
        updated_count = sellers.update_all(flagged: true, updated_at: Time.current)
        Rails.logger.info "Flagged #{updated_count} sellers"
      when 'unflag'
        updated_count = sellers.update_all(flagged: false, updated_at: Time.current)
        Rails.logger.info "Unflagged #{updated_count} sellers"
      when 'block'
        updated_count = sellers.update_all(blocked: true, updated_at: Time.current)
        Rails.logger.info "Blocked #{updated_count} sellers"
      when 'unblock'
        updated_count = sellers.update_all(blocked: false, updated_at: Time.current)
        Rails.logger.info "Unblocked #{updated_count} sellers"
      else
        errors << "Unknown action: #{action}"
      end
    rescue => e
      errors << "Failed to perform bulk action: #{e.message}"
      Rails.logger.error "Bulk action error: #{e.class.name} - #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
    end

    # Add errors for missing sellers
    if missing_ids.any?
      errors << "Sellers not found: #{missing_ids.join(', ')}"
    end

    render json: {
      message: "Bulk action '#{action}' completed",
      updated_count: updated_count,
      total_selected: seller_ids_normalized.count,
      found_count: sellers.count,
      missing_count: missing_ids.count,
      errors: errors
    }
  end

  def analytics
    analytics_data = fetch_analytics(@seller)
    render json: analytics_data
  end

  def orders
  
    orders = @seller.orders.includes(order_items: [:ad, :order], buyer: :orders)
                          .where(order_items: { ad_id: @seller.ads.pluck(:id) })
  
    filtered_orders = orders.map do |order|
      {
        id: order.id,
        status: order.status,
        total_amount: order.total_amount,
        processing_fee: order.processing_fee,
        delivery_fee: order.delivery_fee,
        created_at: order.created_at,
        updated_at: order.updated_at,
        mpesa_transaction_code: order.mpesa_transaction_code,
        buyer: {
          id: order.buyer.id,
          fullname: order.buyer.fullname,
          email: order.buyer.email,
          phone_number: order.buyer.phone_number
        },
        order_items: order.order_items
                          .select { |item| @seller.ads.exists?(item.ad_id) }
                          .map do |item|
          {
            id: item.id,
            quantity: item.quantity,
            price: item.price,
            total_price: item.total_price,
            ad: {
              id: item.ad.id,
              title: item.ad.title,
              seller_id: item.ad.seller_id,
              price: item.ad.price
            }
          }
        end
      }
    end
  
    render json: filtered_orders, status: :ok
  end

  private

  def assign_default_tier_for_seller(seller)
    free_tier = Tier.find_by(name: 'Free') || Tier.find_by(id: 1) || Tier.first
    return unless free_tier
    SellerTier.create!(seller: seller, tier: free_tier, duration_months: 0)
    Rails.logger.info "✅ Default (Free) tier assigned to admin-created seller #{seller.id}"
  end

  def set_seller
    @seller = Seller.find(params[:id])
  end

  def seller_params
    params.require(:seller).permit(:fullname, :phone_number, :email, :enterprise_name, :location, :password, :business_registration_number, category_ids: [])
  end

  def authenticate_admin_or_sales
    begin
      @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    rescue ExceptionHandler::InvalidToken, ExceptionHandler::MissingToken
      @current_user = SalesAuthorizeApiRequest.new(request.headers).result
    end
    unless @current_user && (@current_user.is_a?(Admin) || @current_user.is_a?(SalesUser))
      render json: { error: 'Not Authorized' }, status: :unauthorized
      return
    end
  end

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end


  def most_clicked_ad(seller)
    most_clicked = ClickEvent.where(ad_id: seller.ads.pluck(:id))
                             .group(:ad_id)
                             .order('count_id DESC')
                             .limit(1)
                             .count(:id)
                             .first
  
    if most_clicked
      ad = Ad.find(most_clicked[0])
      {
        ad_id: ad.id,
        title: ad.title,
        total_clicks: most_clicked[1],
        category: ad.category.name
      }
    else
      nil
    end
  end
  
  def fetch_analytics(seller)
    seller_ads = seller.ads
    ad_ids = seller_ads.pluck(:id)
    click_events = ClickEvent.where(ad_id: ad_ids)
    click_event_counts = click_events.group(:event_type).count
  
    # Seller Engagement & Visibility
    total_clicks = click_event_counts["Ad-Click"] || 0
    total_profile_views = click_event_counts["Reveal-Seller-Details"] || 0
    reveal_seller_details_clicks = click_event_counts["Reveal-Seller-Details"] || 0
    ad_performance_rankings = Seller.joins(ads: :click_events)
                                .group("sellers.id")
                                .order(Arel.sql("COUNT(click_events.id) DESC"))
                                .count("click_events.id")
                                .keys

    ad_performance_rank = ad_performance_rankings.index(seller.id)&.next || nil
    
    # Seller Activity & Consistency
    last_activity = seller.ads.order(updated_at: :desc).limit(1).pluck(:updated_at).first
    total_ads_updated = seller_ads.where.not("updated_at = created_at").count
    ad_approval_rate = (seller_ads.where(approved: true).count.to_f / seller_ads.count * 100).round(2) rescue 0
  
    # Competitor & Category Insights
    top_category = seller_ads.joins("JOIN categories_sellers ON ads.seller_id = categories_sellers.seller_id")
                      .joins("JOIN categories ON categories_sellers.category_id = categories.id")
                      .group("categories.name")
                      .order("COUNT(ads.id) DESC")
                      .limit(1)
                      .count
                      .keys.first rescue "Unknown"

    # Handle sellers without categories
    if seller.category.present?
      category_comparison = Seller.joins(:ads)
                        .joins("JOIN categories_sellers ON sellers.id = categories_sellers.seller_id")
                        .where("categories_sellers.category_id = ?", seller.category.id)
                        .group("sellers.id")
                        .count
                        .sort_by { |_seller_id, ad_count| -ad_count }
                        .to_h

      seller_category_rank = category_comparison.keys.index(seller.id).to_i + 1 rescue nil
    else
      category_comparison = {}
      seller_category_rank = nil
    end
  
    # Customer Interest & Conversion
    wishlist_to_click_ratio = (click_event_counts["Add-to-Wish-List"].to_f / total_clicks * 100).round(2) rescue 0
    wishlist_to_contact_ratio = (click_event_counts["Add-to-Wish-List"].to_f / reveal_seller_details_clicks * 100).round(2) rescue 0
    most_wishlisted_ad = WishList.where(ad_id: ad_ids)
                        .group(:ad_id)
                        .order("count_id DESC")
                        .limit(1)
                        .count(:id)
                        .first
  
    most_wishlisted_ad_data = most_wishlisted_ad ? Ad.find(most_wishlisted_ad[0]).as_json(only: [:id, :title]) : nil
  
    {
      # Ad Inventory
      total_ads: seller_ads.count,

      # Ad Performance
      total_ads_wishlisted: WishList.where(ad_id: ad_ids).count,

      # Rating
      mean_rating: seller.reviews.joins(:ad)
                                .where(ads: { id: ad_ids })
                                .average(:rating).to_f.round(2),
  
      # Total Reviews
      total_reviews: seller.reviews.joins(:ad)
                                   .where(ads: { id: ad_ids })
                                   .group(:rating)
                                   .count
                                   .values.sum,
  
      # Rating Breakdown
      rating_pie_chart: (1..5).map do |rating|
        {
          rating: rating,
          count: seller.reviews.joins(:ad)
                              .where(ads: { id: ad_ids })
                              .group(:rating)
                              .count[rating] || 0
        }
      end,
  
      # Reviews
      reviews: seller.reviews.joins(:ad, :buyer)
                      .where(ads: { id: ad_ids })
                      .select('reviews.*, buyers.fullname AS buyer_name')
                      .as_json(only: [:id, :rating, :review, :created_at],
                                include: { buyer: { only: [:fullname] } }),
  
      # Click Event Breakdown
      ad_clicks: total_clicks,
      add_to_wish_list: click_event_counts["Add-to-Wish-List"] || 0,
      reveal_seller_details: reveal_seller_details_clicks,
      total_click_events: click_events.count,
  
      # Engagement & Visibility Metrics
      total_profile_views: total_profile_views,
      ad_performance_rank: ad_performance_rank,
  
      # Activity & Consistency
      last_activity: last_activity,
      total_ads_updated: total_ads_updated,
      ad_approval_rate: ad_approval_rate,
  
      # Competitor & Category Insights
      seller_category: seller.category&.name || "No Category",
      top_performing_category: top_category,
      category_rank: seller_category_rank,
  
      # Customer Interest & Conversion
      wishlist_to_click_ratio: wishlist_to_click_ratio,
      wishlist_to_contact_ratio: wishlist_to_contact_ratio,
      most_wishlisted_ad: most_wishlisted_ad_data,
      most_clicked_ad: most_clicked_ad(seller),
  
      last_ad_posted_at: seller_ads.order(created_at: :desc).limit(1).pluck(:created_at).first,
      account_age_days: (Time.current.to_date - seller.created_at.to_date).to_i
    }
  end  
end
