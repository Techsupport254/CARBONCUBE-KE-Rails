# app/controllers/buyer/buy_for_me_order_cart_items_controller.rb

class Buyer::BuyForMeOrderCartItemsController < ApplicationController
  before_action :authenticate_buyer

  # GET /buyer/buy_for_me_order_cart_items
  def index
    @buy_for_me_order_cart_items = current_buyer.buy_for_me_order_cart_items.includes(:ad)
    total_cart_price = @buy_for_me_order_cart_items.sum(&:total_price)
    render json: { buy_for_me_order_cart_items: @buy_for_me_order_cart_items, total_cart_price: total_cart_price }, include: ['ad']
  end

  # POST /buyer/buy_for_me_order_cart_items
  def create
    @buy_for_me_order_cart_items = current_buyer.buy_for_me_order_cart_items.build(buy_for_me_order_cart_item_params)

    if @buy_for_me_order_cart_items.save
      update_cart_total_price
      render json: @buy_for_me_order_cart_items, status: :created
    else
      render json: @buy_for_me_order_cart_items.errors, status: :unprocessable_entity
    end
  end

  # Buyer::CartItemsController
  def update
    buy_for_me_order_cart_item = BuyForMeOrderCartItem.find(params[:id])
    if buy_for_me_order_cart_item.update(quantity: params[:quantity])
      render json: buy_for_me_order_cart_item, status: :ok
    else
      render json: { error: 'Failed to update item' }, status: :unprocessable_entity
    end
  end


  # DELETE /buyer/buy_for_me_order_cart_items/:id
  def destroy
    @buy_for_me_order_cart_items = current_buyer.buy_for_me_order_cart_items.find(params[:id])
    @buy_for_me_order_cart_items.destroy
    update_buy_for_me_order_cart_total_price
    head :no_content
  end

  private

  def buy_for_me_order_cart_item_params
    params.require(:buy_for_me_order_cart_item).permit(:ad_id, :quantity)
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
    total_price = current_buyer.buy_for_me_order_cart_items.sum(&:total_price)
    current_buyer.update(buy_for_me_order_cart_total_price: total_price)
  end
end
