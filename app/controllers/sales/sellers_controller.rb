class Sales::SellersController < ApplicationController
  before_action :authenticate_sales_user
  before_action :set_seller, only: [:show, :assign_carbon_code]

  # GET /sales/sellers
  def index
    per_page = params[:per_page]&.to_i || 20
    page = params[:page]&.to_i || 1
    
    sellers_query = Seller.unscoped
    
    if params[:query].present?
      search_term = params[:query].strip
      sellers_query = sellers_query.where(
        "fullname ILIKE :search OR 
         phone_number ILIKE :search OR 
         email ILIKE :search OR 
         enterprise_name ILIKE :search",
        search: "%#{search_term}%"
      )
    end
    
    total_count = sellers_query.count
    @sellers = sellers_query.includes(:tier, :carbon_code).order(created_at: :desc).limit(per_page).offset((page - 1) * per_page)
    
    render json: {
      sellers: @sellers,
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  # GET /sales/sellers/:id
  def show
    render json: @seller.as_json(include: { tier: { only: [:name] } })
  end

  # PATCH /sales/sellers/:id/assign_carbon_code
  # Assigns a carbon code to a seller and captures the sales user's GPS location
  # at the moment of assignment for anti-fraud verification.
  def assign_carbon_code
    code_string = params[:carbon_code].to_s.strip.upcase

    if code_string.blank?
      # Remove code if empty
      if @seller.update(carbon_code_id: nil)
        render json: { message: 'Carbon code removed successfully' }, status: :ok
      else
        render json: { error: 'Failed to remove carbon code', details: @seller.errors.full_messages }, status: :unprocessable_entity
      end
      return
    end

    carbon_code = CarbonCode.find_by(code: code_string)

    unless carbon_code
      render json: { error: "Carbon code '#{code_string}' not found" }, status: :not_found
      return
    end

    unless carbon_code.valid_for_use?
      render json: { error: "Carbon code '#{code_string}' is expired or has reached its usage limit" }, status: :unprocessable_entity
      return
    end

    if @seller.update(carbon_code_id: carbon_code.id)
      # Increment usage if it's a new assignment and not just updating to the same code
      if @seller.saved_change_to_carbon_code_id?
        carbon_code.increment!(:times_used)

        # Record the assignment with the sales user's GPS location for verification
        record_assignment_location(carbon_code)
      end

      render json: { message: 'Carbon code assigned successfully', carbon_code: carbon_code.code, label: carbon_code.label }, status: :ok
    else
      render json: { error: 'Failed to assign carbon code', details: @seller.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def set_seller
    @seller = Seller.includes(:tier).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Seller not found' }, status: :not_found
  end

  # Record the sales user's GPS location at the moment of carbon code assignment.
  # The frontend sends lat/lng + reverse-geocoded address from the browser.
  # Also computes distance to the seller's registered location for admin verification.
  def record_assignment_location(carbon_code)
    lat = params[:latitude]
    lng = params[:longitude]

    # If no location provided, still create the assignment record (without GPS)
    assignment = SellerCarbonCodeAssignment.new(
      seller: @seller,
      carbon_code: carbon_code,
      sales_user: @current_sales_user,
      latitude: lat,
      longitude: lng,
      display_name: params[:display_name],
      area: params[:area],
      city: params[:city],
      county: params[:county],
      country: params[:country],
      notes: params[:notes]&.strip&.presence
    )

    # Compute distance to seller's registered location if available.
    # Seller coordinates are geocoded and stored on their branches.
    branch = @seller.branches.first
    seller_lat = branch&.latitude
    seller_lng = branch&.longitude
    if lat.present? && lng.present? && seller_lat.present? && seller_lng.present?
      assignment.distance_km = assignment.distance_to(seller_lat, seller_lng)
    end

    assignment.save!
  rescue StandardError => e
    Rails.logger.error "Failed to record assignment location: #{e.message}"
    # Don't fail the assignment if location recording fails
  end
end
