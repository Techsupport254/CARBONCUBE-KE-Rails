class Admin::Buyer::OrdersController < ApplicationController
  before_action :authenticate_admin
  before_action :set_seller

  # GET /admin/sellers/:seller_id/orders
  def index_for_seller
    @orders = @seller.orders.includes(order_items: { ad: :seller })

    # Calculate total amount for each order
    orders_with_totals = @orders.map do |order|
      total_amount = order.order_items.sum { |item| item.total_price.to_f }
      order.as_json(include: {
        order_items: {
          include: {
            ad: {
              only: [:title],
              include: { seller: { only: [:fullname] } }
            }
          }
        }
      }).merge("total_amount" => total_amount)
    end

    render json: orders_with_totals
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
