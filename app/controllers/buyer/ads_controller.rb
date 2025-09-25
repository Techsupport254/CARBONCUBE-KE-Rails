# app/controllers/buyer/ads_controller.rb
class Buyer::AdsController < ApplicationController
  before_action :set_ad, only: [:show, :seller, :related]

  # GET /buyer/ads
  def index
    per_page = params[:per_page]&.to_i || 24
    per_page = 500 if per_page > 500
    page = params[:page].to_i.positive? ? params[:page].to_i : 1

    # For the home page, get a balanced distribution of ads across subcategories
    # Only use balanced distribution if explicitly requested AND no category filtering
    if params[:balanced] == 'true' && !params[:category_id].present? && !params[:subcategory_id].present?
      result = get_balanced_ads(per_page)
      @ads = result[:ads]
      @subcategory_counts = result[:subcategory_counts]
    else
      # Use caching for better performance
      cache_key = "buyer_ads_#{per_page}_#{page}_#{params[:category_id]}_#{params[:subcategory_id]}"
      
      @ads = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
        ads_query = Ad.active.with_valid_images.joins(:seller)
                     .where(sellers: { blocked: false, deleted: false })
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
          .order('tier_priority ASC, RANDOM()')
          .limit(per_page).offset((page - 1) * per_page)
      end
    end

    # Calculate total count for pagination
    total_count = if params[:balanced] == 'true' && !params[:category_id].present? && !params[:subcategory_id].present?
      # For balanced ads, we need to count all active ads
      Ad.active.with_valid_images.joins(:seller)
         .where(sellers: { blocked: false, deleted: false })
         .where(flagged: false)
         .count
    else
      # For filtered ads, count with same filters
      ads_query = Ad.active.with_valid_images.joins(:seller)
                    .where(sellers: { blocked: false, deleted: false })
                    .where(flagged: false)
      
      ads_query = filter_by_category(ads_query) if params[:category_id].present?
      ads_query = filter_by_subcategory(ads_query) if params[:subcategory_id].present?
      
      ads_query.count
    end

    render json: {
      ads: @ads.map { |ad| AdSerializer.new(ad).as_json },
      subcategory_counts: @subcategory_counts || {},
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
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
    
    # Pagination parameters
    ads_page = params[:ads_page]&.to_i || params[:page]&.to_i || 1
    shops_page = params[:shops_page]&.to_i || params[:page]&.to_i || 1
    ads_per_page = params[:ads_per_page]&.to_i || 24
    shops_per_page = params[:shops_per_page]&.to_i || 10
    
    # Ensure positive values
    ads_page = 1 if ads_page < 1
    shops_page = 1 if shops_page < 1
    ads_per_page = 24 if ads_per_page < 1 || ads_per_page > 100
    shops_per_page = 10 if shops_per_page < 1 || shops_per_page > 50

    ads = Ad.active.with_valid_images.joins(:seller, :category, :subcategory)
            .where(sellers: { blocked: false, deleted: false })
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

    # Get total count for pagination
    ads_total_count = ads.count
    
    ads = ads
      .joins(:seller, seller: { seller_tier: :tier })
      .select('ads.*, 
               CASE tiers.id
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
                      END ASC, RANDOM()'))
      .limit(ads_per_page)
      .offset((ads_page - 1) * ads_per_page)

    # Enhanced shop search - find shops that match query OR have products matching the query
    matching_shops = []
    if query.present?
      # Find shops that match the search query by name
      name_matching_shops = Seller.joins(:seller_tier)
                                 .where(blocked: false, deleted: false)
                                 .where('enterprise_name ILIKE ?', "%#{query}%")
                                 .includes(:seller_tier)
      
      # Find shops that have products matching the search query
      # Split query into individual words for better matching
      query_words = query.split(/\s+/).reject(&:blank?)
      
      if query_words.length > 1
        # For multi-word queries, search for shops that have products containing ALL words
        conditions = query_words.map do |word|
          '(ads.title ILIKE :word OR ads.description ILIKE :word OR categories.name ILIKE :word OR subcategories.name ILIKE :word)'
        end.join(' AND ')
        
        product_matching_shops = Seller.joins(:seller_tier, :ads)
                                      .joins('JOIN categories ON ads.category_id = categories.id')
                                      .joins('JOIN subcategories ON ads.subcategory_id = subcategories.id')
                                      .where(blocked: false, deleted: false)
                                      .where('ads.flagged = ?', false)
                                      .where(conditions, query_words.map { |word| { word: "%#{word}%" } }.reduce({}, :merge))
                                      .includes(:seller_tier)
                                      .distinct
      else
        # For single word queries, use the original logic
        product_matching_shops = Seller.joins(:seller_tier, :ads)
                                      .joins('JOIN categories ON ads.category_id = categories.id')
                                      .joins('JOIN subcategories ON ads.subcategory_id = subcategories.id')
                                      .where(blocked: false, deleted: false)
                                      .where('ads.flagged = ?', false)
                                      .where('ads.title ILIKE :query OR ads.description ILIKE :query OR categories.name ILIKE :query OR subcategories.name ILIKE :query', 
                                             query: "%#{query}%")
                                      .includes(:seller_tier)
                                      .distinct
      end
      
      # Combine and deduplicate shops
      all_matching_shops = (name_matching_shops + product_matching_shops).uniq
      
      # Calculate shop scores for ranking
      matching_shops = all_matching_shops.map do |shop|
        # Calculate various scoring factors
        tier_score = case shop.seller_tier&.tier&.id
                    when 4 then 100  # Premium
                    when 3 then 80   # Gold
                    when 2 then 60   # Silver
                    when 1 then 40   # Bronze
                    else 20          # Free
                    end
        
        # Product count score (more products = higher score)
        product_count = Ad.active.with_valid_images.where(seller_id: shop.id, flagged: false).count
        product_score = [product_count * 2, 50].min # Cap at 50 points
        
        # Rating score (if reviews exist) - get overall average for the seller
        avg_rating = Ad.joins(:reviews)
                      .where(seller_id: shop.id)
                      .average('reviews.rating')
        avg_rating = avg_rating ? avg_rating.to_f : 0.0
        rating_score = avg_rating > 0 ? (avg_rating * 10).round : 0
        
        # Recency score (newer shops get slight boost)
        created_at = shop.created_at.is_a?(Time) ? shop.created_at : Time.parse(shop.created_at.to_s)
        days_since_created = (Time.current - created_at) / 1.day
        recency_score = [30 - days_since_created.to_i, 0].max
        
        # Name match bonus (shops with name matching get extra points)
        name_match_bonus = shop.enterprise_name.downcase.include?(query.downcase) ? 20 : 0
        
        # Calculate total score
        total_score = tier_score + product_score + rating_score + recency_score + name_match_bonus
        
        {
          shop: shop,
          score: total_score,
          tier_score: tier_score,
          product_score: product_score,
          rating_score: rating_score,
          recency_score: recency_score,
          name_match_bonus: name_match_bonus,
          product_count: product_count,
          avg_rating: avg_rating
        }
      end.sort_by { |item| -item[:score] } # Sort by score descending
      
      # Apply pagination to shops
      shops_total_count = matching_shops&.length || 0
      paginated_shops = matching_shops&.slice((shops_page - 1) * shops_per_page, shops_per_page) || []
    else
      paginated_shops = []
      shops_total_count = 0
    end

    # Prepare the response
    response = {
      ads: ads.map { |ad| AdSerializer.new(ad).as_json },
      shops: paginated_shops.map do |shop_data|
        shop = shop_data[:shop]
        {
          id: shop.id,
          enterprise_name: shop.enterprise_name,
          description: shop.description,
          email: shop.email,
          address: shop.location,
          profile_picture: shop.profile_picture,
          tier: shop.seller_tier&.tier&.name || 'Free',
          tier_id: shop.seller_tier&.tier&.id || 1,
          product_count: shop_data[:product_count],
          created_at: shop.created_at.is_a?(Time) ? shop.created_at : Time.parse(shop.created_at.to_s),
          # Enhanced scoring data
          score: shop_data[:score],
          tier_score: shop_data[:tier_score],
          product_score: shop_data[:product_score],
          rating_score: shop_data[:rating_score],
          recency_score: shop_data[:recency_score],
          name_match_bonus: shop_data[:name_match_bonus],
          avg_rating: shop_data[:avg_rating]
        }
      end,
      # Pagination metadata
      pagination: {
        ads: {
          current_page: ads_page,
          per_page: ads_per_page,
          total_count: ads_total_count,
          total_pages: (ads_total_count.to_f / ads_per_page).ceil,
          has_next_page: ads_page < (ads_total_count.to_f / ads_per_page).ceil,
          has_prev_page: ads_page > 1
        },
        shops: {
          current_page: shops_page,
          per_page: shops_per_page,
          total_count: shops_total_count,
          total_pages: (shops_total_count.to_f / shops_per_page).ceil,
          has_next_page: shops_page < (shops_total_count.to_f / shops_per_page).ceil,
          has_prev_page: shops_page > 1
        }
      }
    }

    render json: response
  end

  
  # GET /buyer/ads/:id/related
  def related
    # Use @ad from before_action instead of finding it again
    ad = @ad

    Rails.logger.info "Fetching related ads for ad ID: #{ad.id}, category: #{ad.category_id}, subcategory: #{ad.subcategory_id}"

    # Fetch ads that share either the same category or subcategory
    # Apply the same filters as the main ads endpoint
    related_ads = Ad.active.with_valid_images
                    .joins(:seller, seller: { seller_tier: :tier })
                    .where(sellers: { blocked: false, deleted: false })
                    .where(flagged: false)
                    .where.not(id: ad.id)
                    .where('ads.category_id = ? OR ads.subcategory_id = ?', ad.category_id, ad.subcategory_id)
                    .where('ads.id != ?', ad.id) # Double check to exclude current ad
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
                            END ASC, RANDOM()'))
                    .limit(10) # Limit to 10 related ads for performance

    Rails.logger.info "Found #{related_ads.count} related ads"
    Rails.logger.info "Related ad IDs: #{related_ads.pluck(:id)}"
    
    # Final validation: ensure no related ad has the same ID as the current ad
    filtered_related_ads = related_ads.reject { |related_ad| related_ad.id == ad.id }
    
    if filtered_related_ads.length != related_ads.length
      Rails.logger.warn "Filtered out #{related_ads.length - filtered_related_ads.length} ads that matched current ad ID"
    end

    render json: filtered_related_ads, each_serializer: AdSerializer
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
    total_count = Ad.active.with_valid_images
      .joins(:seller)
      .where(sellers: { blocked: false })
      .where(flagged: false)
      .where(subcategory_id: subcategory_id)
      .count
    
    ads = Ad.active.with_valid_images
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
              END ASC, RANDOM()'))  # Random order within tier priority
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
        total_count = Ad.active.with_valid_images
          .joins(:seller)
          .where(sellers: { blocked: false, deleted: false })
          .where(flagged: false)
          .where(subcategory_id: subcategory.id)
          .count
        
        subcategory_counts[subcategory.id] = total_count
        
        subcategory_ads = Ad.active.with_valid_images
           .joins(:seller, seller: { seller_tier: :tier })
           .where(sellers: { blocked: false, deleted: false })
           .where(flagged: false)
           .where(subcategory_id: subcategory.id)
           .includes(:category, :subcategory, :reviews, seller: { seller_tier: :tier })
           .order(Arel.sql('CASE tiers.id
                     WHEN 4 THEN 1
                     WHEN 3 THEN 2
                     WHEN 2 THEN 3
                     WHEN 1 THEN 4
                     ELSE 5
                   END ASC, RANDOM()'))  # Random order within tier priority
           .limit(ads_per_subcategory)
           .offset((page - 1) * ads_per_subcategory)
        
        all_ads.concat(subcategory_ads)
      end
    else
      # Regular balanced loading for all subcategories
      categories.each do |category|
        category.subcategories.each do |subcategory|
          # Get total count for this subcategory
          total_count = Ad.active.with_valid_images
            .joins(:seller)
            .where(sellers: { blocked: false, deleted: false })
            .where(flagged: false)
            .where(subcategory_id: subcategory.id)
            .count
          
          subcategory_counts[subcategory.id] = total_count
          
          # Get ads for this subcategory, ordered by tier priority first, then by creation date
          subcategory_ads = Ad.active.with_valid_images
             .joins(:seller, seller: { seller_tier: :tier })
             .where(sellers: { blocked: false, deleted: false })
             .where(flagged: false)
             .where(subcategory_id: subcategory.id)
             .includes(:category, :subcategory, :reviews, seller: { seller_tier: :tier })
             .order(Arel.sql('CASE tiers.id
                       WHEN 4 THEN 1
                       WHEN 3 THEN 2
                       WHEN 2 THEN 3
                       WHEN 1 THEN 4
                       ELSE 5
                     END ASC, RANDOM()'))  # Random order within tier priority
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
    params.require(:ad).permit(:title, :description, { media: [] }, :subcategory_id, :category_id, :seller_id, :price, :brand, :manufacturer, :item_length, :item_width, :item_height, :item_weight, :weight_unit, :condition)
  end
end
