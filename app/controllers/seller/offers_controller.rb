class Seller::OffersController < ApplicationController
  before_action :authenticate_seller, except: [:offer_types, :templates]
  before_action :set_offer, only: [:show, :update, :destroy, :activate, :pause, :add_ads, :remove_ads]
  
  # GET /seller/offers
  def index
    @offers = current_seller.offers
                           .order(priority: :desc, created_at: :desc)
    
    # Filtering
    @offers = @offers.where(status: params[:status]) if params[:status].present?
    @offers = @offers.where(offer_type: params[:offer_type]) if params[:offer_type].present?
    @offers = @offers.where(featured: true) if params[:featured] == 'true'
    @offers = @offers.where('start_time >= ?', params[:start_date]) if params[:start_date].present?
    @offers = @offers.where('end_time <= ?', params[:end_date]) if params[:end_date].present?
    
    # Search
    if params[:search].present?
      @offers = @offers.where(
        'name ILIKE ? OR description ILIKE ?', 
        "%#{params[:search]}%", 
        "%#{params[:search]}%"
      )
    end
    
    # Pagination
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 100].min # Max 100 per page
    
    total_count = @offers.count
    total_pages = (total_count.to_f / per_page).ceil
    offset = (page - 1) * per_page
    
    @offers = @offers.offset(offset).limit(per_page)
    
    render json: {
      offers: @offers.map { |offer| OfferSerializer.new(offer).as_json },
      pagination: {
        current_page: page,
        per_page: per_page,
        total_pages: total_pages,
        total_count: total_count,
        has_next_page: page < total_pages,
        has_prev_page: page > 1,
        next_page: page < total_pages ? page + 1 : nil,
        prev_page: page > 1 ? page - 1 : nil
      }
    }
  end
  
  # GET /seller/offers/:id
  def show
    render json: OfferSerializer.new(@offer).as_json
  end
  
  # POST /seller/offers
  def create
    @offer = current_seller.offers.build(offer_params)
    
    if @offer.save
      render json: OfferSerializer.new(@offer).as_json, status: :created
    else
      render json: { errors: @offer.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  # PUT /seller/offers/:id
  def update
    if @offer.update(offer_params)
      render json: OfferSerializer.new(@offer).as_json
    else
      render json: { errors: @offer.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  # DELETE /seller/offers/:id
  def destroy
    @offer.destroy
    head :no_content
  end
  
  # POST /seller/offers/:id/activate
  def activate
    if @offer.can_be_activated?
      @offer.update!(status: 'active')
      render json: { message: 'Offer activated successfully' }
    else
      render json: { error: 'Offer cannot be activated' }, status: :unprocessable_entity
    end
  end
  
  # POST /seller/offers/:id/pause
  def pause
    if @offer.active?
      @offer.update!(status: 'paused')
      render json: { message: 'Offer paused successfully' }
    else
      render json: { error: 'Only active offers can be paused' }, status: :unprocessable_entity
    end
  end
  
  # POST /seller/offers/:id/add_ads
  def add_ads
    ads_data = params[:ads] || []
    
    if ads_data.any?
      added_count = 0
      errors = []
      
      ads_data.each do |ad_data|
        ad_id = ad_data[:ad_id] || ad_data['ad_id']
        discount_percentage = ad_data[:discount_percentage] || ad_data['discount_percentage']
        original_price = ad_data[:original_price] || ad_data['original_price']
        seller_notes = ad_data[:seller_notes] || ad_data['seller_notes']
        
        # Get the ad to get current price if original_price not provided
        ad = current_seller.ads.find_by(id: ad_id)
        if ad && original_price.blank?
          original_price = ad.price
        end
        
        # Calculate discounted price
        discounted_price = original_price * (1 - discount_percentage / 100)
        
        begin
          offer_ad = @offer.offer_ads.create!(
            ad_id: ad_id,
            discount_percentage: discount_percentage,
            original_price: original_price,
            discounted_price: discounted_price,
            seller_notes: seller_notes
          )
          added_count += 1
        rescue ActiveRecord::RecordInvalid => e
          errors << "Ad #{ad_id}: #{e.record.errors.full_messages.join(', ')}"
        end
      end
      
      if added_count > 0
        render json: { 
          message: "#{added_count} ads added to offer successfully",
          total_ads: @offer.offer_ads.active.count,
          errors: errors
        }
      else
        render json: { 
          error: 'No ads could be added',
          details: errors
        }, status: :unprocessable_entity
      end
    else
      render json: { error: 'No ads provided' }, status: :unprocessable_entity
    end
  end
  
  # DELETE /seller/offers/:id/remove_ads
  def remove_ads
    ad_ids = params[:ad_ids] || []
    
    if ad_ids.any?
      current_products = @offer.target_products || []
      updated_products = current_products - ad_ids.map(&:to_i)
      @offer.update!(target_products: updated_products)
      
      render json: { 
        message: "#{ad_ids.length} ads removed from offer successfully",
        total_ads: updated_products.length
      }
    else
      render json: { error: 'No ads provided' }, status: :unprocessable_entity
    end
  end
  
  # GET /seller/offers/offer_types
  def offer_types
    # Return all available offer types from the Offer model enum
    types = Offer.offer_types.keys.map do |type|
      {
        value: type,
        label: type.titleize,
        description: get_offer_type_description(type)
      }
    end
    
    render json: { offer_types: types }
  end
  
  # GET /seller/offers/templates
  def templates
    # Predefined offer templates for sellers
    render json: [
      {
        name: 'Black Friday Sale',
        offer_type: 'black_friday',
        description: 'Join the biggest shopping event of the year!',
        banner_color: '#000000',
        badge_color: '#FF0000',
        icon_name: 'shopping-bag',
        discount_percentage: 70,
        start_time: '2024-11-29T00:00:00Z',
        end_time: '2024-11-30T23:59:59Z',
        featured: true,
        show_on_homepage: true,
        show_badge: true,
        badge_text: 'BLACK FRIDAY',
        cta_text: 'Shop Now'
      },
      {
        name: 'Cyber Monday Deals',
        offer_type: 'cyber_monday',
        description: 'Exclusive online deals for Cyber Monday!',
        banner_color: '#1E3A8A',
        badge_color: '#3B82F6',
        icon_name: 'laptop',
        discount_percentage: 50,
        start_time: '2024-12-02T00:00:00Z',
        end_time: '2024-12-02T23:59:59Z',
        featured: true,
        show_on_homepage: true,
        show_badge: true,
        badge_text: 'CYBER MONDAY',
        cta_text: 'Get Deals'
      },
      {
        name: 'Flash Sale',
        offer_type: 'flash_sale',
        description: 'Limited time flash sale with amazing discounts!',
        banner_color: '#DC2626',
        badge_color: '#FBBF24',
        icon_name: 'bolt',
        discount_percentage: 40,
        start_time: Time.current.iso8601,
        end_time: (Time.current + 6.hours).iso8601,
        featured: true,
        show_on_homepage: true,
        show_badge: true,
        badge_text: 'FLASH SALE',
        cta_text: 'Grab Now'
      },
      {
        name: 'Clearance Sale',
        offer_type: 'clearance',
        description: 'Last chance to buy! Huge discounts on end-of-season items.',
        banner_color: '#F97316',
        badge_color: '#EF4444',
        icon_name: 'percent',
        discount_percentage: 60,
        start_time: Time.current.iso8601,
        end_time: (Time.current + 7.days).iso8601,
        featured: true,
        show_on_homepage: true,
        show_badge: true,
        badge_text: 'CLEARANCE',
        cta_text: 'Clear Out'
      },
      {
        name: 'Christmas Holiday Sale',
        offer_type: 'christmas',
        description: 'Spread the holiday cheer with amazing discounts on gifts!',
        banner_color: '#B91C1C',
        badge_color: '#FCD34D',
        icon_name: 'gift',
        discount_percentage: 35,
        start_time: '2024-12-20T00:00:00Z',
        end_time: '2024-12-25T23:59:59Z',
        featured: true,
        show_on_homepage: true,
        show_badge: true,
        badge_text: 'CHRISTMAS',
        cta_text: 'Gift Now'
      }
    ]
  end
  
  # GET /seller/offers/my_ads
  def my_ads
    # Get seller's ads that can be added to offers
    @ads = current_seller.ads
                        .where(status: 'active')
                        .select(:id, :title, :price, :category_name, :subcategory_name, :first_media_url)
                        .order(:title)
    
    render json: @ads.map { |ad| 
      {
        id: ad.id,
        title: ad.title,
        price: ad.price,
        category: ad.category_name,
        subcategory: ad.subcategory_name,
        image_url: ad.first_media_url
      }
    }
  end
  
  # GET /seller/offers/analytics
  def analytics
    @offers = current_seller.offers.where.not(status: 'draft')
    
    total_offers = @offers.count
    active_offers = @offers.active_now.count
    upcoming_offers = @offers.upcoming.count
    expired_offers = @offers.expired.count
    
    render json: {
      total_offers: total_offers,
      active_offers: active_offers,
      upcoming_offers: upcoming_offers,
      expired_offers: expired_offers,
      offer_type_distribution: @offers.group(:offer_type).count,
      status_distribution: @offers.group(:status).count,
      featured_offers_count: @offers.featured_offers.count,
      total_views: @offers.sum(:view_count),
      total_clicks: @offers.sum(:click_count),
      total_conversions: @offers.sum(:conversion_count),
      total_revenue: @offers.sum(:revenue_generated)
    }
  end
  
  private
  
  def set_offer
    @offer = current_seller.offers.find(params[:id])
  end
  
  def offer_params
    params.require(:offer).permit(
      :name, :description, :offer_type, :status, :banner_color, :badge_color,
      :icon_name, :banner_image_url, :hero_image_url, :start_time, :end_time,
      :is_recurring, :recurrence_pattern, :recurrence_config, :discount_percentage,
      :fixed_discount_amount, :discount_type, :discount_config, :target_categories,
      :target_sellers, :target_products, :eligibility_criteria, :minimum_order_amount,
      :max_uses_per_customer, :total_usage_limit, :priority, :featured,
      :show_on_homepage, :show_badge, :badge_text, :cta_text, :terms_and_conditions
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
  
  def get_offer_type_description(type)
    descriptions = {
      'flash_sale' => 'Short-duration sales (hours/days)',
      'limited_time_offer' => 'Any time-limited promotion',
      'daily_deal' => 'Daily special offers',
      'weekend_sale' => 'Weekend-specific promotions',
      'monthly_special' => 'Monthly promotional offers',
      'black_friday' => 'Black Friday sales',
      'cyber_monday' => 'Cyber Monday tech deals',
      'boxing_day' => 'Boxing Day sales',
      'new_year' => 'New Year promotions',
      'easter' => 'Easter sales',
      'christmas' => 'Christmas promotions',
      'independence_day' => 'Jamhuri Day / Madaraka Day',
      'end_of_year' => 'End of year clearance',
      'mid_year_sale' => 'Mid-year promotions',
      'clearance' => 'Clearance sale',
      'stock_clearance' => 'Stock liquidation',
      'overstock_sale' => 'Excess inventory sale',
      'warehouse_sale' => 'Warehouse clearance',
      'discontinued_items' => 'Discontinued product sale',
      'new_arrival' => 'New product launch',
      'new_stock' => 'Newly stocked items',
      'restocked_items' => 'Back in stock',
      'exclusive_items' => 'Exclusive products',
      'imported_goods' => 'Imported items sale',
      'bulk_discount' => 'Volume/bulk discounts',
      'wholesale_pricing' => 'Wholesale rates',
      'trade_discount' => 'Trade/contractor discounts',
      'business_special' => 'B2B exclusive offers',
      'contract_pricing' => 'Special contract rates',
      'loyalty_reward' => 'Repeat customer rewards',
      'first_time_buyer' => 'New customer welcome',
      'vip_offer' => 'VIP customer exclusive',
      'referral_bonus' => 'Referral incentives',
      'free_shipping' => 'Free delivery offer',
      'free_installation' => 'Free installation service',
      'bundle_deal' => 'Package deals',
      'combo_offer' => 'Combo packages',
      'buy_more_save_more' => 'Tiered volume discounts',
      'custom' => 'Seller-defined custom offer'
    }
    
    descriptions[type] || type.titleize
  end
end
