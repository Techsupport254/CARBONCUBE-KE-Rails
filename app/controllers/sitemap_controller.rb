class SitemapController < ApplicationController
  # GET /sitemap
  # Main sitemap endpoint - returns XML sitemap
  def index
    @ads = Ad.active.with_valid_images
             .joins(:seller)
             .where(sellers: { blocked: false, deleted: false })
             .where(flagged: false)
             .includes(:category, :subcategory, seller: { seller_tier: :tier })
             .limit(1000) # Limit for performance

    @sellers = Seller.where(blocked: false, deleted: false)
                     .includes(:seller_tier)
                     .limit(500)

    @categories = Category.includes(:subcategories)

    respond_to do |format|
      format.xml { render layout: false }
    end
  end

  # GET /sitemap/ads
  # Dedicated endpoint for sitemap generation - returns all active ads
  def ads
    # Get all active ads without pagination limits for sitemap generation
    @ads = Ad.active.with_valid_images
             .joins(:seller)
             .where(sellers: { blocked: false, deleted: false })
             .where(flagged: false)
             .includes(:category, :subcategory, seller: { seller_tier: :tier })
             .order(Arel.sql('RANDOM()'))

    render json: @ads
  end

  # GET /sitemap/sellers
  # Dedicated endpoint for sitemap generation - returns all active sellers
  def sellers
    # Get all active sellers without pagination limits for sitemap generation
    @sellers = Seller.where(blocked: false, deleted: false)
                     .includes(:seller_tier)

    render json: @sellers
  end

  # GET /sitemap/categories
  # Dedicated endpoint for sitemap generation - returns all categories
  def categories
    @categories = Category.includes(:subcategories)

    render json: @categories
  end

  # GET /sitemap/subcategories
  # Dedicated endpoint for sitemap generation - returns all subcategories
  def subcategories
    @subcategories = Subcategory.includes(:category)

    render json: @subcategories
  end

  # GET /sitemap/stats
  # Returns statistics for sitemap generation
  def stats
    stats = {
      total_ads: Ad.count,
      active_ads: Ad.active.count,
      non_deleted_ads: Ad.where(deleted: false).count,
      non_flagged_ads: Ad.where(flagged: false).count,
      active_non_deleted_non_flagged_ads: Ad.active
                                           .where(deleted: false, flagged: false)
                                           .joins(:seller)
                                           .where(sellers: { blocked: false, deleted: false })
                                           .count,
      total_sellers: Seller.count,
      active_sellers: Seller.where(blocked: false, deleted: false).count,
      total_categories: Category.count,
      total_subcategories: Subcategory.count
    }

    render json: stats
  end
end
