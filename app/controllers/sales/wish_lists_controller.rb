# app/controllers/sales/wish_lists_controller.rb
class Sales::WishListsController < ApplicationController
  before_action :authenticate_sales_user

  # GET /sales/wishlists
  def index
    # Filter out deleted ads and blocked/deleted ad sellers
    @wishlists = WishList.joins(ad: :seller)
                         .where(ads: { deleted: false })
                         .where(sellers: { deleted: false, blocked: false, flagged: false })
                         .includes(:buyer, :seller, ad: :seller)
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
      bookmarker_data = wishlist.buyer || wishlist.seller
      seller_data = ad_data&.seller
      
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
        buyer: bookmarker_data ? {
          id: bookmarker_data.id,
          name: bookmarker_data.respond_to?(:enterprise_name) ? (bookmarker_data.enterprise_name || bookmarker_data.fullname || bookmarker_data.username || "Seller ##{bookmarker_data.id}") : (bookmarker_data.fullname || bookmarker_data.name || "Buyer ##{bookmarker_data.id}"),
          email: bookmarker_data.email,
          profile_picture: bookmarker_data.profile_picture
        } : nil,
        ad: ad_data ? {
          id: ad_data.id,
          title: ad_data.title || "Untitled Product",
          price: ad_data.price&.to_f || 0.0,
          category_name: ad_data.category_name,
          subcategory_name: ad_data.subcategory_name,
          first_media_url: ad_data.first_media_url,
          rating: ad_rating && ad_rating > 0 ? ad_rating.round(1) : nil,
          seller: seller_data ? {
            id: seller_data.id,
            shop_name: seller_data.enterprise_name,
            name: seller_data.fullname || seller_data.username || "Seller ##{seller_data.id}",
            profile_picture: seller_data.profile_picture
          } : nil
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
