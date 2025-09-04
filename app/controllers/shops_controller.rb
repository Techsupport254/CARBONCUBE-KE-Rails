class ShopsController < ApplicationController
  def show
    # Find shop by slug (enterprise_name converted to slug)
    slug = params[:slug]
    
    # Convert slug back to enterprise name format for searching
    # Replace hyphens with spaces and handle special characters
    enterprise_name = slug.gsub('-', ' ').gsub('_', ' ')
    
    # First try exact match with case insensitive
    @shop = Seller.includes(:seller_tier, :tier)
                  .where('LOWER(enterprise_name) = ?', enterprise_name.downcase)
                  .first
    
    # If no exact match, try partial match
    unless @shop
      @shop = Seller.includes(:seller_tier, :tier)
                    .where('LOWER(enterprise_name) ILIKE ?', "%#{enterprise_name.downcase}%")
                    .first
    end
    
    # If still no match, try to find by ID as fallback (for backward compatibility)
    unless @shop
      begin
        shop_id = slug.to_i
        if shop_id > 0
          @shop = Seller.includes(:seller_tier, :tier).find(shop_id)
        end
      rescue ActiveRecord::RecordNotFound
        # Ignore and continue to error handling
      end
    end
    
    unless @shop
      render json: { error: 'Shop not found' }, status: :not_found
      return
    end
    
    # Get shop's active ads with pagination
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    
    @ads = @shop.ads
                .active
                .where(flagged: false)
                .joins(:category, :subcategory, seller: { seller_tier: :tier })
                .left_joins(:reviews)
                .includes(:category, :subcategory, :reviews, seller: { seller_tier: :tier })
                .order('tiers.id DESC, ads.created_at DESC')
                .offset((page - 1) * per_page)
                .limit(per_page)
    
    # Get total count for pagination
    @total_count = @shop.ads.active.where(flagged: false).count
    
    render json: {
      shop: {
        id: @shop.id,
        enterprise_name: @shop.enterprise_name,
        description: @shop.description,
        email: @shop.email,
        address: @shop.location,
        profile_picture: @shop.profile_picture,
        tier: @shop.seller_tier&.tier&.name || 'Free',
        tier_id: @shop.seller_tier&.tier&.id || 1,
        product_count: @total_count,
        created_at: @shop.created_at
      },
      ads: @ads.map { |ad| AdSerializer.new(ad).as_json },
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: @total_count,
        total_pages: (@total_count.to_f / per_page).ceil
      }
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Shop not found' }, status: :not_found
  end
end
