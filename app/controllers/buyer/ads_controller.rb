# app/controllers/buyer/ads_controller.rb
class Buyer::AdsController < ApplicationController
  before_action :set_ad, only: [:show, :seller, :related]

  # GET /buyer/ads
  def index
    per_page = params[:per_page]&.to_i || 500  # ✅ Default to fetching all ads if not specified
    page = params[:page].to_i.positive? ? params[:page].to_i : 1

    @ads = Ad.active.joins(:seller)
            .where(sellers: { blocked: false })
            .where(flagged: false)
            .includes(
              :category,
              :subcategory,
              :reviews,
              seller: { seller_tier: :tier }
            )
            .preload(:reviews)

    filter_by_category if params[:category_id].present?
    filter_by_subcategory if params[:subcategory_id].present?

    @ads = @ads.limit(per_page).offset((page - 1) * per_page)

    # ✅ Group ads by subcategory for frontend
    grouped_ads = @ads.group_by(&:subcategory_id)
    
    # Pre-calculate review statistics to avoid N+1 queries
    ad_ids = @ads.pluck(:id)
    review_stats = Review.where(ad_id: ad_ids)
                        .group(:ad_id)
                        .select('ad_id, COUNT(*) as count, AVG(rating) as average')
                        .index_by(&:ad_id)
    
    # Serialize each group of ads properly using the serializer
    serialized_ads = {}
    grouped_ads.each do |subcategory_id, ads_array|
      # Attach pre-calculated review stats to each ad
      ads_array.each do |ad|
        if review_stats[ad.id]
          ad.define_singleton_method(:review_stats) do
            {
              count: review_stats[ad.id].count,
              average: review_stats[ad.id].average.to_f
            }
          end
        end
      end
      
      serialized_ads[subcategory_id] = ActiveModel::Serializer::CollectionSerializer.new(
        ads_array, 
        serializer: AdSerializer
      ).as_json
    end

    render json: serialized_ads
  end

  # GET /buyer/ads/:id
  def show
    @ad = Ad.find(params[:id])
    render json: @ad, serializer: AdSerializer
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
        :reviews,
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
                      :reviews,
                      seller: { seller_tier: :tier }
                    )
                    .order('ads.created_at DESC')
                    .limit(10) # Limit to 10 related ads for performance
                    .distinct

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
