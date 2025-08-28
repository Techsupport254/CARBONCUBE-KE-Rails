class ReviewsController < ApplicationController
  def index
    ad = Ad.find(params[:id])
    reviews = ad.reviews.includes(:buyer)

    reviews_data = reviews.map do |review|
      {
        rating: review.rating,
        review: review.review,
        buyer: {
          id: review.buyer.id,
          name: review.buyer.fullname
        }
      }
    end

    render json: reviews_data, status: :ok
  end
end
