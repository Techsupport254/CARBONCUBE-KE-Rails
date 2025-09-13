class Admin::Seller::AnalyticsController < ApplicationController
  before_action :authenticate_admin
  before_action :set_seller

  # GET /admin/sellers/:seller_id/analytics
  def show
    # Calculate total revenue from all orders related to the seller's ads
    total_revenue = @seller.orders.joins(:order_items)
                              .where(order_items: { ad_id: @seller.ads.pluck(:id) })
                              .sum('order_items.quantity * order_items.price')

    # Calculate total number of orders related to the seller's ads
    total_orders = @seller.orders.joins(:order_items)
                              .where(order_items: { ad_id: @seller.ads.pluck(:id) })
                              .distinct.count


    # Calculate average rating (mean of ratings) from reviews related to the seller's ads
    mean_rating = @seller.reviews.joins(:ad)
                          .where(ads: { id: @seller.ads.pluck(:id) })
                          .average(:rating).to_f

    # Count the number of reviews related to the seller's ads and group by rating
    reviews_by_rating = @seller.reviews.joins(:ad)
                                  .where(ads: { id: @seller.ads.pluck(:id) })
                                  .group(:rating)
                                  .count

    # Prepare data for pie chart
    rating_pie_chart = (1..5).map do |rating|
      {
        rating: rating,
        count: reviews_by_rating[rating] || 0
      }
    end

    # Fetch detailed reviews with buyer information
    reviews_details = @seller.reviews.joins(:ad, :buyer)
                              .where(ads: { id: @seller.ads.pluck(:id) })
                              .select('reviews.*, buyers.fullname AS buyer_name')
                              .as_json(only: [:id, :rating, :review, :created_at],
                                        include: { buyer: { only: [:fullname] } })

    # Prepare the analytics response
    analytics = {
      total_revenue: total_revenue,
      total_orders: total_orders,
      mean_rating: mean_rating,
      total_reviews: reviews_by_rating.values.sum,
      rating_pie_chart: rating_pie_chart,
      reviews: reviews_details
    }

    render json: analytics
  end

  private

  def set_seller
    @seller = Seller.find(params[:seller_id])
  end

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end
