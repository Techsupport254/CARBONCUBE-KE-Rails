# app/controllers/sales/wish_lists_controller.rb
class Sales::WishListsController < ApplicationController
  before_action :authenticate_sales_user

  # GET /sales/wishlists
  def index
    # Filter out wishlists from deleted/blocked buyers, blocked/deleted sellers, and deleted ads
    @wishlists = WishList.joins(:buyer, ad: :seller)
                         .where(buyers: { deleted: false })
                         .where(sellers: { deleted: false, blocked: false, flagged: false })
                         .where(ads: { deleted: false })
                         .includes(:buyer, :ad)
                         .order('wish_lists.created_at DESC')

    # Get pagination parameters
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 50
    total = @wishlists.count
    
    # Apply pagination
    @wishlists = @wishlists.offset((page - 1) * per_page).limit(per_page)

    # Preload reviews to avoid N+1 queries when calculating mean_rating
    ad_ids = @wishlists.map(&:ad_id).compact.uniq
    reviews_by_ad = Review.where(ad_id: ad_ids).group(:ad_id).average(:rating) if ad_ids.any?
    
    wishlists_data = @wishlists.map do |wishlist|
      ad_data = wishlist.ad
      buyer_data = wishlist.buyer
      
      # Calculate mean rating for the ad using preloaded data
      ad_rating = if ad_data && reviews_by_ad
        reviews_by_ad[ad_data.id]&.to_f || 0.0
      elsif ad_data
        # Fallback to method if preload didn't work
        ad_data.respond_to?(:mean_rating) ? ad_data.mean_rating : 0.0
      else
        nil
      end
      
      {
        id: wishlist.id,
        buyer_id: wishlist.buyer_id,
        seller_id: wishlist.seller_id,
        ad_id: wishlist.ad_id,
        created_at: wishlist.created_at&.iso8601,
        buyer: buyer_data ? {
          id: buyer_data.id,
          name: buyer_data.fullname || buyer_data.name || "Buyer ##{buyer_data.id}",
          email: buyer_data.email
        } : nil,
        ad: ad_data ? {
          id: ad_data.id,
          title: ad_data.title || "Untitled Product",
          price: ad_data.price&.to_f || 0.0,
          category_name: ad_data.category_name,
          subcategory_name: ad_data.subcategory_name,
          first_media_url: ad_data.first_media_url,
          rating: ad_rating && ad_rating > 0 ? ad_rating.round(1) : nil
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
