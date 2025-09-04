# app/controllers/buyer/wish_lists_controller.rb
class Buyer::WishListsController < ApplicationController
  before_action :authenticate_buyer

  # GET /buyer/wish_lists
  def index
    @wish_lists = current_buyer.wish_lists.includes(:ad).order(created_at: :desc)    
    
    render json: @wish_lists.as_json(include: {
      ad: {
        only: [:id, :title, :price, :rating],
        methods: [:first_media_url] # Include a method to get the first media URL
      }
    })
  end

  # GET /buyer/wishlist/count
  def count
    count = current_buyer.wish_lists.count
    render json: { count: count }
  end

  # POST /buyer/wish_lists
  def create
    ad = Ad.find(params[:ad_id])
    current_buyer.wish_list_ad(ad)
    render json: { message: 'Ad wishlisted successfully' }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ad not found' }, status: :not_found
  end

  # DELETE /buyer/wish_lists/:id
  def destroy
    ad = Ad.find(params[:id])
    if current_buyer.unwish_list_ad(ad)
      render json: { message: 'Wish list removed successfully' }, status: :ok
    else
      render json: { error: 'Wish list not found' }, status: :not_found
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ad not found' }, status: :not_found
  end

  # POST /buyer/wish_lists/:id/add_to_cart
  def add_to_cart
    ad = Ad.find(params[:id])
    cart_item = CartItem.new(buyer: current_buyer, ad: ad)

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
    @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
    render json: { error: 'Not Authorized' }, status: :unauthorized unless @current_user.is_a?(Buyer)
  end

  def current_buyer
    @current_user
  end
end
