# Similar Products Service
# Provides similar and alternative products logic for product detail pages
class SimilarProductsService
  class << self
    def find_similar_products(ad, limit: 15)
      # Normalize title and brand for better matching
      normalized_title = normalize_title(ad.title)
      normalized_brand = normalize_brand(ad.brand)
      normalized_manufacturer = normalize_brand(ad.manufacturer) if ad.manufacturer.present?

      # Find alternative sellers for the same product (different sellers, same product)
      alternative_sellers = find_alternative_sellers(ad, normalized_title, normalized_brand, normalized_manufacturer)

      # Find exact same products from other sellers (for comparison)
      same_products = find_same_products(ad, normalized_title, normalized_brand, normalized_manufacturer, exclude_current_seller: true)

      # Find similar products if we don't have enough exact matches
      similar_products = []
      exclude_ids = (same_products + alternative_sellers).map(&:id)
      if same_products.size + alternative_sellers.size < 8
        similar_products = find_similar_products_by_keywords(ad, normalized_title, normalized_brand, exclude_ids)
      end

      # Return serialized results
      {
        alternative_sellers: serialize_alternatives(alternative_sellers),
        same_products: serialize_alternatives(same_products),
        similar_products: serialize_alternatives(similar_products),
        total_count: alternative_sellers.size + same_products.size + similar_products.size
      }
    end

    private

    def find_alternative_sellers(ad, normalized_title, normalized_brand, normalized_manufacturer)
      # Find products from the SAME seller with similar titles (alternative products from same seller)
      alternative_scope = Ad.active.with_valid_images
                             .select('ads.*')
                             .joins(:seller, :category, :subcategory)
                             .joins('LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id')
                             .joins('LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id')
                             .where(sellers: { blocked: false, deleted: false, flagged: false })
                             .where(flagged: false, deleted: false)
                             .where.not(id: ad.id)
                             .where(seller_id: ad.seller_id) # SAME seller
                             .where(category_id: ad.category_id) # Same category

      # Extract key words from title and find similar products from same seller
      key_words = extract_key_words(ad.title)

      if key_words.any?
        # Build ILIKE conditions for key words (but not exact matches)
        word_conditions = key_words.map { |word| "ads.title ILIKE ?" }.join(' OR ')
        word_params = key_words.map { |word| "%#{word}%" }
        alternative_scope = alternative_scope.where(word_conditions, *word_params)
                                             .where.not("LOWER(TRIM(ads.title)) = LOWER(TRIM(?))", ad.title.to_s.strip)
      end

      # Get alternative products with scoring
      alternatives = alternative_scope
                      .select("ads.*,
                              CASE tiers.id
                                WHEN 4 THEN 1
                                WHEN 3 THEN 2
                                WHEN 2 THEN 3
                                WHEN 1 THEN 4
                                ELSE 5
                              END AS tier_priority")
                      .includes(:reviews, offer_ads: :offer, seller: { seller_tier: :tier })
                      .limit(8)
                      .to_a

      # Score and rank alternative products
      scored_alternatives = alternatives.map do |alt|
        score = calculate_alternative_score(alt, ad, normalized_title, normalized_brand, false)
        { ad: alt, score: score }
      end.sort_by { |item| -item[:score] }.first(5).map { |item| item[:ad] }

      scored_alternatives
    end

    def build_base_scope(ad, exclude_current_seller: false)
      scope = Ad.active.with_valid_images
                 .select('ads.*')
                 .joins(:seller, :category, :subcategory)
                 .joins('LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id')
                 .joins('LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id')
                 .where(sellers: { blocked: false, deleted: false, flagged: false })
                 .where(flagged: false, deleted: false)
                 .where.not(id: ad.id)

      # Optionally exclude current seller
      scope = scope.where.not(seller_id: ad.seller_id) if exclude_current_seller

      scope
    end

    def find_same_products(ad, normalized_title, normalized_brand, normalized_manufacturer, exclude_current_seller: false)
      base_scope = build_base_scope(ad, exclude_current_seller: exclude_current_seller)
      same_product_scope = base_scope
                             .where(category_id: ad.category_id, subcategory_id: ad.subcategory_id)

      # Build title matching conditions
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

      # Brand matching
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

      # Apply title matching
      if title_match_conditions.any?
        title_sql = title_match_conditions.join(' OR ')
        same_product_scope = same_product_scope.where(title_sql, *title_match_params)
      end

      # Apply brand matching if brand exists
      if brand_match_conditions.any? && normalized_brand.present?
        brand_sql = brand_match_conditions.join(' OR ')
        same_product_scope = same_product_scope.where(brand_sql, *brand_match_params)
      end

      # Get same products with scoring and ordering
      same_products = same_product_scope
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

      # Score and rank same products
      scored_same_products = same_products.map do |alt|
        score = calculate_alternative_score(alt, ad, normalized_title, normalized_brand, true)
        { ad: alt, score: score }
      end.sort_by { |item| -item[:score] }.first(10).map { |item| item[:ad] }

      scored_same_products
    end

    def find_similar_products_by_keywords(ad, normalized_title, normalized_brand, exclude_ids)
      base_scope = build_base_scope(ad, exclude_current_seller: true)
      similar_scope = base_scope
                        .where(category_id: ad.category_id, subcategory_id: ad.subcategory_id)
                        .where.not(id: exclude_ids)

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

      scored_similar
    end

    # Helper methods extracted from buyer/ads_controller.rb

    def normalize_title(title)
      return '' if title.blank?
      # Remove extra spaces, normalize case, remove special chars but keep numbers/letters
      title.to_s.downcase.strip
           .gsub(/[^\w\s-]/, '') # Remove special characters except hyphens
           .gsub(/\s+/, ' ') # Normalize multiple spaces
           .strip
    end

    def normalize_brand(brand)
      return '' if brand.blank?
      # Normalize brand names for better matching
      brand.to_s.downcase.strip
           .gsub(/[^\w\s]/, '') # Remove all special characters
           .gsub(/\s+/, ' ') # Normalize spaces
           .strip
    end

    def extract_key_words(title)
      return [] if title.blank?

      # Common words to exclude from matching
      stop_words = Set.new([
        'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by',
        'new', 'used', 'refurbished', 'original', 'genuine', 'authentic', 'brand', 'quality',
        'best', 'good', 'great', 'excellent', 'super', 'premium', 'cheap', 'affordable',
        'black', 'white', 'red', 'blue', 'green', 'yellow', 'gray', 'grey', 'silver', 'gold',
        'small', 'medium', 'large', 'extra', 'plus', 'mini', 'max', 'pro', 'lite', 'ultra'
      ])

      # Extract words, normalize, and filter
      words = title.to_s.downcase.scan(/\b\w+\b/)
      words.reject { |word| word.length < 3 || stop_words.include?(word) }
           .uniq
           .first(5) # Limit to top 5 keywords
    end

    def calculate_alternative_score(alt, original_ad, normalized_title, normalized_brand, is_exact_match)
      score = 0.0

      # Base score for tier priority (higher tier = higher score)
      tier_score = case alt.tier_priority
                   when 1 then 50.0  # Premium
                   when 2 then 40.0  # Gold
                   when 3 then 30.0  # Silver
                   when 4 then 20.0  # Bronze
                   else 10.0         # Free
                   end
      score += tier_score

      # Title similarity (40% weight)
      if is_exact_match
        score += 40.0 # Exact matches get full title score
      else
        # Calculate word overlap
        original_words = Set.new(normalized_title.scan(/\b\w+\b/))
        alt_words = Set.new(normalize_title(alt.title).scan(/\b\w+\b/))

        if original_words.any?
          common_words = original_words.intersection(alt_words).size
          similarity = (common_words.to_f / original_words.size) * 40.0
          score += similarity
        end
      end

      # Brand match bonus (30% weight)
      if normalized_brand.present? && normalize_brand(alt.brand) == normalized_brand
        score += 30.0
      end

      # Price similarity (20% weight) - prefer similar priced items
      if original_ad.price.present? && alt.price.present?
        price_ratio = [original_ad.price, alt.price].min.to_f / [original_ad.price, alt.price].max.to_f
        price_score = price_ratio * 20.0
        score += price_score
      end

      # Review count bonus (10% weight) - prefer items with more reviews
      review_score = [alt.reviews_count || 0, 10].min * 1.0 # Max 10 reviews = 10 points
      score += review_score

      score
    end

    def serialize_alternatives(ads)
      return [] if ads.blank?

      ads.map do |ad|
        AdSerializer.new(ad).as_json
      end
    end
  end
end