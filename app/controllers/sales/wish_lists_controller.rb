# app/controllers/sales/wish_lists_controller.rb
class Sales::WishListsController < ApplicationController
  before_action :authenticate_sales_user

  # GET /sales/wishlists
  def index
    # Filter out wishlists from deleted/blocked buyers and blocked/deleted sellers
    @wishlists = WishList.joins(:buyer, ad: :seller)
                         .where(buyers: { deleted: false })
                         .where(sellers: { deleted: false, blocked: false })
                         .includes(:buyer, :ad)
                         .order(created_at: :desc)

    # Get pagination parameters
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 50
    total = @wishlists.count
    
    # Apply pagination
    @wishlists = @wishlists.offset((page - 1) * per_page).limit(per_page)

    wishlists_data = @wishlists.map do |wishlist|
      ad_data = wishlist.ad
      {
        id: wishlist.id,
        buyer_id: wishlist.buyer_id,
        seller_id: wishlist.seller_id,
        ad_id: wishlist.ad_id,
        created_at: wishlist.created_at&.iso8601,
        buyer: wishlist.buyer ? {
          id: wishlist.buyer.id,
          name: wishlist.buyer.fullname || wishlist.buyer.name || "Buyer ##{wishlist.buyer.id}",
          email: wishlist.buyer.email
        } : nil,
        ad: ad_data ? {
          id: ad_data.id,
          title: ad_data.title,
          price: ad_data.price,
          first_media_url: ad_data.first_media_url,
          rating: ad_data.mean_rating
        } : nil
      }
    end

    render json: {
      wishlists: wishlists_data,
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

