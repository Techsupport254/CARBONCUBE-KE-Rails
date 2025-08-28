class Seller::ReviewsController < ApplicationController
  before_action :authenticate_seller
  before_action :current_seller

  def index
    @reviews = Review.joins(:ad).where(ads: { seller_id: @current_seller.id }).includes(:buyer).order(updated_at: :desc)

    render json: @reviews.map { |review|
      {
        id: review.id,
        rating: review.rating,
        review: review.review,
        seller_reply: review.seller_reply,
        created_at: review.created_at,
        updated_at: review.updated_at,
        buyer_id: review.buyer_id,
        buyer_name: review.buyer.fullname || review.buyer.name || "Buyer ##{review.buyer.id}"
      }
    }
  end

  def show
    @review = Review.find(params[:id])
    render json: @review
  end

  # POST /seller/reviews/:id/reply
  def reply
    @review = Review.find(params[:id])
    if @review.update(seller_reply: params[:seller_reply])
      render json: @review
    else
      render json: { error: 'Update failed' }, status: 422
    end
  end

  private

  def authenticate_seller
    @current_user = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: 401
    end
  end

  def current_seller
    @current_seller = @current_user
  end
end
