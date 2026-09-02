require 'digest'

class Admin::BuyersController < ApplicationController
  before_action :authenticate_admin
  before_action :set_buyer, only: [:block, :unblock, :update, :destroy]
  # show loads its own record with eager associations to avoid N+1 queries

  # Columns needed for the list response so we don't load password digests / tokens.
  BUYER_LIST_COLUMNS = %i[
    id fullname username phone_number email location
    blocked created_at updated_at last_active_at
    profile_picture provider deleted
  ].freeze

  def index
    cache_key = buyer_list_cache_key

    data = Rails.cache.fetch(cache_key, expires_in: 30.seconds) do
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
           buyers.id::text = :exact_search",
          search: "%#{search_term}%",
          exact_search: search_term
        )
      end

      # Filter by status
      case params[:status]
      when 'active'
        buyers_query = buyers_query.where(blocked: false)
      when 'blocked'
        buyers_query = buyers_query.where(blocked: true)
      end

      # Sorting - default to last_active_at desc to show most recently active users first
      sort_by = params[:sort_by] || 'last_active_at'
      sort_order = params[:sort_order] || 'desc'

      # Validate sort parameters
      allowed_sort_fields = %w[id fullname username email location created_at updated_at last_active_at]
      allowed_sort_orders = %w[asc desc]

      sort_by = 'id' unless allowed_sort_fields.include?(sort_by)
      sort_order = 'asc' unless allowed_sort_orders.include?(sort_order)

      # Put nulls at the end when sorting by recency so stale records don't float to the top.
      order_clause = if sort_by == 'last_active_at' && sort_order == 'desc'
                       "last_active_at DESC NULLS LAST"
                     else
                       "#{sort_by} #{sort_order}"
                     end
      buyers_query = buyers_query.order(order_clause)

      # Pagination
      page = params[:page]&.to_i || 1
      per_page = params[:per_page]&.to_i || 20

      # Validate pagination parameters
      page = 1 if page < 1
      per_page = [per_page, 100].min # Max 100 per page
      per_page = 20 if per_page < 1

      total_count = buyers_query.count
      offset = (page - 1) * per_page

      @buyers = buyers_query.select(BUYER_LIST_COLUMNS).limit(per_page).offset(offset)

      # Prepare buyers data with last_active_at and profile_picture
      @buyers_data = @buyers.map do |buyer|
        buyer.as_json(only: BUYER_LIST_COLUMNS)
      end

      # Calculate pagination metadata
      total_pages = (total_count.to_f / per_page).ceil
      has_next_page = page < total_pages
      has_prev_page = page > 1

      {
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

    render json: data
  end

  def show
    buyer_updated_at = Buyer.where(id: params[:id]).pick(:updated_at).to_i
    cache_key = "admin_buyer_detail_v2_#{params[:id]}_#{buyer_updated_at}"

    buyer_data = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      buyer = Buyer.includes(
        :county, :sub_county, :age_group, :income, :employment, :education, :sector
      ).find(params[:id])

      data = buyer.as_json(
        only: [
          :id, :fullname, :username, :description, :phone_number, :secondary_phone_number,
          :email, :location, :blocked, :profile_picture, :zipcode,
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

      # Legacy orders key kept for backward compatibility.
      data['orders'] = []

      data['wish_lists'] = buyer.wish_lists.includes(ad: [:seller, :category]).order(created_at: :desc).limit(50).map do |wish|
        ad = wish.ad
        {
          id: wish.id,
          created_at: wish.created_at,
          ad: ad.as_json(
            only: [:id, :title, :price, :slug],
            methods: [:first_media_url],
            include: { seller: { only: [:id, :fullname, :enterprise_name] }, category: { only: [:id, :name] } }
          )
        }
      end

      data['cart_items'] = buyer.cart_items.includes(ad: [:seller, :category]).order(created_at: :desc).limit(50).map do |item|
        ad = item.ad
        {
          id: item.id,
          quantity: item.quantity,
          price: item.price,
          total_price: item.total_price,
          created_at: item.created_at,
          ad: ad.as_json(
            only: [:id, :title, :price, :slug],
            methods: [:first_media_url],
            include: { seller: { only: [:id, :fullname, :enterprise_name] }, category: { only: [:id, :name] } }
          )
        }
      end

      data['conversations'] = buyer.conversations.includes(:ad, :messages, :seller, :inquirer_seller, :admin).order(updated_at: :desc).limit(50).map do |conv|
        {
          id: conv.id,
          created_at: conv.created_at,
          updated_at: conv.updated_at,
          ad: conv.ad&.as_json(only: [:id, :title, :price, :slug], methods: [:first_media_url]),
          seller: conv.seller&.as_json(only: [:id, :fullname, :enterprise_name]),
          admin: conv.admin&.as_json(only: [:id, :fullname, :email]),
          messages: conv.messages.order(created_at: :desc).limit(20).reverse.map do |message|
            {
              id: message.id,
              content: message.content,
              sender_type: message.sender_type,
              sender_id: message.sender_id,
              created_at: message.created_at,
              status: message.status
            }
          end
        }
      end

      data['reviews'] = buyer.reviews.includes(ad: :seller).order(created_at: :desc).limit(50).map do |review|
        {
          id: review.id,
          rating: review.rating,
          review: review.review,
          seller_reply: review.seller_reply,
          created_at: review.created_at,
          ad: review.ad.as_json(
            only: [:id, :title, :price, :slug],
            methods: [:first_media_url],
            include: { seller: { only: [:id, :fullname, :enterprise_name] } }
          )
        }
      end

      data['click_events'] = buyer.click_events.includes(:ad).order(created_at: :desc).limit(100).map do |event|
        {
          id: event.id,
          event_type: event.event_type,
          created_at: event.created_at,
          metadata: event.metadata,
          ad: event.ad&.as_json(only: [:id, :title, :price, :slug], methods: [:first_media_url])
        }
      end

      data['ad_searches'] = buyer.ad_searches.order(created_at: :desc).limit(100).map do |search|
        {
          id: search.id,
          search_term: search.search_term,
          created_at: search.created_at
        }
      end

      data
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

  def buyer_list_cache_key
    cache_params = params.permit(:query, :page, :per_page, :sort_by, :sort_order, :status).to_h
    max_updated_at = Buyer.maximum(:updated_at).to_i
    "admin_buyers_index_v1_#{Digest::SHA256.hexdigest(cache_params.to_json)}_#{max_updated_at}"
  end

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