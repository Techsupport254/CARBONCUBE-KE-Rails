class ReviewsController < ApplicationController
  def index
    ad = Ad.find_by_id_or_slug(params[:id])
    unless ad
      render json: { error: 'Ad not found' }, status: :not_found
      return
    end

    page = (params[:page] || 1).to_i
    per_page = [(params[:per_page] || 50).to_i, 100].min
    reviews = ad.reviews.includes(:buyer, :seller)
                        .order(created_at: :desc)
                        .offset((page - 1) * per_page).limit(per_page)

    reviews_data = reviews.map do |review|
      {
        id: review.id,
        rating: review.rating,
        review: review.review,
        images: review.images,
        seller_reply: review.seller_reply,
        buyer: review.buyer ? {
          id: review.buyer.id,
          name: review.buyer.fullname,
          profile_picture: review.buyer.profile_picture
        } : nil,
        seller: review.seller ? {
          id: review.seller.id,
          enterprise_name: review.seller.enterprise_name,
          profile_picture: review.seller.profile_picture
        } : nil,
        created_at: review.created_at,
        updated_at: review.updated_at
      }
    end

    render json: {
      reviews: reviews_data,
      stats: {
        average_rating: ad.mean_rating,
        total_reviews: ad.review_count
      }
    }, status: :ok
  end
end
