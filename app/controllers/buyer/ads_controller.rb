# app/controllers/buyer/ads_controller.rb
class Buyer::AdsController < ApplicationController
  before_action :set_ad, only: [:show, :seller, :related]
  before_action :set_ad_with_relations, only: [:alternatives]
  before_action :authenticate_user_for_alternatives, only: [:alternatives]

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
      # Regular ads - optimize serialization with media URL processing
      @ads.map do |ad|
        # Process media URLs for frontend compatibility
        media_json = ad.media
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
          rescue JSON::ParserError
            # If media is not valid JSON, try to use it as a single URL
            if media_json.is_a?(String) && (media_json.start_with?('http://') || media_json.start_with?('https://'))
              media_urls = [media_json]
              first_media_url = media_json
            end
          end
        end

      {
        id: ad.id,
        title: ad.title,
        price: ad.price,
          media: media_json,
          media_urls: media_urls,
          first_media_url: first_media_url,
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
                    .joins('LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id')
                    .joins('LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id')
                    .where(sellers: { blocked: false, deleted: false, flagged: false })
                    .where(flagged: false, deleted: false)
                    .where.not(id: ad.id, seller_id: ad.seller_id)

    # Normalize title for better matching
    normalized_title = normalize_title(ad.title)
    normalized_brand = normalize_brand(ad.brand)
    normalized_manufacturer = normalize_brand(ad.manufacturer) if ad.manufacturer.present?

    # Find same product with improved matching logic
    same_product_scope = base_scope
                           .where(category_id: ad.category_id, subcategory_id: ad.subcategory_id)

    # Build title matching conditions - use multiple strategies for better matching
    # Strategy 1: Exact match (case-insensitive, trimmed)
    # Strategy 2: Match with normalized title (if different from original)
    
    title_match_conditions = []
    title_match_params = []
    
    # Exact match
    title_match_conditions << "LOWER(TRIM(ads.title)) = LOWER(TRIM(?))"
    title_match_params << ad.title.to_s.strip
    
    # If normalized title is different, add it as alternative match
    if normalized_title != ad.title.to_s.downcase.strip
      title_match_conditions << "LOWER(TRIM(ads.title)) = ?"
      title_match_params << normalized_title
    end
    
    # Brand matching - handle nulls and case-insensitive
    brand_match_conditions = []
    brand_match_params = []
    
    if normalized_brand.present?
      # Match brand
      brand_match_conditions << "(LOWER(TRIM(COALESCE(ads.brand, ''))) = ?)"
      brand_match_params << normalized_brand
      
      # Match manufacturer if present
      if normalized_manufacturer.present?
        brand_match_conditions << "(LOWER(TRIM(COALESCE(ads.manufacturer, ''))) = ?)"
        brand_match_params << normalized_manufacturer
      end
    end

    # Apply title matching (OR conditions)
    if title_match_conditions.any?
      title_sql = title_match_conditions.join(' OR ')
      same_product_scope = same_product_scope.where(title_sql, *title_match_params)
    end

    # Apply brand matching (OR conditions) if brand exists
    if brand_match_conditions.any? && normalized_brand.present?
      brand_sql = brand_match_conditions.join(' OR ')
      same_product_scope = same_product_scope.where(brand_sql, *brand_match_params)
    end

    # Get same products with scoring and ordering
    same_product = same_product_scope
                     .select("ads.*, 
                             CASE tiers.id
                               WHEN 4 THEN 1
                               WHEN 3 THEN 2
                               WHEN 2 THEN 3
                               WHEN 1 THEN 4
                               ELSE 5
                             END AS tier_priority")
                     .includes(:reviews, offer_ads: :offer, seller: { seller_tier: :tier })
                     .limit(20) # Get more for scoring
                     .to_a

    # Score and rank same products
    scored_same_products = same_product.map do |alt|
      score = calculate_alternative_score(alt, ad, normalized_title, normalized_brand, true)
      { ad: alt, score: score }
    end.sort_by { |item| -item[:score] }.first(10).map { |item| item[:ad] }

    # Find similar items if we have fewer than 5 exact matches
    similar_items = []
    if scored_same_products.size < 5
      similar_scope = base_scope
                        .where(category_id: ad.category_id, subcategory_id: ad.subcategory_id)
                        .where.not(id: scored_same_products.map(&:id))

      # Extract key words from title (remove common words)
      key_words = extract_key_words(ad.title)
      
      if key_words.any?
        # Build ILIKE conditions for key words
        word_conditions = key_words.map { |word| "ads.title ILIKE ?" }.join(' OR ')
        word_params = key_words.map { |word| "%#{word}%" }
        similar_scope = similar_scope.where(word_conditions, *word_params)
      end

      # Get similar items with scoring
      similar_candidates = similar_scope
                             .select("ads.*, 
                                     CASE tiers.id
                                       WHEN 4 THEN 1
                                       WHEN 3 THEN 2
                                       WHEN 2 THEN 3
                                       WHEN 1 THEN 4
                                       ELSE 5
                                     END AS tier_priority")
                             .includes(:reviews, offer_ads: :offer, seller: { seller_tier: :tier })
                             .limit(20)
                             .to_a

      # Score and rank similar items
      scored_similar = similar_candidates.map do |alt|
        score = calculate_alternative_score(alt, ad, normalized_title, normalized_brand, false)
        { ad: alt, score: score }
      end.sort_by { |item| -item[:score] }.first(10).map { |item| item[:ad] }

      similar_items = scored_similar
    end

    render json: {
      same_product: serialize_alternatives(scored_same_products),
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

    # Logging disabled to reduce console noise
    # Rails.logger.info "Fetching related ads for ad ID: #{ad.id}, category: #{ad.category_id}, subcategory: #{ad.subcategory_id}"

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

  def authenticate_user_for_alternatives
    # Try authenticating as different user types (buyer, seller, admin, sales, marketing)
    @current_user = nil
    
    # Try buyer authentication first
    begin
      buyer_auth = BuyerAuthorizeApiRequest.new(request.headers)
      @current_user = buyer_auth.result
    rescue ExceptionHandler::InvalidToken => e
    rescue => e
      Rails.logger.debug "Buyer::AdsController#alternatives: Buyer auth error: #{e.class.name}: #{e.message}"
    end

    # Try seller authentication if buyer auth failed
    if @current_user.nil? || !@current_user.is_a?(Buyer)
      begin
        seller_auth = SellerAuthorizeApiRequest.new(request.headers)
        @current_user = seller_auth.result
      rescue ExceptionHandler::InvalidToken => e
        Rails.logger.debug "Buyer::AdsController#alternatives: Seller authentication failed: #{e.message}"
      rescue => e
        Rails.logger.debug "Buyer::AdsController#alternatives: Seller auth error: #{e.class.name}: #{e.message}"
      end
    end

    # Try admin authentication if still no user
    if @current_user.nil?
      begin
        admin_auth = AdminAuthorizeApiRequest.new(request.headers)
        @current_user = admin_auth.result
      rescue ExceptionHandler::InvalidToken => e
        Rails.logger.debug "Buyer::AdsController#alternatives: Admin authentication failed: #{e.message}"
      rescue => e
        Rails.logger.debug "Buyer::AdsController#alternatives: Admin auth error: #{e.class.name}: #{e.message}"
      end
    end

    # Try sales authentication if still no user
    if @current_user.nil?
      begin
        # SalesAuthorizeApiRequest is in lib, ensure it's loaded
        require_relative '../../lib/sales_authorize_api_request' unless defined?(SalesAuthorizeApiRequest)
        sales_auth = SalesAuthorizeApiRequest.new(request.headers)
        @current_user = sales_auth.result
      rescue ExceptionHandler::InvalidToken => e
        Rails.logger.debug "Buyer::AdsController#alternatives: Sales authentication failed: #{e.message}"
      rescue => e
        Rails.logger.debug "Buyer::AdsController#alternatives: Sales auth error: #{e.class.name}: #{e.message}"
      end
    end

    # Try marketing authentication if still no user
    if @current_user.nil?
      begin
        # MarketingAuthorizeApiRequest is in lib, ensure it's loaded
        require_relative '../../lib/marketing_authorize_api_request' unless defined?(MarketingAuthorizeApiRequest)
        marketing_auth = MarketingAuthorizeApiRequest.new(request.headers)
        @current_user = marketing_auth.result
      rescue ExceptionHandler::InvalidToken => e
        Rails.logger.debug "Buyer::AdsController#alternatives: Marketing authentication failed: #{e.message}"
      rescue => e
        Rails.logger.debug "Buyer::AdsController#alternatives: Marketing auth error: #{e.class.name}: #{e.message}"
      end
    end

    # Require any authenticated user (buyer, seller, admin, sales, or marketing)
    unless @current_user.is_a?(Buyer) || @current_user.is_a?(Seller) || @current_user.is_a?(Admin) || @current_user.is_a?(SalesUser) || @current_user.is_a?(MarketingUser)
      Rails.logger.warn "Buyer::AdsController#alternatives: Authentication failed - no valid user found"
      render json: { error: 'Authentication required to view alternative sellers' }, status: :unauthorized
    end
  end

  def serialize_alternatives(scope)
    scope.map do |alt|
      seller_tier_id = alt.seller&.seller_tier&.tier_id || 1
      review_count = alt.reviews&.count || 0
      avg_rating = if alt.reviews&.any?
        alt.reviews.sum(&:rating).to_f / review_count
      else
        0.0
      end

      # Get original_price from active offer if available
      original_price = nil
      if alt.association(:offer_ads).loaded?
        # Use preloaded associations (more efficient)
        active_offer_ad = alt.offer_ads.find do |offer_ad|
          offer = offer_ad.association(:offer).loaded? ? offer_ad.offer : offer_ad.offer
          offer && 
          ['active', 'scheduled'].include?(offer.status) &&
          offer.end_time >= Time.current
        end
        original_price = active_offer_ad&.original_price&.to_f
      else
        # Fallback to database query
        active_offer_ad = alt.offer_ads.joins(:offer)
                                    .where(offers: { status: ['active', 'scheduled'] })
                                    .where('offers.end_time >= ?', Time.current)
                                    .order('offers.start_time ASC')
                                    .first
        original_price = active_offer_ad&.original_price&.to_f
      end

      {
        id: alt.id,
        title: alt.title,
        price: alt.price&.to_f,
        original_price: original_price,
        first_media_url: alt.first_media_url,
        category_name: alt.category&.name,
        subcategory_name: alt.subcategory&.name,
        seller_id: alt.seller_id,
        seller_name: alt.seller&.fullname || alt.seller&.enterprise_name,
        seller_rating: alt.seller&.respond_to?(:calculate_mean_rating) ? alt.seller.calculate_mean_rating : nil,
        rating: avg_rating.round(2),
        review_count: review_count,
        seller_tier: seller_tier_id,
        seller_tier_name: (alt.seller&.seller_tier&.tier&.name || 'Free'),
        location: alt.seller&.county,
        brand: alt.brand,
        manufacturer: alt.manufacturer
      }
    end
  end

  # Normalize title for better matching
  def normalize_title(title)
    return "" if title.blank?
    title.to_s
         .downcase
         .strip
         .gsub(/[^\w\s]/, '')  # Remove special characters
         .gsub(/\s+/, ' ')     # Normalize multiple spaces
         .strip
  end

  # Normalize brand for better matching
  def normalize_brand(brand)
    return "" if brand.blank?
    brand.to_s
         .downcase
         .strip
         .gsub(/[^\w\s]/, '')  # Remove special characters
         .gsub(/\s+/, ' ')     # Normalize multiple spaces
         .strip
  end

  # Extract key words from title (removes common stop words)
  def extract_key_words(title)
    return [] if title.blank?
    
    # Common stop words to ignore
    stop_words = %w[
      a an and are as at be by for from has he in is it its of on that the to was will with
      the a an and or but in on at to for of with by from as is was are were been be have has had
      do does did will would should could may might must can this that these those
    ]
    
    words = title.to_s
                  .downcase
                  .gsub(/[^\w\s]/, ' ')
                  .split(/\s+/)
                  .reject(&:blank?)
                  .reject { |word| word.length < 3 }  # Remove very short words
                  .reject { |word| stop_words.include?(word) }
                  .uniq
    
    # Return top 3-5 most relevant words (longer words are usually more specific)
    words.sort_by { |w| -w.length }.first(5)
  end

  # Calculate relevance score for alternative products
  def calculate_alternative_score(alt, original_ad, normalized_title, normalized_brand, is_exact_match)
    score = 0.0

    # Title similarity (40% weight)
    alt_title_normalized = normalize_title(alt.title)
    if is_exact_match
      # Exact matches get full points
      if alt_title_normalized == normalized_title
        score += 40.0
      else
        # Partial match based on word overlap
        original_words = normalized_title.split(/\s+/).reject { |w| w.length < 3 }
        alt_words = alt_title_normalized.split(/\s+/).reject { |w| w.length < 3 }
        common_words = (original_words & alt_words).size
        if original_words.any?
          similarity = (common_words.to_f / original_words.size) * 40.0
          score += similarity
        end
      end
    else
      # Similar items - word overlap scoring
      original_words = normalized_title.split(/\s+/).reject { |w| w.length < 3 }
      alt_words = alt_title_normalized.split(/\s+/).reject { |w| w.length < 3 }
      common_words = (original_words & alt_words).size
      if original_words.any?
        similarity = (common_words.to_f / original_words.size) * 40.0
        score += similarity
      end
    end

    # Brand/Manufacturer match (20% weight)
    if normalized_brand.present?
      alt_brand_normalized = normalize_brand(alt.brand)
      alt_manufacturer_normalized = normalize_brand(alt.manufacturer) if alt.manufacturer.present?
      
      if alt_brand_normalized == normalized_brand || 
         (alt_manufacturer_normalized.present? && alt_manufacturer_normalized == normalized_brand)
        score += 20.0
      elsif alt_brand_normalized.include?(normalized_brand) || normalized_brand.include?(alt_brand_normalized)
        score += 10.0  # Partial brand match
      end
    end

    # Seller tier bonus (15% weight) - higher tier sellers get boost
    seller_tier_id = alt.seller&.seller_tier&.tier_id || 1
    tier_bonus = case seller_tier_id
                 when 4 then 15.0  # Premium
                 when 3 then 12.0  # Gold
                 when 2 then 9.0   # Silver
                 when 1 then 6.0   # Free
                 else 3.0
                 end
    score += tier_bonus

    # Rating and reviews (15% weight)
    review_count = alt.reviews&.count || 0
    avg_rating = if alt.reviews&.any?
      alt.reviews.sum(&:rating).to_f / review_count
    else
      0.0
    end
    
    if review_count > 0 && avg_rating > 0
      rating_score = (avg_rating / 5.0) * 10.0  # Normalize to 0-10
      review_bonus = [Math.log10(review_count + 1) * 2.0, 5.0].min  # Logarithmic bonus for review count
      score += rating_score + review_bonus
    end

    # Price competitiveness (10% weight) - lower price gets slight boost
    if alt.price.present? && original_ad.price.present?
      price_diff = ((original_ad.price - alt.price) / original_ad.price) * 100
      if price_diff > 0  # Alternative is cheaper
        price_bonus = [price_diff * 0.1, 10.0].min
        score += price_bonus
      end
    end

    score
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
    # OPTIMIZATION: Get subcategory counts first (this is relatively fast)
    subcategory_counts = Ad.active
      .joins(:seller)
      .where(sellers: { blocked: false, deleted: false, flagged: false })
      .where(flagged: false)
      .where("ads.media IS NOT NULL AND ads.media != '' AND ads.media::text != '[]' AND (ads.media::jsonb -> 0) IS NOT NULL")
      .group('ads.subcategory_id')
      .count('ads.id')
    
    subcategory_ids = subcategory_counts.keys.compact
    return { ads: [], subcategory_counts: subcategory_counts } if subcategory_ids.empty?
    
    # OPTIMIZATION: Use a much simpler query without CTE/window functions
    # Get ads grouped by subcategory and ordered by priority, then take top N per group
    sql = <<-SQL
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
        COALESCE(review_stats.average_rating, 0.0) as average_rating
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
      ORDER BY
        ads.subcategory_id,
        CASE COALESCE(tiers.id, 1)
          WHEN 4 THEN 1
          WHEN 3 THEN 2
          WHEN 2 THEN 3
          WHEN 1 THEN 4
          ELSE 5
        END,
        ads.created_at DESC
    SQL

    results = ActiveRecord::Base.connection.execute(sql)

    # OPTIMIZATION: Process results more efficiently in Ruby
    # Group by subcategory and take only top 6 per subcategory
    ads_by_subcategory = {}
    results.each do |row|
      subcategory_id = row['subcategory_id']
      ads_by_subcategory[subcategory_id] ||= []
      # Only keep top 6 per subcategory
      ads_by_subcategory[subcategory_id] << row if ads_by_subcategory[subcategory_id].size < 6
    end

    # Flatten back to single array
    results = ads_by_subcategory.values.flatten
    
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
    
    # OPTIMIZATION: Process media URLs more efficiently
    balanced_ads = results.map do |row|
      ad_id = row['id']
      media_json = row['media']
      
      # OPTIMIZED: Extract first media URL directly from JSONB in database
      # This avoids expensive JSON parsing in Ruby for most cases
      media_urls = []
      first_media_url = nil
      
      if media_json.present?
        begin
          # Quick check for array format and extract first valid URL
          if media_json.is_a?(String)
            # Handle empty arrays
            if media_json.strip == '[]' || media_json.strip == 'null' || media_json.strip == ''
              media_array = []
            else
              media_array = JSON.parse(media_json)
            end
          else
            media_array = media_json
          end
          
          if media_array.is_a?(Array) && media_array.any?
            # OPTIMIZATION: Only process the first URL for performance
            first_valid_url = media_array.find do |url|
              url.present? && 
              url.is_a?(String) && 
              url.strip.length > 0 &&
              (url.start_with?('http://') || url.start_with?('https://'))
            end
            first_media_url = first_valid_url
            media_urls = first_valid_url ? [first_valid_url] : []
          end
        rescue JSON::ParserError
          # Fallback for malformed JSON
          if media_json.is_a?(String) && (media_json.start_with?('http://') || media_json.start_with?('https://'))
            first_media_url = media_json
            media_urls = [media_json]
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
    # OPTIMIZED: Use caching for best sellers calculation
    cache_key = "best_sellers_optimized_#{limit}_#{Date.current.strftime('%Y%m%d')}"
    
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      # OPTIMIZATION: Use raw SQL with pre-aggregated metrics to avoid expensive joins
      sql = <<-SQL
        SELECT
                     ads.id,
                     ads.title,
                     ads.price,
                     ads.media,
                     ads.created_at,
          ads.category_id,
          ads.subcategory_id,
          ads.seller_id,
                     sellers.fullname as seller_name,
                     categories.name as category_name,
                     subcategories.name as subcategory_name,
                     COALESCE(tiers.id, 1) as seller_tier_id,
                     COALESCE(tiers.name, 'Free') as seller_tier_name,

          -- Pre-calculated metrics (much faster than separate joins)
          COALESCE(wishlist_stats.wishlist_count, 0) as wishlist_count,
          COALESCE(review_stats.review_count, 0) as review_count,
          COALESCE(review_stats.avg_rating, 0.0) as avg_rating,
          COALESCE(click_stats.click_count, 0) as click_count,

          -- Pre-calculated scores (moved from Ruby to SQL for performance)
          CASE
            WHEN ads.created_at >= CURRENT_DATE - INTERVAL '7 days' THEN 8
            WHEN ads.created_at >= CURRENT_DATE - INTERVAL '30 days' THEN 5
            WHEN ads.created_at >= CURRENT_DATE - INTERVAL '90 days' THEN 3
            WHEN ads.created_at >= CURRENT_DATE - INTERVAL '365 days' THEN 1
            ELSE 0
          END as recency_score,

          CASE COALESCE(tiers.id, 1)
            WHEN 4 THEN 15
            WHEN 3 THEN 8
            WHEN 2 THEN 4
            ELSE 0
          END as tier_bonus,

          -- Calculated comprehensive score in SQL
          (
            (
              CASE
                WHEN ads.created_at >= CURRENT_DATE - INTERVAL '7 days' THEN 8
                WHEN ads.created_at >= CURRENT_DATE - INTERVAL '30 days' THEN 5
                WHEN ads.created_at >= CURRENT_DATE - INTERVAL '90 days' THEN 3
                WHEN ads.created_at >= CURRENT_DATE - INTERVAL '365 days' THEN 1
                ELSE 0
              END * 0.25
            ) + (
              CASE COALESCE(tiers.id, 1)
                WHEN 4 THEN 15
                WHEN 3 THEN 8
                WHEN 2 THEN 4
                ELSE 0
              END * 0.15
            ) + (
              LN(COALESCE(wishlist_stats.wishlist_count, 0) + 1) * 20 * 0.25
            ) + (
              (
                (COALESCE(review_stats.avg_rating, 0.0) / 5.0) * 30 +
                LN(COALESCE(review_stats.review_count, 0) + 1) * 10
              ) * 0.20
            ) + (
              LN(COALESCE(click_stats.click_count, 0) + 1) * 15 * 0.15
            )
          ) as comprehensive_score

        FROM ads
        INNER JOIN sellers ON sellers.id = ads.seller_id
        INNER JOIN categories ON categories.id = ads.category_id
        INNER JOIN subcategories ON subcategories.id = ads.subcategory_id
        LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id
        LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id

        -- Pre-aggregated metrics (much faster than individual joins)
        LEFT JOIN (
          SELECT ad_id, COUNT(*) as wishlist_count
          FROM wish_lists
          GROUP BY ad_id
        ) wishlist_stats ON wishlist_stats.ad_id = ads.id

        LEFT JOIN (
          SELECT ad_id, COUNT(*) as review_count, AVG(rating) as avg_rating
          FROM reviews
          GROUP BY ad_id
        ) review_stats ON review_stats.ad_id = ads.id

        LEFT JOIN (
          SELECT ad_id, COUNT(*) as click_count
          FROM click_events
          WHERE event_type = 'Ad-Click'
          GROUP BY ad_id
        ) click_stats ON click_stats.ad_id = ads.id

        WHERE ads.deleted = false
          AND ads.flagged = false
          AND sellers.blocked = false
          AND sellers.deleted = false
          AND sellers.flagged = false
          AND ads.media IS NOT NULL
          AND ads.media != ''
          AND ads.media::text != '[]'
          AND (ads.media::jsonb -> 0) IS NOT NULL

        ORDER BY comprehensive_score DESC, RANDOM()
        LIMIT #{limit}
      SQL

      results = ActiveRecord::Base.connection.execute(sql)

      # OPTIMIZATION: Process media URLs for frontend compatibility
      results.map do |row|
        media_json = row['media']

        # Process media URLs similar to recommendations method
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
          rescue JSON::ParserError
            # If media is not valid JSON, try to use it as a single URL
            if media_json.is_a?(String) && (media_json.start_with?('http://') || media_json.start_with?('https://'))
              media_urls = [media_json]
              first_media_url = media_json
            end
          end
        end

        {
          ad_id: row['id'],
          id: row['id'],
          title: row['title'],
          price: row['price']&.to_f || 0.0,
          media: media_json,
          media_urls: media_urls,
          first_media_url: first_media_url,
          created_at: row['created_at'],
          seller_name: row['seller_name'],
          seller_id: row['seller_id'],
          category_name: row['category_name'],
          subcategory_name: row['subcategory_name'],
          seller_tier: row['seller_tier_id'],
          seller_tier_name: row['seller_tier_name'],
        metrics: {
            avg_rating: row['avg_rating']&.to_f&.round(2) || 0.0,
            review_count: row['review_count']&.to_i || 0,
            total_clicks: row['click_count']&.to_i || 0,
            wishlist_count: row['wishlist_count']&.to_i || 0
          },
          comprehensive_score: row['comprehensive_score']&.to_f&.round(2) || 0.0
        }
      end
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
