class Admin::OffersController < ApplicationController
  before_action :authenticate_admin
  before_action :set_offer, only: [:show, :update, :destroy, :activate, :pause, :approve]
  
  # GET /admin/offers
  def index
    @offers = Offer.includes(:seller)
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
  
  # GET /admin/offers/:id
  def show
    render json: OfferSerializer.new(@offer).as_json
  end
  
  # POST /admin/offers
  def create
    @offer = Offer.new(offer_params)
    # Seller should be provided in params or use a default seller
    
    if @offer.save
      render json: OfferSerializer.new(@offer).as_json, status: :created
    else
      render json: { errors: @offer.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  # PUT /admin/offers/:id
  def update
    if @offer.update(offer_params)
      render json: OfferSerializer.new(@offer).as_json
    else
      render json: { errors: @offer.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  # DELETE /admin/offers/:id
  def destroy
    @offer.destroy
    head :no_content
  end
  
  # POST /admin/offers/:id/activate
  def activate
    if @offer.can_be_activated?
      @offer.update!(status: 'active')
      render json: { message: 'Offer activated successfully' }
    else
      render json: { error: 'Offer cannot be activated at this time' }, status: :unprocessable_entity
    end
  end
  
  # POST /admin/offers/:id/pause
  def pause
    if @offer.active?
      @offer.update!(status: 'paused')
      render json: { message: 'Offer paused successfully' }
    else
      render json: { error: 'Only active offers can be paused' }, status: :unprocessable_entity
    end
  end
  
  # POST /admin/offers/:id/approve
  def approve
    @offer.update!(status: 'active')
    render json: { message: 'Offer approved and activated' }
  end
  
  # GET /admin/offers/analytics
  def analytics
    @offers = Offer.where.not(status: 'draft')
    
    analytics_data = {
      total_offers: @offers.count,
      active_offers: @offers.active.count,
      total_views: @offers.sum(:view_count),
      total_clicks: @offers.sum(:click_count),
      total_conversions: @offers.sum(:conversion_count),
      total_revenue: @offers.sum(:revenue_generated),
      average_conversion_rate: @offers.average(:conversion_count).to_f / @offers.average(:click_count).to_f * 100,
      top_performing_offers: @offers.order(revenue_generated: :desc).limit(5).map do |offer|
        {
          id: offer.id,
          name: offer.name,
          revenue: offer.revenue_generated,
          conversions: offer.conversion_count
        }
      end,
      offers_by_type: @offers.group(:offer_type).count,
      offers_by_status: @offers.group(:status).count
    }
    
    render json: analytics_data
  end
  
  # POST /admin/offers/bulk_actions
  def bulk_actions
    action = params[:action_type]
    offer_ids = params[:offer_ids]
    
    case action
    when 'activate'
      Offer.where(id: offer_ids).update_all(status: 'active')
    when 'pause'
      Offer.where(id: offer_ids).update_all(status: 'paused')
    when 'delete'
      Offer.where(id: offer_ids).destroy_all
    when 'feature'
      Offer.where(id: offer_ids).update_all(featured: true)
    when 'unfeature'
      Offer.where(id: offer_ids).update_all(featured: false)
    end
    
    render json: { message: "Bulk action '#{action}' completed successfully" }
  end
  
  # GET /admin/offers/templates
  def templates
    templates = {
      black_friday: {
        name: 'Black Friday Sale',
        description: 'Huge discounts on Black Friday!',
        offer_type: 'black_friday',
        banner_color: '#000000',
        badge_color: '#ff0000',
        icon_name: 'bolt',
        badge_text: 'BLACK FRIDAY',
        discount_type: 'percentage',
        discount_percentage: 50.0,
        featured: true,
        priority: 100
      },
      cyber_monday: {
        name: 'Cyber Monday Deals',
        description: 'Tech deals you can\'t miss!',
        offer_type: 'cyber_monday',
        banner_color: '#1e40af',
        badge_color: '#3b82f6',
        icon_name: 'laptop',
        badge_text: 'CYBER MONDAY',
        discount_type: 'percentage',
        discount_percentage: 40.0,
        featured: true,
        priority: 90
      },
      flash_sale: {
        name: 'Flash Sale',
        description: 'Limited time offers!',
        offer_type: 'flash_sale',
        banner_color: '#dc2626',
        badge_color: '#fbbf24',
        icon_name: 'bolt',
        badge_text: 'FLASH SALE',
        discount_type: 'percentage',
        discount_percentage: 30.0,
        featured: true,
        priority: 80
      },
      clearance: {
        name: 'Clearance Sale',
        description: 'Clearance items at unbeatable prices!',
        offer_type: 'clearance',
        banner_color: '#7c2d12',
        badge_color: '#f97316',
        icon_name: 'tag',
        badge_text: 'CLEARANCE',
        discount_type: 'percentage',
        discount_percentage: 60.0,
        featured: true,
        priority: 70
      }
    }
    
    render json: templates
  end
  
  private
  
  def set_offer
    @offer = Offer.find(params[:id])
  end
  
  def offer_params
    params.require(:offer).permit(
      :seller_id, :name, :description, :offer_type, :status, :banner_color, :badge_color,
      :icon_name, :banner_image_url, :hero_image_url, :start_time, :end_time,
      :is_recurring, :recurrence_pattern, :recurrence_config, :discount_percentage,
      :fixed_discount_amount, :discount_type, :discount_config, :target_categories,
      :target_sellers, :target_products, :eligibility_criteria, :minimum_order_amount,
      :max_uses_per_customer, :total_usage_limit, :priority, :featured,
      :show_on_homepage, :show_badge, :badge_text, :cta_text, :terms_and_conditions,
      :admin_notes
    )
  end
  
  def authenticate_admin
    # Implement admin authentication
    # This should check if the current user is an admin
  end
  
  def current_admin
    # Return the current admin user
    # This should be implemented based on your authentication system
  end
end
