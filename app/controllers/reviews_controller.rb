class ReviewsController < ApplicationController
  def index
    ad = Ad.find(params[:id])
    reviews = ad.reviews.includes(:buyer, :seller)

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
