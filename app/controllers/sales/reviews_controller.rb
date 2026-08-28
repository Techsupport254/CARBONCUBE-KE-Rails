# app/controllers/sales/reviews_controller.rb
class Sales::ReviewsController < ApplicationController
  before_action :authenticate_sales_user

  # GET /sales/reviews
  def index
    # Show buyer and seller reviews, filtering out deleted/blocked authors and sellers
    @reviews = Review.joins(ad: :seller)
                     .left_joins(:buyer)
                     .where(ads: { deleted: false })
                     .where(sellers: { deleted: false, blocked: false, flagged: false })
                     .where("(buyers.id IS NOT NULL AND buyers.deleted = ?) OR reviews.seller_id IS NOT NULL", false)
                     .includes(:buyer, :seller, :ad)
                     .order(created_at: :desc)

    # Get pagination parameters
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 50
    total = @reviews.count
    
    # Apply pagination
    @reviews = @reviews.offset((page - 1) * per_page).limit(per_page)

    reviews_data = @reviews.map do |review|
      {
        id: review.id,
        rating: review.rating,
        review: review.review,
        seller_reply: review.seller_reply,
        images: review.images,
        created_at: review.created_at&.iso8601,
        updated_at: review.updated_at&.iso8601,
        buyer_id: review.buyer_id,
        seller_id: review.seller_id,
        buyer: review.buyer ? {
          id: review.buyer.id,
          name: review.buyer.fullname || review.buyer.name || "Buyer ##{review.buyer.id}",
          fullname: review.buyer.fullname
        } : nil,
        seller: review.seller ? {
          id: review.seller.id,
          name: review.seller.fullname,
          enterprise_name: review.seller.enterprise_name
        } : nil,
        ad: review.ad ? {
          id: review.ad.id,
          title: review.ad.title,
          price: review.ad.price,
          first_media_url: review.ad.first_media_url
        } : nil
      }
    end

    render json: {
      reviews: reviews_data,
      total: total,
      page: page,
      per_page: per_page
    }
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end

