class Buyer::OffersController < ApplicationController
  before_action :authenticate_buyer, except: [:index, :show, :active_offers]
  
  # GET /buyer/offers
  # Returns ALL active offers with their ads for the deals page
  # Also includes scheduled offers that should be visible to buyers
  def index
    @offers = Offer.where(status: ['active', 'scheduled'])
                   .where('end_time > ?', Time.current)
                   .by_priority
                   .includes(:seller, :offer_ads, ads: [:category, :subcategory, :reviews, seller: :seller_tier])
    
    # Filter by offer type
    @offers = @offers.where(offer_type: params[:offer_type]) if params[:offer_type].present?
    
    # Filter by category
    if params[:category_id].present?
      @offers = @offers.where("target_categories @> ?", [params[:category_id]].to_json)
    end
    
    # Search
    if params[:search].present?
      @offers = @offers.where(
        'name ILIKE ? OR description ILIKE ?', 
        "%#{params[:search]}%", 
        "%#{params[:search]}%"
      )
    end
    
    # Pagination - default to more items for deals page
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 100).to_i  # Increased default to get all offers
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
  
  # GET /buyer/offers/:id
  def show
    @offer = Offer.find(params[:id])
    
    # Track view
    @offer.increment_view_count!
    
    render json: OfferSerializer.new(@offer).as_json
  end
  
  # GET /buyer/offers/active
  def active_offers
    @offers = Offer.active_now
                   .homepage_visible
                   .featured
                   .by_priority
                   .limit(5)
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/featured
  def featured_offers
    @offers = Offer.active_now
                   .featured
                   .by_priority
                   .limit(10)
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/upcoming
  def upcoming_offers
    @offers = Offer.upcoming
                   .homepage_visible
                   .by_priority
                   .limit(5)
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/by_type/:type
  def by_type
    offer_type = params[:type]
    
    unless Offer.offer_types.key?(offer_type)
      render json: { error: 'Invalid offer type' }, status: :bad_request
      return
    end
    
    @offers = Offer.active_now
                   .where(offer_type: offer_type)
                   .homepage_visible
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # POST /buyer/offers/:id/click
  def track_click
    @offer = Offer.find(params[:id])
    @offer.increment_click_count!
    
    render json: { message: 'Click tracked successfully' }
  end
  
  # GET /buyer/offers/black-friday
  def black_friday
    @offers = Offer.active_now
                   .where(offer_type: 'black_friday')
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/cyber-monday
  def cyber_monday
    @offers = Offer.active_now
                   .where(offer_type: 'cyber_monday')
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/flash-sales
  def flash_sales
    @offers = Offer.active_now
                   .where(offer_type: 'flash_sale')
                   .includes(:seller, :offer_ads, ads: [:category, :subcategory, :reviews, seller: :seller_tier])
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/clearance
  def clearance
    @offers = Offer.active_now
                   .where(offer_type: 'clearance')
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/seasonal
  def seasonal
    @offers = Offer.active_now
                   .where(offer_type: 'seasonal')
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/holiday
  def holiday
    @offers = Offer.active_now
                   .where(offer_type: 'holiday')
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/calendar
  def calendar
    start_date = params[:start_date] || Date.current.beginning_of_month
    end_date = params[:end_date] || Date.current.end_of_month
    
    @offers = Offer.where(
      'start_time >= ? AND end_time <= ?', 
      start_date, 
      end_date
    ).order(:start_time)
    
    calendar_data = @offers.map do |offer|
      {
        id: offer.id,
        title: offer.name,
        start: offer.start_time,
        end: offer.end_time,
        type: offer.offer_type,
        status: offer.status,
        color: offer.banner_color,
        featured: offer.featured
      }
    end
    
    render json: calendar_data
  end
  
  # GET /buyer/offers/search
  def search
    query = params[:q]
    return render json: { offers: [] } if query.blank?
    
    @offers = Offer.active_now
                   .where(
                     'name ILIKE ? OR description ILIKE ? OR badge_text ILIKE ?', 
                     "%#{query}%", 
                     "%#{query}%",
                     "%#{query}%"
                   )
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  private
  
  def authenticate_buyer
    # Implement buyer authentication
    # This should check if the current user is a buyer
  end
end
