class Buyer::ReviewsController < ApplicationController
  before_action :authenticate_buyer
  before_action :set_ad, only: [:index, :create]
  before_action :set_review, only: [:show, :update, :destroy]

  # GET /buyer/ads/:ad_id/reviews
  def index
    @reviews = @ad.reviews
    render json: @reviews
  end

  # GET /buyer/ads/:ad_id/reviews/:id
  def show
    render json: @review
  end

  # POST /buyer/ads/:ad_id/reviews
  def create
    @review = @ad.reviews.new(review_params)
    @review.buyer = current_buyer

    if @review.save
      render json: @review, status: :created
    else
      render json: @review.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /buyer/ads/:ad_id/reviews/:id
  def update
    if @review.update(review_params)
      render json: @review
    else
      render json: @review.errors, status: :unprocessable_entity
    end
  end

  # DELETE /buyer/ads/:ad_id/reviews/:id
  def destroy
    @review.destroy
    head :no_content
  end

  private

  def set_ad
    @ad = Ad.active.find(params[:ad_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ad not found' }, status: :not_found
  end

  def set_review
    @review = current_buyer.reviews.find_by!(id: params[:id], ad_id: params[:ad_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Review not found' }, status: :not_found
  end

  def review_params
    params.require(:review).permit(:rating, :review)
  end

  def authenticate_buyer
    @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
    unless @current_user&.is_a?(Buyer)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_buyer
    @current_user
  end
end
