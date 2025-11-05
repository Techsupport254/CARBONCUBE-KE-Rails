class Admin::BuyersController < ApplicationController
  before_action :authenticate_admin
  before_action :set_buyer, only: [:block, :unblock, :show, :update, :destroy]

  def index
    # Base query
    buyers_query = Buyer.where(deleted: false)
    
    # Enhanced search functionality
    if params[:query].present?
      search_term = params[:query].strip
      buyers_query = buyers_query.where(
        "fullname ILIKE :search OR 
         phone_number ILIKE :search OR 
         email ILIKE :search OR 
         username ILIKE :search OR 
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
        buyers_query = buyers_query.where(blocked: false)
      when 'blocked'
        buyers_query = buyers_query.where(blocked: true)
      end
    end
    
    # Sorting - default to last_active_at desc to show most recently active users first
    sort_by = params[:sort_by] || 'last_active_at'
    sort_order = params[:sort_order] || 'desc'
    
    # Validate sort parameters
    allowed_sort_fields = %w[id fullname username email location created_at updated_at last_active_at]
    allowed_sort_orders = %w[asc desc]
    
    sort_by = 'id' unless allowed_sort_fields.include?(sort_by)
    sort_order = 'asc' unless allowed_sort_orders.include?(sort_order)
    
    buyers_query = buyers_query.order("#{sort_by} #{sort_order}")
    
    # Pagination
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    
    # Validate pagination parameters
    page = 1 if page < 1
    per_page = [per_page, 100].min # Max 100 per page
    per_page = 20 if per_page < 1
    
    total_count = buyers_query.count
    offset = (page - 1) * per_page
    
    @buyers = buyers_query.limit(per_page).offset(offset)
    
    # Prepare buyers data with last_active_at and profile_picture
    @buyers_data = @buyers.map do |buyer|
      buyer.as_json(only: [:id, :fullname, :username, :phone_number, :email, :location, :blocked, :created_at, :updated_at, :last_active_at, :profile_picture])
    end
    
    # Calculate pagination metadata
    total_pages = (total_count.to_f / per_page).ceil
    has_next_page = page < total_pages
    has_prev_page = page > 1
    
    render json: {
      buyers: @buyers_data,
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
    buyer_data = @buyer.as_json(
      only: [
        :id, :fullname, :username, :description, :phone_number, :email, 
        :location, :blocked, :profile_picture, :zipcode, 
        :city, :gender, :created_at, :updated_at,
        :last_active_at, :deleted, :provider, :uid
      ],
      include: {
        county: { only: [:id, :name, :capital, :county_code] },
        sub_county: { only: [:id, :name] },
        age_group: { only: [:id, :name] },
        income: { only: [:id, :name] },
        employment: { only: [:id, :name] },
        education: { only: [:id, :name] },
        sector: { only: [:id, :name] }
      }
    )
    
    # Include orders if needed
    orders = @buyer.orders.includes(order_items: :ad)
    buyer_data['orders'] = orders.map do |order|
      order.as_json(
        include: { order_items: { include: :ad } },
        methods: [:order_date, :total_price]
      )
    end
    
    render json: buyer_data
  end

  def create
    @buyer = Buyer.new(buyer_params)
    if @buyer.save
      render json: @buyer, status: :created
    else
      render json: @buyer.errors, status: :unprocessable_entity
    end
  end

  def update
    if @buyer.update(buyer_params)
      render json: @buyer
    else
      render json: @buyer.errors, status: :unprocessable_entity
    end
  end

  def block
    if @buyer
      if @buyer.update(blocked: true)
        render json: @buyer.as_json(only: [:id, :fullname, :email, :location, :blocked]), status: :ok
      else
        render json: @buyer.errors, status: :unprocessable_entity
      end
    else
      render json: { error: 'Buyer not found' }, status: :not_found
    end
  end

  def unblock
    if @buyer
      if @buyer.update(blocked: false)
        render json: @buyer.as_json(only: [:id, :fullname, :email, :location, :blocked]), status: :ok
      else
        render json: @buyer.errors, status: :unprocessable_entity
      end
    else
      render json: { error: 'Buyer not found' }, status: :not_found
    end
  end

  def destroy
    @buyer.destroy
    head :no_content
  end

  private

  def set_buyer
    @buyer = Buyer.find(params[:id])
  end

  def buyer_params
    params.require(:buyer).permit(:fullname, :username, :phone_number, :email, :location, :password)
  end

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_admin
    @current_user
  end
end