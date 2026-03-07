class ReviewsController < ApplicationController
  def index
    ad = Ad.find(params[:id])
    reviews = ad.reviews.includes(:buyer)

    reviews_data = reviews.map do |review|
      {
        id: review.id,
        rating: review.rating,
        review: review.review,
        images: review.images,
        seller_reply: review.seller_reply,
        buyer: {
          id: review.buyer.id,
          name: review.buyer.fullname,
          profile_picture: review.buyer.profile_picture
        },
        created_at: review.created_at,
        updated_at: review.updated_at
      }
    end

    render json: reviews_data, status: :ok
  end
end
