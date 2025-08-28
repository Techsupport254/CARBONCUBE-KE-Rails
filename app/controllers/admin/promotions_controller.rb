class Admin::PromotionsController < ApplicationController
  before_action :set_promotion, only: [:show, :update, :destroy]

  # GET /admin/promotions
  def index
    @promotions = Promotion.all
    render json: @promotions, each_serializer: PromotionSerializer
  end

  # GET /admin/promotions/:id
  def show
    render json: @promotion, serializer: PromotionSerializer
  end

  # POST /admin/promotions
  def create
    @promotion = Promotion.new(promotion_params)

    if @promotion.save
      render json: @promotion, status: :created, serializer: PromotionSerializer
    else
      render json: @promotion.errors, status: :unprocessable_entity
    end
  end

  # PUT /admin/promotions/:id
  def update
    if @promotion.update(promotion_params)
      render json: @promotion, serializer: PromotionSerializer
    else
      render json: @promotion.errors, status: :unprocessable_entity
    end
  end

  # DELETE /admin/promotions/:id
  def destroy
    @promotion.destroy
    head :no_content
  end

  private

  def set_promotion
    @promotion = Promotion.find(params[:id])
  end

  def promotion_params
    params.require(:promotion).permit(:title, :description, :discount_percentage, :start_date, :end_date, :coupon_code)
  end
end
