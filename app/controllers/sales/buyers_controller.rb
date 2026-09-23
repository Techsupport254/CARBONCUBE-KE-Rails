class Sales::BuyersController < ApplicationController
  before_action :authenticate_sales_user
  before_action :ensure_employed_or_manager
  before_action :ensure_manager, only: [:destroy]
  before_action :set_buyer, only: [:show, :destroy]

  # Columns rendered for the list — never serialize password digests or OAuth tokens.
  BUYER_LIST_COLUMNS = %i[
    id fullname username email phone_number location city
    county_id sub_county_id blocked deleted profile_picture provider
    created_at last_active_at
  ].freeze

  # GET /sales/buyers
  def index
    per_page = params[:per_page]&.to_i || 20
    page = params[:page]&.to_i || 1

    buyers_query = Buyer.unscoped.includes(:county, :sub_county)

    if params[:query].present?
      search_term = params[:query].strip
      buyers_query = buyers_query.where(
        "fullname ILIKE :search OR
         username ILIKE :search OR
         phone_number ILIKE :search OR
         email ILIKE :search OR
         location ILIKE :search OR
         city ILIKE :search",
        search: "%#{search_term}%"
      )
    end

    total_count = buyers_query.count
    @buyers = buyers_query.order(created_at: :desc).limit(per_page).offset((page - 1) * per_page).to_a
    buyer_ids = @buyers.map(&:id)

    click_counts = ClickEvent.where(buyer_id: buyer_ids, event_type: 'Ad-Click').group(:buyer_id).count
    reveal_counts = ClickEvent.where(buyer_id: buyer_ids, event_type: 'Reveal-Seller-Details').group(:buyer_id).count
    review_counts = Review.where(buyer_id: buyer_ids).group(:buyer_id).count
    wishlist_counts = WishList.where(buyer_id: buyer_ids).group(:buyer_id).count

    buyers_data = @buyers.map do |buyer|
      buyer.as_json(only: BUYER_LIST_COLUMNS).merge(
        county_name: buyer.county&.name,
        sub_county_name: buyer.sub_county&.name,
        signup_method: buyer.oauth_user? ? 'google_oauth' : 'regular',
        stats: {
          clicks_count: click_counts[buyer.id] || 0,
          reveals_count: reveal_counts[buyer.id] || 0,
          wishlist_count: wishlist_counts[buyer.id] || 0,
          reviews_count: review_counts[buyer.id] || 0
        }
      )
    end

    render json: {
      buyers: buyers_data,
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
    render json: @buyer.as_json(only: BUYER_LIST_COLUMNS).merge(
      county_name: @buyer.county&.name,
      sub_county_name: @buyer.sub_county&.name
    )
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

  def ensure_employed_or_manager
    return if @current_sales_user&.full_sales_dashboard_access?

    render json: { error: 'Buyer management is restricted to employed sales staff and managers' }, status: :forbidden
  end

  def ensure_manager
    return if @current_sales_user&.is_manager

    render json: { error: 'Only managers can delete buyers' }, status: :forbidden
  end

  def set_buyer
    @buyer = Buyer.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Buyer not found' }, status: :not_found
  end
end
