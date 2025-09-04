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
      result = get_balanced_ads(per_page)
      @ads = result[:ads]
      @subcategory_counts = result[:subcategory_counts]
    else
      # Use caching for better performance
      cache_key = "buyer_ads_#{per_page}_#{page}_#{params[:category_id]}_#{params[:subcategory_id]}"
      
      @ads = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
        ads_query = Ad.active.joins(:seller)
                     .where(sellers: { blocked: false })
                     .where(flagged: false)
                     .joins(seller: { seller_tier: :tier })
                     .select('ads.*, CASE tiers.id
                               WHEN 4 THEN 1
                               WHEN 3 THEN 2
                               WHEN 2 THEN 3
                               WHEN 1 THEN 4
                               ELSE 5
                             END AS tier_priority')

        ads_query = filter_by_category(ads_query) if params[:category_id].present?
        ads_query = filter_by_subcategory(ads_query) if params[:subcategory_id].present?

        ads_query
          .order('tier_priority ASC, ads.created_at DESC')
          .limit(per_page).offset((page - 1) * per_page)
      end
    end

    render json: {
      ads: @ads.map { |ad| AdSerializer.new(ad).as_json },
      subcategory_counts: @subcategory_counts || {}
    }
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
      .joins(:seller, seller: { seller_tier: :tier })
      .left_joins(:reviews)
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

    # Check if the search query matches any shop names
    matching_shops = []
    if query.present?
      # Find shops that match the search query
      matching_shops = Seller.joins(:seller_tier)
                           .where(blocked: false)
                           .where('enterprise_name ILIKE ?', "%#{query}%")
                           .includes(:seller_tier)
                           .limit(5) # Limit to 5 shops
    end

    # Prepare the response
    response = {
      ads: ads.map { |ad| AdSerializer.new(ad).as_json },
      shops: matching_shops.map do |shop|
        {
          id: shop.id,
          enterprise_name: shop.enterprise_name,
          description: shop.description,
          email: shop.email,
          address: shop.location,
          profile_picture: shop.profile_picture,
          tier: shop.seller_tier&.tier&.name || 'Free',
          tier_id: shop.seller_tier&.tier&.id || 1,
          product_count: Ad.active.where(seller_id: shop.id, flagged: false).count,
          created_at: shop.created_at
        }
      end
    }

    render json: response
  end

  
  # GET /buyer/ads/:id/related
  def related
    # Use @ad from before_action instead of finding it again
    ad = @ad

    # Fetch ads that share either the same category or subcategory
    # Apply the same filters as the main ads endpoint
    related_ads = Ad.active
                    .joins(:seller, seller: { seller_tier: :tier })
                    .where(sellers: { blocked: false })
                    .where(flagged: false)
                    .where.not(id: ad.id)
                    .where('ads.category_id = ? OR ads.subcategory_id = ?', ad.category_id, ad.subcategory_id)
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
                    .order(Arel.sql('CASE tiers.id
                              WHEN 4 THEN 1
                              WHEN 3 THEN 2
                              WHEN 2 THEN 3
                              WHEN 1 THEN 4
                              ELSE 5
                            END ASC, ads.created_at DESC'))
                    .limit(10) # Limit to 10 related ads for performance

    render json: related_ads, each_serializer: AdSerializer
  end


  # GET /buyer/ads/load_more_subcategory
  def load_more_subcategory
    subcategory_id = params[:subcategory_id]
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    
    if subcategory_id.blank?
      render json: { error: 'Subcategory ID is required' }, status: :bad_request
      return
    end
    
    subcategory = Subcategory.find_by(id: subcategory_id)
    unless subcategory
      render json: { error: 'Subcategory not found' }, status: :not_found
      return
    end
    
    # Get total count for this subcategory
    total_count = Ad.active
      .joins(:seller)
      .where(sellers: { blocked: false })
      .where(flagged: false)
      .where(subcategory_id: subcategory_id)
      .count
    
    ads = Ad.active
      .joins(:seller, seller: { seller_tier: :tier })
      .where(sellers: { blocked: false })
      .where(flagged: false)
      .where(subcategory_id: subcategory_id)
      .select('ads.*, CASE tiers.id
                WHEN 4 THEN 1
                WHEN 3 THEN 2
                WHEN 2 THEN 3
                WHEN 1 THEN 4
                ELSE 5
              END AS tier_priority')
      .order(Arel.sql('CASE tiers.id
                WHEN 4 THEN 1
                WHEN 3 THEN 2
                WHEN 2 THEN 3
                WHEN 1 THEN 4
                ELSE 5
              END ASC, ads.created_at DESC'))  # Strict hierarchical order
      .limit(per_page)
      .offset((page - 1) * per_page)
      .includes(:category, :subcategory, :reviews, seller: { seller_tier: :tier })
    
    render json: {
      ads: ads,
      total_count: total_count,
      current_page: page,
      per_page: per_page
    }
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
    
    # Set fixed number of ads per subcategory (20)
    ads_per_subcategory = 20
    
    # Check if we need to load more for a specific subcategory
    subcategory_id = params[:subcategory_id]
    page = params[:page]&.to_i || 1
    
    all_ads = []
    subcategory_counts = {}
    
    if subcategory_id.present?
      # Load more for specific subcategory
      subcategory = Subcategory.find_by(id: subcategory_id)
      if subcategory
        # Get total count for this subcategory
        total_count = Ad.active
          .joins(:seller)
          .where(sellers: { blocked: false })
          .where(flagged: false)
          .where(subcategory_id: subcategory.id)
          .count
        
        subcategory_counts[subcategory.id] = total_count
        
        subcategory_ads = Ad.active
           .joins(:seller, seller: { seller_tier: :tier })
           .where(sellers: { blocked: false })
           .where(flagged: false)
           .where(subcategory_id: subcategory.id)
           .includes(:category, :subcategory, :reviews, seller: { seller_tier: :tier })
           .order(Arel.sql('CASE tiers.id
                     WHEN 4 THEN 1
                     WHEN 3 THEN 2
                     WHEN 2 THEN 3
                     WHEN 1 THEN 4
                     ELSE 5
                   END ASC, ads.created_at DESC'))  # Strict hierarchical order
           .limit(ads_per_subcategory)
           .offset((page - 1) * ads_per_subcategory)
        
        all_ads.concat(subcategory_ads)
      end
    else
      # Regular balanced loading for all subcategories
      categories.each do |category|
        category.subcategories.each do |subcategory|
          # Get total count for this subcategory
          total_count = Ad.active
            .joins(:seller)
            .where(sellers: { blocked: false })
            .where(flagged: false)
            .where(subcategory_id: subcategory.id)
            .count
          
          subcategory_counts[subcategory.id] = total_count
          
          # Get ads for this subcategory, ordered by tier priority first, then by creation date
          subcategory_ads = Ad.active
             .joins(:seller, seller: { seller_tier: :tier })
             .where(sellers: { blocked: false })
             .where(flagged: false)
             .where(subcategory_id: subcategory.id)
             .includes(:category, :subcategory, :reviews, seller: { seller_tier: :tier })
             .order(Arel.sql('CASE tiers.id
                       WHEN 4 THEN 1
                       WHEN 3 THEN 2
                       WHEN 2 THEN 3
                       WHEN 1 THEN 4
                       ELSE 5
                     END ASC, ads.created_at DESC'))  # Strict hierarchical order
             .limit(ads_per_subcategory)
          
          all_ads.concat(subcategory_ads)
        end
      end
    end
    
    # Return both ads and subcategory counts
    {
      ads: all_ads,
      subcategory_counts: subcategory_counts
    }
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
