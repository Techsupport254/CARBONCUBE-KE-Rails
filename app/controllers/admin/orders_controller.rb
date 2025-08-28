class Admin::OrdersController < ApplicationController
  before_action :authenticate_admin
  before_action :set_order, only: [:show, :update_status, :destroy]

  # app/controllers/admin/orders_controller.rb
  def index
    if params[:search_query].present?
      @orders = Order.joins(:buyer)
                    .where("sellers.phone_number = :query OR buyers.phone_number = :query OR orders.id = :query", query: params[:search_query])
                    .includes(:buyer, order_items: { ad: :seller })
    else
      @orders = Order.includes(:buyer, order_items: { ad: :seller }).all
    end
  
    render json: @orders.as_json(
      include: {
        buyer: { only: [:fullname] },
        order_items: {
          include: {
            ad: {
              include: { seller: { only: [:fullname] } }
            }
          }
        }
      },
      methods: [:order_date, :total_price]
    )
  end
  
  def show
    render json: @order.as_json(
      include: {
        buyer: { only: [:fullname] },
        order_items: {
          include: {
            ad: {
              include: { seller: { only: [:fullname] } }
            }
          }
        }
      },
      methods: [:order_date, :total_price]
    )
  end

  # PUT /admin/orders/:id/update-status
  def update_status
    if @order.update(status: params[:status])
      render json: @order.as_json(
        include: {
          buyer: { only: [:fullname] },
          order_items: {
            include: {
              ad: {
                include: { seller: { only: [:fullname] } }
              }
            }
          }
        },
        methods: [:order_date, :total_price]
      )
    else
      render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @order.destroy
    head :no_content
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  def order_params
    params.require(:order).permit(:buyer_id, :status, :total_amount)
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
