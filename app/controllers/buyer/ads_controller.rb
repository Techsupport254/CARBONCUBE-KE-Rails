# app/controllers/buyer/ads_controller.rb
class Buyer::AdsController < ApplicationController
  before_action :set_ad, only: [:show, :seller, :related]

  # GET /buyer/ads
  def index
    per_page = params[:per_page]&.to_i || 50
    per_page = 500 if per_page > 500
    page = params[:page].to_i.positive? ? params[:page].to_i : 1

    # For the home page, get a balanced distribution of ads across subcategories
    if params[:balanced] == 'true' || (params[:per_page]&.to_i || 50) > 100
      @ads = get_balanced_ads(per_page)
    else
      # Use caching for better performance
      cache_key = "buyer_ads_#{per_page}_#{page}_#{params[:category_id]}_#{params[:subcategory_id]}"
      
      @ads = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
        ads_query = Ad.active.joins(:seller)
                     .where(sellers: { blocked: false })
                     .where(flagged: false)
                     .includes(
                       :category,
                       :subcategory,
                       :reviews,
                       seller: { seller_tier: :tier }
                     )

        ads_query = filter_by_category(ads_query) if params[:category_id].present?
        ads_query = filter_by_subcategory(ads_query) if params[:subcategory_id].present?

        ads_query.order(created_at: :desc)
                .limit(per_page).offset((page - 1) * per_page)
      end
    end

    render json: @ads, each_serializer: AdSerializer
  end

  # GET /buyer/ads/:id
  def show
    @ad = Ad.includes(
      :category,
      :subcategory,
      :reviews,
      seller: { seller_tier: :tier }
    ).find(params[:id])
    render json: @ad, serializer: AdSerializer, include_reviews: true
  end
  

  # GET /buyer/ads/search
  def search
    query = params[:query].to_s.strip
    category_param = params[:category]
    subcategory_param = params[:subcategory]

    ads = Ad.active.joins(:seller, :category, :subcategory)
            .where(sellers: { blocked: false })
            .where(flagged: false)

    if query.present?
      query_words = query.split(/\s+/)
      query_words.each do |word|
        ads = ads.where(
        'ads.title ILIKE :word
          OR ads.description ILIKE :word
          OR categories.name ILIKE :word
          OR subcategories.name ILIKE :word
          OR sellers.enterprise_name ILIKE :word',
       word: "%#{word}%"
)

      end
    end

    if category_param.present? && category_param != 'All'
      if category_param.to_s.match?(/\A\d+\z/)
        ads = ads.where(category_id: category_param.to_i)
      else
        category = Category.find_by(name: category_param)
        ads = ads.where(category_id: category.id) if category
      end
    end

    if subcategory_param.present? && subcategory_param != 'All'
      if subcategory_param.to_s.match?(/\A\d+\z/)
        ads = ads.where(subcategory_id: subcategory_param.to_i)
      else
        subcategory = Subcategory.find_by(name: subcategory_param)
        ads = ads.where(subcategory_id: subcategory.id) if subcategory
      end
    end

    ads = ads
      .joins(:seller, :reviews, seller: { seller_tier: :tier })
      .select('ads.*, CASE tiers.id
                        WHEN 4 THEN 1
                        WHEN 3 THEN 2
                        WHEN 2 THEN 3
                        WHEN 1 THEN 4
                        ELSE 5
                      END AS tier_priority')
      .includes(
        :category,
        :subcategory,
        :reviews,
        seller: { seller_tier: :tier }
      )
      .order('tier_priority ASC, ads.created_at DESC')

    render json: ads, each_serializer: AdSerializer
  end

  
  # GET /buyer/ads/:id/related
  def related
    ad = Ad.find(params[:id])

    # Fetch ads that share either the same category or subcategory
    # Apply the same filters as the main ads endpoint
    related_ads = Ad.active
                    .joins(:seller)
                    .where(sellers: { blocked: false })
                    .where(flagged: false)
                    .where.not(id: ad.id)
                    .where('category_id = ? OR subcategory_id = ?', ad.category_id, ad.subcategory_id)
                    .includes(
                      :category,
                      :subcategory,
                      :reviews,
                      seller: { seller_tier: :tier }
                    )
                    .order('ads.created_at DESC')
                    .limit(10) # Limit to 10 related ads for performance

    render json: related_ads, each_serializer: AdSerializer
  end


  # GET /buyer/ads/:id/seller
  def seller
    @seller = @ad.seller
    if @seller
      render json: @seller, serializer: SellerSerializer
    else
      render json: { error: 'Seller not found' }, status: :not_found
    end
  end

  private

  def get_balanced_ads(per_page)
    # Get all categories with their subcategories
    categories = Category.includes(:subcategories).all
    
    # Calculate how many ads to get per subcategory to achieve balance
    total_subcategories = categories.sum { |cat| cat.subcategories.count }
    ads_per_subcategory = [per_page / total_subcategories, 1].max
    
    all_ads = []
    
    categories.each do |category|
      category.subcategories.each do |subcategory|
        # Get ads for this subcategory, ordered by tier priority
        subcategory_ads = Ad.active
           .joins(:seller, seller: { seller_tier: :tier })
           .where(sellers: { blocked: false })
           .where(flagged: false)
           .where(subcategory_id: subcategory.id)
           .select('ads.*, CASE tiers.id
                     WHEN 4 THEN 1
                     WHEN 3 THEN 2
                     WHEN 2 THEN 3
                     WHEN 1 THEN 4
                     ELSE 5
                   END AS tier_priority')
           .order('tier_priority ASC, ads.created_at DESC')
           .limit(ads_per_subcategory)
           .preload(:category, :subcategory, :reviews, seller: { seller_tier: :tier })
        
        all_ads.concat(subcategory_ads)
      end
    end
    
    # Sort the final result by tier priority and creation date
    all_ads.sort_by { |ad| [ad.tier_priority || 5, ad.created_at] }.reverse
  end

  def set_ad
    @ad = Ad.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ad not found' }, status: :not_found
  end

  def filter_by_category(ads_query)
    ads_query.where(category_id: params[:category_id])
  end

  def filter_by_subcategory(ads_query)
    ads_query.where(subcategory_id: params[:subcategory_id])
  end

  def ad_params
    params.require(:ad).permit(:title, :description, { media: [] }, :subcategory_id, :category_id, :seller_id, :price, :quantity, :brand, :manufacturer, :item_length, :item_width, :item_height, :item_weight, :weight_unit, :condition)
  end
end
