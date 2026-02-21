class Sales::BuyersController < ApplicationController
  before_action :authenticate_sales_user
  before_action :set_buyer, only: [:show, :destroy]

  # GET /sales/buyers
  def index
    per_page = params[:per_page]&.to_i || 20
    page = params[:page]&.to_i || 1
    
    buyers_query = Buyer.unscoped
    
    if params[:query].present?
      search_term = params[:query].strip
      buyers_query = buyers_query.where(
        "fullname ILIKE :search OR 
         phone_number ILIKE :search OR 
         email ILIKE :search",
        search: "%#{search_term}%"
      )
    end
    
    total_count = buyers_query.count
    @buyers = buyers_query.order(created_at: :desc).limit(per_page).offset((page - 1) * per_page)
    
    render json: {
      buyers: @buyers,
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  # GET /sales/buyers/:id
  def show
    render json: @buyer
  end

  # DELETE /sales/buyers/:id - Permanent delete
  def destroy
    begin
      if @buyer.destroy
        render json: { message: "Buyer '#{@buyer.fullname}' permanently deleted successfully" }, status: :ok
      else
        render json: { error: "Failed to delete buyer permanently", details: @buyer.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "❌ Error permanently deleting buyer: #{e.message}"
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

  def set_buyer
    @buyer = Buyer.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Buyer not found' }, status: :not_found
  end
end
