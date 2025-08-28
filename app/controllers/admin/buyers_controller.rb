class Admin::BuyersController < ApplicationController
  before_action :authenticate_admin
  before_action :set_buyer, only: [:block, :unblock, :show, :update, :destroy]

  def index 
    if params[:search_query].present?
      @buyers=Buyer.where("phone_number = :query OR id = :query", query: params[:search_query])
    else
      @buyers = Buyer.all
    end

    render json: @buyers
  end

  def show
    # Include orders with nested order items
    buyer = Buyer.includes(orders: { order_items: :ad }).find(params[:id])
    render json: buyer.to_json(include: {
      orders: {
        include: { order_items: { include: :ad } },
        methods: [:order_date, :total_price]
      }
    })
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