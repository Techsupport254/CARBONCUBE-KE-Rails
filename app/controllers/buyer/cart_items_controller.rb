# app/controllers/buyer/cart_items_controller.rb

class Buyer::CartItemsController < ApplicationController
  before_action :authenticate_buyer

  # GET /buyer/cart_items
  def index
    @cart_items = current_buyer.cart_items.includes(:ad)
    total_cart_price = @cart_items.sum(&:total_price)
    render json: { cart_items: @cart_items, total_cart_price: total_cart_price }, include: ['ad']
  end

  # POST /buyer/cart_items
  def create
    @cart_item = current_buyer.cart_items.build(cart_item_params)

    if @cart_item.save
      update_cart_total_price
      render json: @cart_item, status: :created
    else
      render json: @cart_item.errors, status: :unprocessable_entity
    end
  end

  # Buyer::CartItemsController
  def update
    cart_item = CartItem.find(params[:id])
    if cart_item.update(quantity: params[:quantity])
      render json: cart_item, status: :ok
    else
      render json: { error: 'Failed to update item' }, status: :unprocessable_entity
    end
  end


  # DELETE /buyer/cart_items/:id
  def destroy
    @cart_item = current_buyer.cart_items.find(params[:id])
    @cart_item.destroy
    update_cart_total_price
    head :no_content
  end

  private

  def cart_item_params
    params.require(:cart_item).permit(:ad_id, :quantity)
  end

  def authenticate_buyer
    @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Buyer)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_buyer
    @current_user
  end

  def update_cart_total_price
    total_price = current_buyer.cart_items.sum(&:total_price)
    current_buyer.update(cart_total_price: total_price)
  end
end
