class Sales::SellersController < ApplicationController
  before_action :authenticate_sales_user
  before_action :set_seller, only: [:show, :destroy]

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
    @sellers = sellers_query.order(created_at: :desc).limit(per_page).offset((page - 1) * per_page)
    
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

  # DELETE /sales/sellers/:id - Permanent delete
  def destroy
    begin
      if @seller.destroy
        render json: { message: "Seller '#{@seller.fullname}' and all their data permanently deleted successfully" }, status: :ok
      else
        render json: { error: "Failed to delete seller permanently", details: @seller.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "❌ Error permanently deleting seller: #{e.message}"
      render json: { error: "Internal server error during deletion", details: e.message }, status: :internal_server_error
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
    @seller = Seller.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Seller not found' }, status: :not_found
  end
end
