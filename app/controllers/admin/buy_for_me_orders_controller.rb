class Admin::BuyForMeOrdersController < ApplicationController
  before_action :authenticate_admin
  before_action :set_buy_for_me_order, only: [:show, :update_status, :destroy]

  # app/controllers/admin/buy_for_me_orders_controller.rb
  def index
    if params[:search_query].present?
      @buy_for_me_orders = BuyForMeOrder.joins(:buyer)
                    .where("sellers.phone_number = :query OR buyers.phone_number = :query OR buy_for_me_orders.id = :query", query: params[:search_query])
                    .includes(:buyer, buy_for_me_order_items: { ad: :seller })
    else
      @buy_for_me_orders = BuyForMeOrder.includes(:buyer, buy_for_me_order_items: { ad: :seller }).all
    end
  
    render json: @buy_for_me_orders.as_json(
      include: {
        buyer: { only: [:fullname] },
        buy_for_me_order_items: {
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
    render json: @buy_for_me_order.as_json(
      include: {
        buyer: { only: [:fullname] },
        buy_for_me_order_items: {
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
    if @buy_for_me_order.update(status: params[:status])
      render json: @buy_for_me_order.as_json(
        include: {
          buyer: { only: [:fullname] },
          buy_for_me_order_items: {
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
    @buy_for_me_order.destroy
    head :no_content
  end

  private

  def set_buy_for_me_order
    @buy_for_me_order = BuyForMeOrder.find(params[:id])
  end

  def buy_for_me_order_params
    params.require(:buy_for_me_order).permit(:buyer_id, :status, :total_amount)
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
