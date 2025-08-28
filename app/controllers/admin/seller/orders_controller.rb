class Admin::Seller::OrdersController < ApplicationController
  before_action :authenticate_admin
  before_action :set_seller

  # GET /admin/sellers/:seller_id/orders
  def index_for_seller
    # Get all orders that have order_items related to the seller's ads
    orders = @seller.orders.includes(order_items: :ad, buyer: :orders).where(order_items: { ad_id: @seller.ads.pluck(:id) })

    # Prepare the response with filtered orders, including the buyer details
    filtered_orders = orders.map do |order|
      {
        order: order.as_json(only: [:id, :status, :created_at, :updated_at, :mpesa_transaction_code]),
        buyer: order.buyer.as_json(only: [:id, :fullname, :email, :phone_number]),
        order_items: order.order_items.select { |item| @seller.ads.exists?(item.ad_id) }.as_json(include: { ad: { only: [:id, :title, :price] } })
      }
    end

    render json: filtered_orders
  end

  private

  def set_seller
    @seller = Seller.find(params[:seller_id])
  end

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end
