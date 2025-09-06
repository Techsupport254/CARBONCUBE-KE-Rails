class ShopsController < ApplicationController
  def show
    # Find shop by slug (enterprise_name converted to slug)
    slug = params[:slug]
    
    # Convert slug back to enterprise name format for searching
    # Replace hyphens with spaces and handle special characters
    enterprise_name = slug.gsub('-', ' ').gsub('_', ' ')
    
    # First try exact match with case insensitive
    @shop = Seller.includes(:seller_tier, :tier)
                  .where(deleted: false)
                  .where('LOWER(enterprise_name) = ?', enterprise_name.downcase)
                  .first
    
    # If no exact match, try partial match
    unless @shop
      @shop = Seller.includes(:seller_tier, :tier)
                    .where(deleted: false)
                    .where('LOWER(enterprise_name) ILIKE ?', "%#{enterprise_name.downcase}%")
                    .first
    end
    
    # If still no match, try to find by ID as fallback (for backward compatibility)
    unless @shop
      begin
        shop_id = slug.to_i
        if shop_id > 0
          @shop = Seller.includes(:seller_tier, :tier)
                        .where(deleted: false)
                        .find(shop_id)
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
    
    # Calculate review statistics for SEO
    all_reviews = Review.joins(:ad).where(ads: { seller_id: @shop.id })
    total_reviews = all_reviews.count
    average_rating = total_reviews > 0 ? all_reviews.average(:rating).round(1) : 0
    
    # Get shop categories for SEO
    shop_categories = @shop.categories.pluck(:name).join(', ')
    
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
        created_at: @shop.created_at,
        # SEO-specific fields
        fullname: @shop.fullname,
        phone_number: @shop.phone_number,
        city: @shop.city,
        county: @shop.county&.name,
        sub_county: @shop.sub_county&.name,
        business_registration_number: @shop.business_registration_number,
        categories: shop_categories,
        total_reviews: total_reviews,
        average_rating: average_rating,
        slug: slug
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

  def reviews
    # Find shop by slug (enterprise_name converted to slug)
    slug = params[:slug]
    
    # Convert slug back to enterprise name format for searching
    enterprise_name = slug.gsub('-', ' ').gsub('_', ' ')
    
    # First try exact match with case insensitive
    @shop = Seller.includes(:seller_tier, :tier)
                  .where(deleted: false)
                  .where('LOWER(enterprise_name) = ?', enterprise_name.downcase)
                  .first
    
    # If no exact match, try partial match
    unless @shop
      @shop = Seller.includes(:seller_tier, :tier)
                    .where(deleted: false)
                    .where('LOWER(enterprise_name) ILIKE ?', "%#{enterprise_name.downcase}%")
                    .first
    end
    
    # If still no match, try to find by ID as fallback
    unless @shop
      begin
        shop_id = slug.to_i
        if shop_id > 0
          @shop = Seller.includes(:seller_tier, :tier)
                        .where(deleted: false)
                        .find(shop_id)
        end
      rescue ActiveRecord::RecordNotFound
        # Ignore and continue to error handling
      end
    end
    
    unless @shop
      render json: { error: 'Shop not found' }, status: :not_found
      return
    end
    
    # Get pagination parameters
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 10
    
    # Get all reviews for this shop's ads
    @reviews = Review.joins(:ad)
                     .where(ads: { seller_id: @shop.id })
                     .includes(:buyer, :ad)
                     .order(created_at: :desc)
                     .offset((page - 1) * per_page)
                     .limit(per_page)
    
    # Calculate review statistics
    all_reviews = Review.joins(:ad).where(ads: { seller_id: @shop.id })
    total_reviews = all_reviews.count
    average_rating = total_reviews > 0 ? all_reviews.average(:rating).round(1) : 0
    
    # Rating distribution
    rating_distribution = (1..5).map do |rating|
      count = all_reviews.where(rating: rating).count
      percentage = total_reviews > 0 ? (count.to_f / total_reviews * 100).round(1) : 0
      { rating: rating, count: count, percentage: percentage }
    end
    
    # Format reviews data
    reviews_data = @reviews.map do |review|
      {
        id: review.id,
        rating: review.rating,
        review: review.review,
        seller_reply: review.seller_reply,
        created_at: review.created_at,
        updated_at: review.updated_at,
        buyer: {
          id: review.buyer.id,
          name: review.buyer.fullname || review.buyer.name || "Buyer ##{review.buyer.id}"
        },
        ad: {
          id: review.ad.id,
          title: review.ad.title,
          price: review.ad.price
        }
      }
    end
    
    render json: {
      reviews: reviews_data,
      statistics: {
        total_reviews: total_reviews,
        average_rating: average_rating,
        rating_distribution: rating_distribution
      },
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_reviews,
        total_pages: (total_reviews.to_f / per_page).ceil
      }
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Shop not found' }, status: :not_found
  end

  private

end
