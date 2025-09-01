# app/controllers/buyer/ads_controller.rb
class Buyer::AdsController < ApplicationController
  before_action :set_ad, only: [:show, :seller, :related]

  # GET /buyer/ads
  def index
    per_page = params[:per_page]&.to_i || 50
    per_page = 500 if per_page > 500
    page = params[:page].to_i.positive? ? params[:page].to_i : 1

    @ads = Ad.active.joins(:seller)
            .where(sellers: { blocked: false })
            .where(flagged: false)
            .includes(
              :category,
              :subcategory,
              seller: { seller_tier: :tier }
            )

    filter_by_category if params[:category_id].present?
    filter_by_subcategory if params[:subcategory_id].present?

    # For the home page, get a balanced distribution of ads across subcategories
    if params[:balanced] == 'true' || (params[:per_page]&.to_i || 50) > 100
      @ads = get_balanced_ads(per_page)
    else
      @ads = @ads.order(created_at: :desc)
              .limit(per_page).offset((page - 1) * per_page)
    end

    render json: @ads, each_serializer: AdSerializer
  end

  # GET /buyer/ads/:id
  def show
    @ad = Ad.find(params[:id])
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
      .joins(seller: { seller_tier: :tier })
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
        seller: { seller_tier: :tier }
      )
      .order('tier_priority ASC, ads.created_at DESC')
      .distinct

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
    # Use a single optimized query with window functions to get balanced ads
    # This approach uses ROW_NUMBER() to rank ads within each subcategory
    # and then selects the top N from each subcategory
    
    sql = <<-SQL
      WITH ranked_ads AS (
        SELECT 
          ads.*,
          ROW_NUMBER() OVER (
            PARTITION BY ads.subcategory_id 
            ORDER BY ads.created_at DESC
          ) as rn
        FROM ads
        INNER JOIN sellers ON sellers.id = ads.seller_id
        WHERE ads.deleted = false 
          AND sellers.blocked = false 
          AND ads.flagged = false
      )
      SELECT * FROM ranked_ads 
      WHERE rn <= 10
      ORDER BY created_at DESC
      LIMIT ?
    SQL
    
    # Execute the raw SQL and map to Ad objects
    result = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, per_page])
    )
    
    # Get the ad IDs from the result
    ad_ids = result.map { |row| row['id'] }
    
    # Return empty if no ads found
    return Ad.none if ad_ids.empty?
    
    # Fetch the full Ad objects with includes in the correct order
    Ad.where(id: ad_ids)
      .includes(:category, :subcategory, seller: { seller_tier: :tier })
      .order(Arel.sql("position(id::text in '#{ad_ids.join(',')}')"))
  end

  def set_ad
    @ad = Ad.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ad not found' }, status: :not_found
  end

  def filter_by_category
    @ads = @ads.where(category_id: params[:category_id])
  end

  def filter_by_subcategory
    @ads = @ads.where(subcategory_id: params[:subcategory_id])
  end

  def ad_params
    params.require(:ad).permit(:title, :description, { media: [] }, :subcategory_id, :category_id, :seller_id, :price, :quantity, :brand, :manufacturer, :item_length, :item_width, :item_height, :item_weight, :weight_unit, :condition)
  end
end
