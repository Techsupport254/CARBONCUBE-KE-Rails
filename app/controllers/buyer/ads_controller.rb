# app/controllers/buyer/ads_controller.rb
class Buyer::AdsController < ApplicationController
  before_action :set_ad, only: [:show, :seller, :related]
  before_action :set_ad_with_relations, only: [:alternatives]
  before_action :authenticate_buyer_for_alternatives, only: [:alternatives]

  # GET /buyer/ads
  def index
    PerformanceMonitor.track_api_performance('buyer_ads_index') do
      per_page = params[:per_page]&.to_i || 24
      per_page = 500 if per_page > 500
      page = params[:page].to_i.positive? ? params[:page].to_i : 1

    # For the home page, get a balanced distribution of ads across subcategories
    # Only use balanced distribution if explicitly requested AND no category filtering
    if params[:balanced] == 'true' && !params[:category_id].present? && !params[:subcategory_id].present?
      # Use shorter cache with randomization factor for home page balanced ads
      cache_key = "balanced_ads_#{per_page}_#{Date.current.strftime('%Y%m%d%H%M')}"
      
      result = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        get_balanced_ads(per_page)
      end
      @ads = result[:ads]
      @subcategory_counts = result[:subcategory_counts]
    else
      # Check if randomization is explicitly requested or if we should disable caching
      if params[:randomize] == 'true' || params[:no_cache] == 'true'
        # No caching for truly randomized results on each request
        @ads = fetch_ads_without_cache(per_page, page)
      else
        # Use minimal caching with randomization factor
        cache_key = "buyer_ads_#{per_page}_#{page}_#{params[:category_id]}_#{params[:subcategory_id]}_#{Time.current.to_i / 60}"
        
        @ads = Rails.cache.fetch(cache_key, expires_in: 1.minute) do
          # Use optimized query with proper ActiveRecord objects
          ads_query = Ad.active.with_valid_images
                       .joins(:seller, :category, :subcategory)
                       .joins('LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id')
                       .joins('LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id')
                       .where(sellers: { blocked: false, deleted: false, flagged: false })
                       .where(flagged: false)
                       .includes(:category, :subcategory, seller: { seller_tier: :tier })

          ads_query = filter_by_category(ads_query) if params[:category_id].present?
          ads_query = filter_by_subcategory(ads_query) if params[:subcategory_id].present?
          ads_query = filter_by_price_range(ads_query) if params[:price_range].present? && params[:price_range] != 'All'
          ads_query = filter_by_condition(ads_query) if params[:condition].present? && params[:condition] != 'All'
          ads_query = filter_by_location(ads_query) if params[:location].present? && params[:location] != 'All'
          ads_query = filter_by_search(ads_query) if params[:search].present?

          # Enhanced randomization with multiple factors for better distribution
          get_randomized_ads(ads_query, per_page).offset((page - 1) * per_page)
        end
      end
    end

    # Calculate total count for pagination
    total_count = if params[:balanced] == 'true' && !params[:category_id].present? && !params[:subcategory_id].present?
      # For balanced ads, we need to count all active ads
      Ad.active.with_valid_images.joins(:seller)
         .where(sellers: { blocked: false, deleted: false, flagged: false })
         .where(flagged: false)
         .count
    else
      # For filtered ads, count with same filters
      ads_query = Ad.active.with_valid_images.joins(:seller)
                    .where(sellers: { blocked: false, deleted: false, flagged: false })
                    .where(flagged: false)
      
      ads_query = filter_by_category(ads_query) if params[:category_id].present?
      ads_query = filter_by_subcategory(ads_query) if params[:subcategory_id].present?
      ads_query = filter_by_price_range(ads_query) if params[:price_range].present? && params[:price_range] != 'All'
      ads_query = filter_by_condition(ads_query) if params[:condition].present? && params[:condition] != 'All'
      ads_query = filter_by_location(ads_query) if params[:location].present? && params[:location] != 'All'
      ads_query = filter_by_search(ads_query) if params[:search].present?
      
      ads_query.count
    end

    # Include best sellers for home page (balanced=true)
    best_sellers = []
    if params[:balanced] == 'true' && !params[:category_id].present? && !params[:subcategory_id].present?
      best_sellers = calculate_best_sellers_fast(20) # Get 20 best sellers
    end

    # For balanced ads, @ads is already optimized (hash format from get_balanced_ads)
    # For regular ads, optimize serialization
    optimized_ads = if params[:balanced] == 'true' && !params[:category_id].present? && !params[:subcategory_id].present?
      # Already optimized from get_balanced_ads - just use as is
      @ads
    else
      # Regular ads - optimize serialization
      @ads.map do |ad|
      {
        id: ad.id,
        title: ad.title,
        price: ad.price,
        media: ad.media,
        created_at: ad.created_at,
        subcategory_id: ad.subcategory_id,
        category_id: ad.category_id,
        seller_id: ad.seller_id,
        seller_tier: ad.seller&.seller_tier&.tier&.id || 1,
        seller_tier_name: ad.seller&.seller_tier&.tier&.name || "Free",
        seller_name: ad.seller&.fullname,
        category_name: ad.category&.name,
        subcategory_name: ad.subcategory&.name
      }
      end
    end

    # Add cache headers for faster transfer
    response.headers['Cache-Control'] = 'public, max-age=1800' # 30 minutes cache
    
      render json: {
        ads: optimized_ads,
        subcategory_counts: @subcategory_counts || {},
        best_sellers: best_sellers,
        pagination: {
          current_page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: (total_count.to_f / per_page).ceil
        }
      }
    end
  end

  # GET /buyer/ads/:id
  def show
    @ad = Ad.includes(
      :category,
      :subcategory,
      :reviews,
      :offer_ads,
      seller: { seller_tier: :tier, seller_documents: :document_type }
    ).find_by_id_or_slug(params[:id])

    unless @ad
      render json: { error: 'Ad not found' }, status: :not_found
      return
    end

    render json: @ad, serializer: AdSerializer, include_reviews: true
  end
  
  # GET /buyer/ads/:id/alternatives
  def alternatives
    ad = @ad_with_relations

    base_scope = Ad.active.with_valid_images
                    .select('ads.*')
                    .joins(:seller, :category, :subcategory)
                    .where(sellers: { blocked: false, deleted: false, flagged: false })
                    .where(flagged: false, deleted: false)
                    .where.not(id: ad.id, seller_id: ad.seller_id)

    same_product_scope = base_scope
                           .where(category_id: ad.category_id, subcategory_id: ad.subcategory_id)
                           .where(brand: ad.brand)
                           .where("LOWER(ads.title) = ?", ad.title.to_s.downcase)

    similar_scope = base_scope
                       .where(category_id: ad.category_id, subcategory_id: ad.subcategory_id)

    same_product = same_product_scope.limit(10)

    similar_items = if same_product.size < 5
      similar_scope.where("ads.title ILIKE ?", "%#{ad.title.to_s.split.first}%")
                   .limit(10)
    else
      []
    end

    render json: {
      same_product: serialize_alternatives(same_product),
      similar_items: serialize_alternatives(similar_items)
    }
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
            .where(sellers: { blocked: false, deleted: false, flagged: false })
            .where(flagged: false)

    if query.present?
      query_words = query.split(/\s+/).reject(&:blank?)
      
      # Build relevance-based search conditions
      # Priority 1: Exact word matches in title (highest relevance)
      # Priority 2: Exact word matches in description
      # Priority 3: Partial matches in title
      # Priority 4: Partial matches in description
      # Priority 5: Category/subcategory matches
      # Priority 6: Seller name matches
      
      title_conditions = []
      description_conditions = []
      category_conditions = []
      seller_conditions = []
      
      query_words.each do |word|
        # Create multiple search patterns for better matching
        search_patterns = [
          "% #{word} %",           # Exact word match with spaces
          "%#{word}%",             # Partial match anywhere
          "%#{word[0..-2]}%",      # Remove last character (driller -> drille)
          "%#{word[0..-3]}%",      # Remove last 2 characters (driller -> drill)
          "%#{word[0..-4]}%",      # Remove last 3 characters (drilling -> drill)
          "%#{word}s%",            # Add 's' (drill -> drills)
          "%#{word}er%",           # Add 'er' (drill -> driller)
          "%#{word}ing%",          # Add 'ing' (drill -> drilling)
          "%#{word}ed%",           # Add 'ed' (drill -> drilled)
        ]
        
        # Title matches (highest priority)
        search_patterns.each do |pattern|
          title_conditions << "ads.title ILIKE ?"
        end
        
        # Description matches (second priority)
        search_patterns.each do |pattern|
          description_conditions << "ads.description ILIKE ?"
        end
        
        # Category and subcategory matches
        search_patterns.each do |pattern|
          category_conditions << "categories.name ILIKE ?"
          category_conditions << "subcategories.name ILIKE ?"
        end
        
        # Seller name matches
        search_patterns.each do |pattern|
          seller_conditions << "sellers.enterprise_name ILIKE ?"
        end
      end
      
      # Build the main search condition with relevance weighting
      search_conditions = []
      search_params = []
      
      # Title matches (highest priority)
      if title_conditions.any?
        search_conditions << "(#{title_conditions.join(' OR ')})"
        query_words.each do |word|
          # Add all search patterns for title matching
          search_params << "% #{word} %"           # Exact match
          search_params << "%#{word}%"             # Partial match
          search_params << "%#{word[0..-2]}%"     # Remove last char
          search_params << "%#{word[0..-3]}%"     # Remove last 2 chars
          search_params << "%#{word[0..-4]}%"     # Remove last 3 chars
          search_params << "%#{word}s%"            # Add 's'
          search_params << "%#{word}er%"           # Add 'er'
          search_params << "%#{word}ing%"          # Add 'ing'
          search_params << "%#{word}ed%"           # Add 'ed'
        end
      end
      
      # Description matches (second priority)
      if description_conditions.any?
        search_conditions << "(#{description_conditions.join(' OR ')})"
        query_words.each do |word|
          # Add all search patterns for description matching
          search_params << "% #{word} %"           # Exact match
          search_params << "%#{word}%"             # Partial match
          search_params << "%#{word[0..-2]}%"     # Remove last char
          search_params << "%#{word[0..-3]}%"     # Remove last 2 chars
          search_params << "%#{word[0..-4]}%"     # Remove last 3 chars
          search_params << "%#{word}s%"            # Add 's'
          search_params << "%#{word}er%"           # Add 'er'
          search_params << "%#{word}ing%"          # Add 'ing'
          search_params << "%#{word}ed%"           # Add 'ed'
        end
      end
      
      # Category matches (third priority)
      if category_conditions.any?
        search_conditions << "(#{category_conditions.join(' OR ')})"
        query_words.each do |word|
          # Add all search patterns for category matching
          search_params << "% #{word} %"           # Exact match
          search_params << "%#{word}%"             # Partial match
          search_params << "%#{word[0..-2]}%"     # Remove last char
          search_params << "%#{word[0..-3]}%"     # Remove last 2 chars
          search_params << "%#{word[0..-4]}%"     # Remove last 3 chars
          search_params << "%#{word}s%"            # Add 's'
          search_params << "%#{word}er%"           # Add 'er'
          search_params << "%#{word}ing%"          # Add 'ing'
          search_params << "%#{word}ed%"           # Add 'ed'
          # Add again for subcategory
          search_params << "% #{word} %"           # Exact match
          search_params << "%#{word}%"             # Partial match
          search_params << "%#{word[0..-2]}%"     # Remove last char
          search_params << "%#{word[0..-3]}%"     # Remove last 2 chars
          search_params << "%#{word[0..-4]}%"     # Remove last 3 chars
          search_params << "%#{word}s%"            # Add 's'
          search_params << "%#{word}er%"           # Add 'er'
          search_params << "%#{word}ing%"          # Add 'ing'
          search_params << "%#{word}ed%"           # Add 'ed'
        end
      end
      
      # Seller matches (lowest priority)
      if seller_conditions.any?
        search_conditions << "(#{seller_conditions.join(' OR ')})"
        query_words.each do |word|
          # Add all search patterns for seller matching
          search_params << "% #{word} %"           # Exact match
          search_params << "%#{word}%"             # Partial match
          search_params << "%#{word[0..-2]}%"     # Remove last char
          search_params << "%#{word[0..-3]}%"     # Remove last 2 chars
          search_params << "%#{word[0..-4]}%"     # Remove last 3 chars
          search_params << "%#{word}s%"            # Add 's'
          search_params << "%#{word}er%"           # Add 'er'
          search_params << "%#{word}ing%"          # Add 'ing'
          search_params << "%#{word}ed%"           # Add 'ed'
        end
      end
      
      # Apply the search conditions
      if search_conditions.any?
        ads = ads.where(search_conditions.join(' OR '), *search_params)
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
    
    # Build relevance scoring for search results
    if query.present?
      # Use a simpler approach with better ordering
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
        .order(Arel.sql("
          CASE 
            WHEN ads.title ILIKE '% #{query} %' THEN 1
            WHEN ads.title ILIKE '%#{query}%' THEN 2
            WHEN ads.description ILIKE '% #{query} %' THEN 3
            WHEN ads.description ILIKE '%#{query}%' THEN 4
            WHEN categories.name ILIKE '%#{query}%' THEN 5
            WHEN subcategories.name ILIKE '%#{query}%' THEN 6
            WHEN sellers.enterprise_name ILIKE '%#{query}%' THEN 7
            ELSE 8
          END ASC,
          CASE tiers.id
            WHEN 4 THEN 1
            WHEN 3 THEN 2
            WHEN 2 THEN 3
            WHEN 1 THEN 4
            ELSE 5
          END ASC,
          RANDOM()
        "))
        .limit(ads_per_page)
        .offset((ads_page - 1) * ads_per_page)
    else
      # For non-search queries, use the original ordering
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
    end

    # Enhanced shop search - find shops that match query OR have products matching the query
    matching_shops = []
    if query.present?
      # Find shops that match the search query by name with broad matching
      query_words = query.split(/\s+/)
      shop_patterns = []
      
      query_words.each do |word|
        shop_patterns += [
          "%#{word}%",           # Exact word match
          "%#{word[0..-2]}%",    # Remove last character
          "%#{word[0..-3]}%",    # Remove last 2 characters
          "%#{word}s%",          # Add 's'
          "%#{word}er%",         # Add 'er'
          "%#{word}ing%",        # Add 'ing'
          "%#{word}ed%",         # Add 'ed'
        ]
      end
      
      name_matching_shops = Seller.joins(:seller_tier)
                                 .where(blocked: false, deleted: false)
                                 .where((shop_patterns.map { 'enterprise_name ILIKE ?' } + shop_patterns.map { 'fullname ILIKE ?' }).join(' OR '), *shop_patterns, *shop_patterns)
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

  
  # GET /buyer/ads/recommendations
  # Get personalized recommendations based on user's clicked/revealed ads
  def recommendations
    begin
      device_hash = params[:device_hash] || request.headers['X-Device-Hash']
      
      # Optionally authenticate buyer if token is present (not required for guests)
      buyer_id = nil
      begin
        buyer_auth = BuyerAuthorizeApiRequest.new(request.headers)
        current_buyer = buyer_auth.result
        buyer_id = current_buyer&.id if current_buyer&.is_a?(Buyer)
      rescue => e
        # Silently fail - guest users are allowed
        Rails.logger.debug "Buyer authentication failed (guest user): #{e.message}" if Rails.env.development?
      end
      
      limit = params[:limit]&.to_i || 100
      limit = [limit, 500].min # Cap at 500
      
      Rails.logger.info "Recommendations request: device_hash=#{device_hash.present? ? 'present' : 'missing'}, buyer_id=#{buyer_id || 'none'}"
    
    # Get clicked/revealed ads for this user (device_hash for guests, buyer_id for authenticated)
    clicked_ad_ids = []
    clicked_categories = []
    clicked_subcategories = []
    clicked_sellers = []
    
    if device_hash.present? || buyer_id.present?
      # Get click events - prioritize reveal clicks as they show stronger interest
      click_events_query = ClickEvent
        .excluding_internal_users
        .where(event_type: ['Ad-Click', 'Reveal-Seller-Details'])
      
      if buyer_id.present?
        # Authenticated user - use buyer_id
        click_events_query = click_events_query.where(
          "metadata->>'user_id' = ? OR metadata->>'device_hash' = ?",
          buyer_id.to_s,
          device_hash.to_s
        )
      elsif device_hash.present?
        # Guest user - use device_hash
        click_events_query = click_events_query.where("metadata->>'device_hash' = ?", device_hash.to_s)
      end
      
      # Get recent click events (last 100 to avoid too much data)
      click_events = click_events_query
        .order(created_at: :desc)
        .limit(100)
        .includes(:ad)
        .where.not(ad_id: nil)
      
      Rails.logger.info "Found #{click_events.count} click events for user"
      
      # Extract ad IDs, categories, subcategories, and sellers from clicked ads
      click_events.each do |event|
        next unless event.ad&.active?
        
        clicked_ad_ids << event.ad_id
        clicked_categories << event.ad.category_id if event.ad.category_id
        clicked_subcategories << event.ad.subcategory_id if event.ad.subcategory_id
        clicked_sellers << event.ad.seller_id if event.ad.seller_id
      end
      
      # Remove duplicates
      clicked_categories.uniq!
      clicked_subcategories.uniq!
      clicked_sellers.uniq!
      
      Rails.logger.info "Extracted: #{clicked_ad_ids.count} ad_ids, #{clicked_subcategories.count} subcategories, #{clicked_categories.count} categories, #{clicked_sellers.count} sellers"
    end
    
    # If user has no click history, fall back to best sellers
    if clicked_ad_ids.empty? && clicked_subcategories.empty? && clicked_categories.empty? && clicked_sellers.empty?
      Rails.logger.info "No click history found, falling back to best sellers"
      best_sellers = calculate_best_sellers_fast(limit)
      Rails.logger.info "Best sellers returned: #{best_sellers.count} ads"
      render json: best_sellers
      return
    end
    
    # Find similar ads based on clicked ads
    # Priority: 1) Same subcategory (highest), 2) Same category, 3) Same seller
    recommended_ads_query = Ad.active.with_valid_images
      .joins(:seller, :category, :subcategory)
      .joins('LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id')
      .joins('LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id')
      .where(sellers: { blocked: false, deleted: false, flagged: false })
      .where(flagged: false)
    
    # Exclude already clicked ads only if we have clicked ads
    if clicked_ad_ids.any?
      recommended_ads_query = recommended_ads_query.where.not(id: clicked_ad_ids)
    end
    
    # Build similarity conditions using Arel for proper OR handling
    if clicked_subcategories.any? || clicked_categories.any? || clicked_sellers.any?
      # Build OR conditions using Arel
      or_conditions = []
      
      if clicked_subcategories.any?
        or_conditions << Ad.arel_table[:subcategory_id].in(clicked_subcategories)
      end
      
      if clicked_categories.any?
        or_conditions << Ad.arel_table[:category_id].in(clicked_categories)
      end
      
      if clicked_sellers.any?
        or_conditions << Ad.arel_table[:seller_id].in(clicked_sellers)
      end
      
      # Combine with OR - handle single and multiple conditions
      if or_conditions.length == 1
        combined_condition = or_conditions.first
      else
        combined_condition = or_conditions.reduce { |acc, condition| acc.or(condition) }
      end
      
      recommended_ads_query = recommended_ads_query.where(combined_condition)
    else
      # Fallback to best sellers if no similarity found
      Rails.logger.info "No similarity conditions, falling back to best sellers"
      best_sellers = calculate_best_sellers_fast(limit)
      render json: best_sellers
      return
    end
    
    # Get ads with tier priority
    recommended_ads = recommended_ads_query
      .select("ads.*, 
               CASE tiers.id
                 WHEN 4 THEN 1
                 WHEN 3 THEN 2
                 WHEN 2 THEN 3
                 WHEN 1 THEN 4
                 ELSE 5
               END AS tier_priority")
      .includes(:category, :subcategory, :reviews, seller: { seller_tier: :tier })
      .order(Arel.sql('tier_priority ASC, ads.created_at DESC'))
      .limit(limit * 3) # Get more to allow for scoring
    
    Rails.logger.info "Query returned #{recommended_ads.count} recommended ads"
    
    # If no ads found, fall back to best sellers
    if recommended_ads.empty?
      Rails.logger.info "No recommended ads found, falling back to best sellers"
      best_sellers = calculate_best_sellers_fast(limit)
      render json: best_sellers
      return
    end
    
    # Calculate comprehensive scores and add personalization boost
    scored_ads = recommended_ads.map do |ad|
      # Calculate similarity score in Ruby (safer than SQL)
      similarity_score = 0
      if clicked_subcategories.include?(ad.subcategory_id)
        similarity_score = 3 # Highest priority: same subcategory
      elsif clicked_categories.include?(ad.category_id)
        similarity_score = 2 # Medium priority: same category
      elsif clicked_sellers.include?(ad.seller_id)
        similarity_score = 1 # Lower priority: same seller
      end
      
      # Base comprehensive score
      # Get seller_tier_id from the ad's seller association (loaded via includes)
      seller_tier_id = ad.seller&.seller_tier&.tier_id || 1
      tier_bonus = calculate_tier_bonus(seller_tier_id)
      recency_score = calculate_recency_score(ad.created_at)
      
      # Get engagement metrics
      wishlist_count = WishList.where(ad_id: ad.id).count
      # Reviews are loaded via includes, so we can access them directly
      review_count = ad.reviews&.count || 0
      avg_rating = if ad.reviews&.any?
        ad.reviews.sum(&:rating).to_f / review_count
      else
        0.0
      end
      click_count = ClickEvent.where(ad_id: ad.id, event_type: 'Ad-Click').excluding_internal_users.count
      
      wishlist_score = calculate_wishlist_score(wishlist_count)
      rating_score = calculate_rating_score(avg_rating, review_count)
      click_score = calculate_click_score(click_count)
      
      comprehensive_score = (
        (recency_score * 0.25) +
        (tier_bonus * 0.15) +
        (wishlist_score * 0.25) +
        (rating_score * 0.20) +
        (click_score * 0.15)
      )
      
      # Personalization boost based on similarity
      personalized_score = comprehensive_score + (similarity_score * 2.0) # Boost for similarity
      
      {
        id: ad.id,
        ad_id: ad.id,
        title: ad.title,
        price: ad.price.to_f,
        media: ad.media,
        media_urls: ad.media.is_a?(String) ? JSON.parse(ad.media || '[]') : (ad.media || []),
        first_media_url: ad.media.is_a?(String) ? (JSON.parse(ad.media || '[]').first || '') : (ad.media&.first || ''),
        created_at: ad.created_at,
        seller_id: ad.seller_id,
        seller_name: ad.seller&.enterprise_name || ad.seller&.username || 'Unknown',
        category_id: ad.category_id,
        category_name: ad.category&.name,
        subcategory_id: ad.subcategory_id,
        subcategory_name: ad.subcategory&.name,
        seller_tier: seller_tier_id || 1,
        seller_tier_name: (ad.seller&.seller_tier&.tier&.name || ad.seller_tier_name || 'Free'),
        tier_priority: ad.tier_priority || 5,
        comprehensive_score: comprehensive_score.round(2),
        personalized_score: personalized_score.round(2),
        similarity_score: similarity_score,
        metrics: {
          avg_rating: avg_rating.round(2),
          review_count: review_count,
          total_clicks: click_count,
          wishlist_count: wishlist_count
        }
      }
    end
    
    # Sort by personalized score and return top results
    sorted_ads = scored_ads.sort_by { |ad| -ad[:personalized_score] }.first(limit)
    
    Rails.logger.info "Returning #{sorted_ads.count} sorted recommendations"
    
      # Ensure we always return something - fallback to best sellers if empty
      if sorted_ads.empty?
        Rails.logger.info "Sorted ads empty, falling back to best sellers"
        best_sellers = calculate_best_sellers_fast(limit)
        render json: best_sellers
      else
        render json: sorted_ads
      end
    rescue => e
      Rails.logger.error "Error in recommendations: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Fallback to best sellers on any error
      begin
        fallback_limit = limit || 100
        best_sellers = calculate_best_sellers_fast(fallback_limit)
        render json: best_sellers || []
      rescue => fallback_error
        Rails.logger.error "Error in fallback best sellers: #{fallback_error.message}"
        Rails.logger.error fallback_error.backtrace.first(10).join("\n")
        render json: { error: 'Failed to load recommendations' }, status: :internal_server_error
      end
    end
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
                    .where(sellers: { blocked: false, deleted: false, flagged: false })
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
                    .limit(50) # Limit to 50 related ads for performance
    
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
      .where(sellers: { blocked: false, deleted: false, flagged: false })
      .where(flagged: false)
      .where(subcategory_id: subcategory_id)
      .count
    
    ads = Ad.active.with_valid_images
      .joins(:seller, seller: { seller_tier: :tier })
      .where(sellers: { blocked: false, deleted: false, flagged: false })
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
  def set_ad_with_relations
    @ad_with_relations ||= Ad.includes(:category, :subcategory, :seller).find_by_id_or_slug(params[:id])

    unless @ad_with_relations
      render json: { error: 'Ad not found' }, status: :not_found
      return
    end
  end

  def set_ad
    @ad = Ad.find_by_id_or_slug(params[:id])

    unless @ad
      render json: { error: 'Ad not found' }, status: :not_found
    end
  end

  def authenticate_buyer_for_alternatives
    begin
      @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
    rescue ExceptionHandler::InvalidToken => e
      Rails.logger.warn "Buyer::AdsController#alternatives: invalid token - #{e.message}"
      @current_user = nil
    rescue => e
      Rails.logger.error "Buyer::AdsController#alternatives: unexpected auth error - #{e.class.name}: #{e.message}"
      @current_user = nil
    end

    unless @current_user.is_a?(Buyer)
      render json: { error: 'Authentication required to view alternative sellers' }, status: :unauthorized
    end
  end

  def serialize_alternatives(scope)
    scope.map do |alt|
      {
        id: alt.id,
        title: alt.title,
        price: alt.price&.to_f,
        first_media_url: alt.first_media_url,
        category_name: alt.category&.name,
        subcategory_name: alt.subcategory&.name,
        seller_id: alt.seller_id,
        seller_name: alt.seller&.fullname || alt.seller&.enterprise_name,
        seller_rating: alt.seller&.respond_to?(:calculate_mean_rating) ? alt.seller.calculate_mean_rating : nil,
        location: alt.seller&.county
      }
    end
  end

  # Enhanced randomization method that ensures different results on each request
  def get_randomized_ads(ads_query, limit)
    # Add multiple randomization factors for better distribution
    ads_query.order(
      Arel.sql('RANDOM()'),
      Arel.sql('ads.created_at DESC'),
      Arel.sql('ads.id')
    ).limit(limit)
  end

  # Fetch ads without any caching for true randomization
  def fetch_ads_without_cache(per_page, page)
    # Use optimized query with proper ActiveRecord objects
    ads_query = Ad.active.with_valid_images
                 .joins(:seller, :category, :subcategory)
                 .joins('LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id')
                 .joins('LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id')
                 .where(sellers: { blocked: false, deleted: false, flagged: false })
                 .where(flagged: false)
                 .includes(:category, :subcategory, seller: { seller_tier: :tier })

    ads_query = filter_by_category(ads_query) if params[:category_id].present?
    ads_query = filter_by_subcategory(ads_query) if params[:subcategory_id].present?
    ads_query = filter_by_price_range(ads_query) if params[:price_range].present? && params[:price_range] != 'All'
    ads_query = filter_by_condition(ads_query) if params[:condition].present? && params[:condition] != 'All'
    ads_query = filter_by_location(ads_query) if params[:location].present? && params[:location] != 'All'
    ads_query = filter_by_search(ads_query) if params[:search].present?

    # Enhanced randomization with multiple factors for better distribution
    get_randomized_ads(ads_query, per_page).offset((page - 1) * per_page)
  end

  def get_balanced_ads(per_page)
    # Get 6 ads per subcategory for balanced distribution
    # Get all subcategory counts in a single query
    # Only count ads that actually have valid media URLs (not empty arrays) and are not flagged
    subcategory_counts = Ad.active
      .joins(:seller)
      .where(sellers: { blocked: false, deleted: false, flagged: false })
      .where(flagged: false) # Exclude flagged ads
      .where("ads.media IS NOT NULL AND ads.media != '' AND ads.media::text != '[]' AND (ads.media::jsonb -> 0) IS NOT NULL")
      .group('ads.subcategory_id')
      .count('ads.id')
    
    # Get all subcategory IDs that have ads
    subcategory_ids = subcategory_counts.keys.compact
    
    return { ads: [], subcategory_counts: subcategory_counts } if subcategory_ids.empty?
    
    # Use a subquery with window function to get top 6 ads per subcategory
    # Then select only the necessary fields for optimized serialization
    sql = <<-SQL
      WITH ranked_ads AS (
        SELECT 
          ads.id,
          ads.title,
          ads.price,
          ads.media,
          ads.created_at,
          ads.subcategory_id,
          ads.category_id,
          ads.seller_id,
          sellers.fullname as seller_name,
          categories.name as category_name,
          subcategories.name as subcategory_name,
          COALESCE(tiers.id, 1) as seller_tier_id,
          COALESCE(tiers.name, 'Free') as seller_tier_name,
          COALESCE(review_stats.reviews_count, 0) as reviews_count,
          COALESCE(review_stats.average_rating, 0.0) as average_rating,
          ROW_NUMBER() OVER (
            PARTITION BY ads.subcategory_id 
            ORDER BY 
              CASE COALESCE(tiers.id, 1)
                WHEN 4 THEN 1
                WHEN 3 THEN 2
                WHEN 2 THEN 3
                WHEN 1 THEN 4
                ELSE 5
              END,
              ads.created_at DESC
          ) as row_num
        FROM ads
        INNER JOIN sellers ON sellers.id = ads.seller_id
        INNER JOIN categories ON categories.id = ads.category_id
        INNER JOIN subcategories ON subcategories.id = ads.subcategory_id
        LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id
        LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id
        LEFT JOIN (
          SELECT 
            ad_id,
            COUNT(*) as reviews_count,
            COALESCE(AVG(rating), 0.0) as average_rating
          FROM reviews
          GROUP BY ad_id
        ) review_stats ON review_stats.ad_id = ads.id
        WHERE ads.deleted = false
          AND ads.media IS NOT NULL
          AND ads.media != ''
          AND ads.media::text != '[]'
          AND (ads.media::jsonb -> 0) IS NOT NULL
          AND sellers.blocked = false
          AND sellers.deleted = false
          AND sellers.flagged = false
          AND ads.flagged = false
          AND ads.subcategory_id IN (#{subcategory_ids.map { |id| ActiveRecord::Base.connection.quote(id) }.join(',')})
      )
      SELECT * FROM ranked_ads WHERE row_num <= 6
      ORDER BY subcategory_id, row_num
    SQL
    
    # Execute query and convert to hash format for optimized serialization
    results = ActiveRecord::Base.connection.execute(sql)
    
    # Get ad IDs for fetching offer info and processing media
    ad_ids = results.map { |row| row['id'] }
    
    # Fetch offer info for all ads in one query
    offer_info_map = {}
    if ad_ids.any?
      active_offers = OfferAd.joins(:offer)
                             .where(ad_id: ad_ids)
                             .where(offers: { status: ['active', 'scheduled'] })
                             .where('offers.end_time >= ?', Time.current)
                             .includes(:offer)
                             .group_by(&:ad_id)
      
      active_offers.each do |ad_id, offer_ads|
        # Get the first active offer (ordered by start_time)
        offer_ad = offer_ads.min_by { |oa| oa.offer.start_time || Time.current }
        offer = offer_ad.offer
        
        offer_info_map[ad_id] = {
          active: offer.status == 'active',
          scheduled: offer.status == 'scheduled',
          offer_id: offer.id,
          offer_name: offer.name,
          offer_type: offer.offer_type,
          discount_type: offer.discount_type,
          original_price: offer_ad.original_price,
          discounted_price: offer_ad.discounted_price,
          discount_percentage: offer_ad.discount_percentage,
          savings_amount: offer_ad.savings_amount,
          seller_notes: offer_ad.seller_notes,
          start_time: offer.start_time&.iso8601,
          end_time: offer.end_time&.iso8601,
          time_remaining: offer.time_remaining,
          badge_color: offer.badge_color,
          banner_color: offer.banner_color,
          minimum_order_amount: offer.minimum_order_amount
        }
      end
    end
    
    balanced_ads = results.map do |row|
      ad_id = row['id']
      media_json = row['media']
      
      # Process media to get valid URLs (similar to Ad model's valid_media_urls)
      # PostgreSQL returns JSONB as a string, so we need to parse it
      media_urls = []
      first_media_url = nil
      
      if media_json.present?
        begin
          # Parse JSON string if it's a string
          if media_json.is_a?(String)
            # Handle empty array string
            if media_json.strip == '[]' || media_json.strip == 'null' || media_json.strip == ''
              media_array = []
            else
              media_array = JSON.parse(media_json)
            end
          else
            media_array = media_json
          end
          
          # Process array of URLs
          if media_array.is_a?(Array) && media_array.any?
            # Filter valid URLs (must be strings starting with http)
            media_urls = media_array.select do |url|
              url.present? && 
              url.is_a?(String) && 
              url.strip.length > 0 &&
              (url.start_with?('http://') || url.start_with?('https://'))
            end
            first_media_url = media_urls.first
          end
        rescue JSON::ParserError => e
          # If media is not valid JSON, try to use it as a single URL
          if media_json.is_a?(String) && (media_json.start_with?('http://') || media_json.start_with?('https://'))
            media_urls = [media_json]
            first_media_url = media_json
          end
        end
      end
      
      {
        id: ad_id,
        title: row['title'],
        price: row['price']&.to_f,
        media: media_json,
        media_urls: media_urls,
        first_media_url: first_media_url,
        created_at: row['created_at']&.iso8601,
        subcategory_id: row['subcategory_id'],
        category_id: row['category_id'],
        seller_id: row['seller_id'],
        seller_name: row['seller_name'],
        category_name: row['category_name'],
        subcategory_name: row['subcategory_name'],
        seller_tier: row['seller_tier_id'],
        seller_tier_name: row['seller_tier_name'],
        reviews_count: row['reviews_count']&.to_i || 0,
        average_rating: row['average_rating']&.to_f || 0.0,
        rating: row['average_rating']&.to_f || 0.0, # Alias for AdCard compatibility
        mean_rating: row['average_rating']&.to_f || 0.0, # Alias for AdCard compatibility
        flash_sale_info: offer_info_map[ad_id]
      }
    end
    
    {
      ads: balanced_ads,
      subcategory_counts: subcategory_counts
    }
  end

  def filter_by_category(ads_query)
    ads_query.where(category_id: params[:category_id])
  end

  def filter_by_subcategory(ads_query)
    ads_query.where(subcategory_id: params[:subcategory_id])
  end

  # Filter by price range
  # Expected formats: "0-1000", "1000-5000", "5000-10000", "10000-25000", "25000+"
  def filter_by_price_range(ads_query)
    price_range = params[:price_range]
    
    if price_range.include?('-')
      # Range format: "1000-5000"
      min_price, max_price = price_range.split('-').map(&:to_f)
      ads_query.where('ads.price >= ? AND ads.price <= ?', min_price, max_price)
    elsif price_range.include?('+')
      # Minimum only format: "25000+"
      min_price = price_range.gsub('+', '').to_f
      ads_query.where('ads.price >= ?', min_price)
    else
      ads_query
    end
  end

  # Filter by condition
  # Ad.condition enum: { brand_new: 0, second_hand: 1, refurbished: 2, x_japan: 3 }
  def filter_by_condition(ads_query)
    condition_param = params[:condition].downcase.gsub(/\s+/, '_')
    
    case condition_param
    when 'brand_new', 'new'
      ads_query.where(condition: :brand_new)
    when 'second_hand', 'used'
      ads_query.where(condition: :second_hand)
    when 'refurbished'
      ads_query.where(condition: :refurbished)
    when 'x_japan', 'x-japan'
      ads_query.where(condition: :x_japan)
    else
      ads_query
    end
  end

  # Filter by location (prioritize exact location, then county, then city)
  def filter_by_location(ads_query)
    location_param = params[:location]
    return ads_query if location_param.blank? || location_param == 'All'
    
    # Priority 1: Try exact location match in seller.location field first
    # This handles specific addresses like "Imenti House, Tom Mboya Street"
    exact_match = ads_query.where('sellers.location ILIKE ?', "%#{location_param}%")
    
    # If we get results from exact match, use those
    if exact_match.exists?
      return exact_match
    end
    
    # Priority 2: Try to find county by name
    county = County.find_by('name ILIKE ?', location_param)
    
    if county
      # Filter by seller's county
      ads_query.where(sellers: { county_id: county.id })
    else
      # Priority 3: Fallback to city matching
      ads_query.where('sellers.city ILIKE ?', "%#{location_param}%")
    end
  end

  # Filter by search term (within category context)
  def filter_by_search(ads_query)
    search_term = params[:search].strip
    
    ads_query.where(
      'ads.title ILIKE ? OR ads.description ILIKE ? OR ads.brand ILIKE ?',
      "%#{search_term}%",
      "%#{search_term}%",
      "%#{search_term}%"
    )
  end

  def ad_params
    params.require(:ad).permit(:title, :description, { media: [] }, :subcategory_id, :category_id, :seller_id, :price, :brand, :manufacturer, :item_length, :item_width, :item_height, :item_weight, :weight_unit, :condition)
  end

  def calculate_best_sellers_fast(limit)
    # Optimized approach with minimal data for faster response
    # Use caching for best sellers calculation
    cache_key = "best_sellers_optimized_#{limit}_#{Date.current.strftime('%Y%m%d')}"
    
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      # Get ads with essential data only for faster queries
      ads_data = Ad.active.with_valid_images
                   .joins(:seller, :category, :subcategory)
                   .joins("LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id")
                   .joins("LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id")
                   .joins("LEFT JOIN wish_lists ON ads.id = wish_lists.ad_id")
                   .joins("LEFT JOIN reviews ON ads.id = reviews.ad_id")
                   .joins("LEFT JOIN click_events ON ads.id = click_events.ad_id")
                   .where(sellers: { blocked: false, deleted: false, flagged: false })
                   .where(flagged: false)
                   .select("
                     ads.id,
                     ads.category_id,
                     ads.subcategory_id,
                     ads.title,
                     ads.price,
                     ads.media,
                     ads.created_at,
                     sellers.fullname as seller_name,
                     sellers.id as seller_id,
                     categories.name as category_name,
                     subcategories.name as subcategory_name,
                     COALESCE(tiers.id, 1) as seller_tier_id,
                     COALESCE(tiers.name, 'Free') as seller_tier_name,
                     COUNT(DISTINCT wish_lists.id) as wishlist_count,
                     COUNT(DISTINCT reviews.id) as review_count,
                     COALESCE(AVG(reviews.rating), 0) as avg_rating,
                     COUNT(DISTINCT click_events.id) as click_count
                   ")
                   .group("ads.id, sellers.id, categories.id, subcategories.id, tiers.id")
                   .order('RANDOM()')
                   .limit(limit * 3) # Reduced multiplier for faster queries
    
    return [] if ads_data.empty?
    
    # Enhanced scoring with meaningful metrics
    scored_ads = ads_data.map do |ad|
      # Base scores
      tier_bonus = calculate_tier_bonus(ad.seller_tier_id.to_i)
      recency_score = calculate_recency_score(ad.created_at)
      
      # Engagement metrics
      wishlist_score = calculate_wishlist_score(ad.wishlist_count.to_i)
      rating_score = calculate_rating_score(ad.avg_rating.to_f, ad.review_count.to_i)
      click_score = calculate_click_score(ad.click_count.to_i)
      
      # Weighted comprehensive score
      comprehensive_score = (
        (recency_score * 0.25) +      # 25% - Recency
        (tier_bonus * 0.15) +         # 15% - Seller tier
        (wishlist_score * 0.25) +     # 25% - Wishlist additions
        (rating_score * 0.20) +       # 20% - Ratings & reviews
        (click_score * 0.15)          # 15% - Click engagement
      )
      
      {
        ad_id: ad.id,
        id: ad.id,  # Add id field for consistency
        title: ad.title,
        price: ad.price.to_f,
        media: ad.media,
        created_at: ad.created_at,
        seller_name: ad.seller_name,
        seller_id: ad.seller_id,
        category_name: ad.category_name,
        subcategory_name: ad.subcategory_name,
        seller_tier: ad.seller_tier_id,  # Use seller_tier instead of seller_tier_id
        seller_tier_name: ad.seller_tier_name,
        metrics: {
          avg_rating: ad.avg_rating.to_f.round(2),
          review_count: ad.review_count.to_i,
          total_clicks: ad.click_count.to_i,
          wishlist_count: ad.wishlist_count.to_i
        },
        comprehensive_score: comprehensive_score.round(2)
      }
    end
    
      # Sort by comprehensive score and return top results
      scored_ads.sort_by { |ad| -ad[:comprehensive_score] }.first(limit)
    end
  end

  def calculate_tier_bonus(seller_tier_id)
    case seller_tier_id
    when 4 then 15
    when 3 then 8
    when 2 then 4
    else 0
    end
  end

  def calculate_recency_score(created_at)
    return 0 if created_at.nil?
    days_old = (Time.current - created_at) / 1.day
    case days_old
    when 0..7 then 8
    when 8..30 then 5
    when 31..90 then 3
    when 91..365 then 1
    else 0
    end
  end

  def calculate_wishlist_score(wishlist_count)
    return 0 if wishlist_count <= 0
    # Logarithmic scaling for wishlist additions
    Math.log10(wishlist_count + 1) * 20
  end

  def calculate_rating_score(avg_rating, review_count)
    return 0 if review_count <= 0 || avg_rating <= 0
    
    # Rating score based on average rating
    rating_score = (avg_rating / 5.0) * 30
    
    # Review count bonus (more reviews = more reliable)
    count_bonus = Math.log10(review_count + 1) * 10
    
    rating_score + count_bonus
  end

  def calculate_click_score(click_count)
    return 0 if click_count <= 0
    # Logarithmic scaling for clicks
    Math.log10(click_count + 1) * 15
  end
end
