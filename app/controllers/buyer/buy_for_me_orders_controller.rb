class Buyer::BuyForMeOrdersController < ApplicationController
  before_action :authenticate_buyer

  def index
    @buy_for_me_orders = current_buyer.buy_for_me_orders.includes(buy_for_me_order_items: [ad: :seller])
    render json: @buy_for_me_orders, each_serializer: BuyForMeOrderSerializer
  end

  def show
    @buy_for_me_order = current_buyer.buy_for_me_orders.includes(buy_for_me_order_items: [ad: :seller]).find(params[:id])
    render json: @buy_for_me_order, serializer: BuyForMeOrderSerializer
  end

  def create
    if params[:mpesa_transaction_code].blank?
      render json: { error: "Mpesa transaction code can't be blank" }, status: :unprocessable_entity
      return
    end
  
    ActiveRecord::Base.transaction do
      # Fetch cart items for the current buyer
      buy_for_me_order_cart_items = current_buyer.buy_for_me_order_cart_items
  
      # Calculate total item price separately
      item_total_price = buy_for_me_order_cart_items.sum { |item| item.price * item.quantity }
  
      # Create the order with the provided details
      @buy_for_me_order = current_buyer.buy_for_me_orders.new(
        # status: 'Processing',
        mpesa_transaction_code: params[:mpesa_transaction_code],
        processing_fee: params[:processing_fee],  # New processing fee
        delivery_fee: params[:delivery_fee]       # New delivery fee
      )
  
      # Set the total amount including item total price and fees
      @buy_for_me_order.total_amount = item_total_price + @buy_for_me_order.processing_fee.to_f + @buy_for_me_order.delivery_fee.to_f
  
      # Create order items and associate them with the order
      buy_for_me_order_cart_items.each do |buy_for_me_order_cart_item|
        @buy_for_me_order.buy_for_me_order_items.build(
          ad_id: buy_for_me_order_cart_item.ad_id,
          quantity: buy_for_me_order_cart_item.quantity,
          price: buy_for_me_order_cart_item.price,
          total_price: buy_for_me_order_cart_item.price * buy_for_me_order_cart_item.quantity
        )
      end
  
      # Identify sellers and create order_seller records
      sellers = buy_for_me_order_cart_items.map { |item| item.ad.seller }.uniq.compact
      sellers.each do |seller|
        @buy_for_me_order.buy_for_me_order_sellers.build(seller: seller)
      end
  
      # Clear the cart after creating the order
      buy_for_me_order_cart_items.destroy_all
  
      # Save the order and associated items
      @buy_for_me_order.save!
    end
  
    render json: @buy_for_me_order, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end
  

  def update_status_to_delivered
    @buy_for_me_order_order = BuyForMeOrder.find(params[:id])

    if @buy_for_me_order.update(params.require(:order).permit(:status))
      render json: @buy_for_me_order
    else
      render json: { errors: @buy_for_me_order.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def authenticate_buyer
    @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Buyer)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_buyer
    @current_user
  end
end
