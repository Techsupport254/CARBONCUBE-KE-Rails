# app/controllers/buyer/wish_lists_controller.rb
class Buyer::WishListsController < ApplicationController
  before_action :authenticate_buyer

  # GET /buyer/wish_lists
  def index
    @wish_lists = current_user.wish_lists.includes(ad: [:category, :seller, offer_ads: :offer]).order(created_at: :desc)

    render json: @wish_lists.map { |wl|
      ad = wl.ad
      next nil unless ad

      active_offer_ad = ad.offer_ads.joins(:offer)
                          .where(offers: { status: ['active', 'scheduled'] })
                          .where('offers.start_time <= ? AND offers.end_time >= ?', Time.current, Time.current)
                          .first

      effective_price = ad.effective_price
      has_discount = active_offer_ad.present? && effective_price < ad.price
      disc_percentage = has_discount ? (active_offer_ad.discount_percentage || (((ad.price - effective_price) / ad.price.to_f) * 100).round) : nil

      {
        id: wl.id,
        created_at: wl.created_at,
        ad: {
          id: ad.id,
          title: ad.title,
          price: ad.price,
          effective_price: effective_price,
          discounted_price: has_discount ? effective_price : nil,
          discount_percentage: disc_percentage,
          is_on_sale: has_discount,
          offer_end_time: active_offer_ad&.offer&.end_time,
          offer_type: active_offer_ad&.offer&.offer_type,
          rating: (ad.respond_to?(:mean_rating) ? ad.mean_rating.to_f.round(1) : nil),
          first_media_url: ad.first_media_url,
          category_name: ad.category&.name,
          seller_name: ad.seller&.enterprise_name || ad.seller&.fullname,
          seller_phone: ad.seller&.phone_number,
          location: ad.branch&.location || ad.seller&.location,
          city: ad.seller&.city,
          condition: ad.condition
        }
      }
    }.compact
  end

  # GET /buyer/wish_lists/count
  def count
    own_count = current_user.wish_lists.count
    products_count = if current_user.is_a?(Seller)
      WishList.joins(:ad)
              .where(ads: { seller_id: current_user.id, deleted: false })
              .distinct
              .count('ads.id')
    else
      0
    end

    render json: {
      count: own_count + products_count,
      own: own_count,
      products: products_count
    }
  end

  # GET /buyer/wish_lists/my_products
  def my_products
    if current_user.is_a?(Seller)
      ads = Ad.active
              .joins(:wish_lists)
              .where(seller_id: current_user.id)
              .distinct
              .order('ads.created_at DESC')

      render json: ads.as_json(
        only: [:id, :title, :price, :rating],
        methods: [:first_media_url]
      )
    else
      render json: []
    end
  end

  # POST /buyer/wish_lists
  def create
    ad = Ad.active.find(params[:ad_id])
    current_user.wish_list_ad(ad)
    render json: { message: 'Ad wishlisted successfully' }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ad not found' }, status: :not_found
  end

  # DELETE /buyer/wish_lists/:id
  def destroy
    ad = Ad.active.find(params[:id])
    if current_user.unwish_list_ad(ad)
      render json: { message: 'Wish list removed successfully' }, status: :ok
    else
      render json: { error: 'Wish list not found' }, status: :not_found
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ad not found' }, status: :not_found
  end

  # POST /buyer/wish_lists/:id/add_to_cart
  def add_to_cart
    if current_user.is_a?(Seller)
      render json: { error: 'Sellers cannot add items to cart' }, status: :forbidden
      return
    end

    ad = Ad.active.find(params[:id])
    cart_item = CartItem.new(buyer: current_user, ad: ad)

    if cart_item.save
      render json: { message: 'Ad added to cart' }, status: :created
    else
      render json: { error: cart_item.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ad not found' }, status: :not_found
  end

  private

  def authenticate_buyer
    begin
      # Try buyer authentication first
      buyer_auth = BuyerAuthorizeApiRequest.new(request.headers)
      @current_user = buyer_auth.result
    rescue ExceptionHandler::InvalidToken => e
      @current_user = nil
    rescue => e
      Rails.logger.error "Buyer::WishListsController: Unexpected error during buyer authentication: #{e.class.name} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      @current_user = nil
    end

    # If buyer auth fails or returns nil/string, try seller authentication
    if @current_user.nil? || @current_user.is_a?(String)
      begin
        seller_auth = SellerAuthorizeApiRequest.new(request.headers)
        @current_user = seller_auth.result
      rescue ExceptionHandler::InvalidToken => e
        @current_user = nil
      rescue => e
        Rails.logger.error "Buyer::WishListsController: Unexpected error during seller authentication: #{e.class.name} - #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        @current_user = nil
      end
    end

    # Allow both buyers and sellers to use wishlist functionality
    unless @current_user.is_a?(Buyer) || @current_user.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end

  def current_buyer
    @current_user if @current_user.is_a?(Buyer)
  end
end
