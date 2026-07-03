class Seller::ReviewsController < ApplicationController
  before_action :authenticate_seller
  before_action :current_seller
  before_action :set_branch_context

  def index
    # OPTIMIZATION: Add pagination and limit to avoid loading all reviews
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 50
    per_page = [per_page, 100].min # Cap at 100
    
    reviews_scope = Review.joins(:ad)
                     .where(ads: { seller_id: @current_seller.id })

    if @current_branch
      reviews_scope = reviews_scope.merge(@current_seller.ads.for_branch(@current_branch))
    end

    @reviews = reviews_scope.includes(:buyer)
                     .order(updated_at: :desc)
                     .offset((page - 1) * per_page)
                     .limit(per_page)

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

  def set_branch_context
    branch_id = request.headers['X-Branch-Id']
    if branch_id
      @current_branch = @current_seller.branches.find_by(id: branch_id) if @current_seller
    end
  end
end
