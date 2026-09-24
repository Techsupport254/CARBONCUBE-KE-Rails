# frozen_string_literal: true

# Deterministic retrieve-then-rank pipeline for buyer ad search.
#
# Retrieval builds a broad candidate pool from tiered recall strategies
# (strict AND tokens, relaxed OR tokens + full-text tsearch, pg_trgm fuzzy,
# shop-name, synonym expansion) and external signals can never shrink it.
# Ranking then scores every candidate deterministically — Grok intent,
# shop-name matches, and popularity data only boost/reorder results.
#
class AdSearchService
  CANDIDATE_CAP = 400
  FUZZY_TITLE_THRESHOLD = 0.25
  FUZZY_TOKEN_THRESHOLD = 0.3
  TRIGRAM_BONUS_THRESHOLD = 0.3
  STRONG_MATCH_SCORE = 50
  SHOP_MATCH_MIN_SCORE = 60
  SHOP_MATCH_MIN_QUERY_LENGTH = 3
  RECENCY_WINDOW_DAYS = 7

  # Shop-name tokens too generic to identify a shop on their own (mirrors
  # Buyer::AdsController::GENERIC_SHOP_NAME_TOKENS — a shop-name match
  # requires at least one distinctive token).
  GENERIC_SHOP_NAME_TOKENS = %w[
    shop shops store stores seller sellers vendor vendors outlet outlets
    ltd limited co company kenya kenyan nairobi enterprise enterprises
    traders trading general electronics electronic hardware supplies
    suppliers services solutions international intl group holdings mart
    and the for of ag centre center plaza
  ].freeze

  # Query tokens that carry no retrieval signal on their own.
  SEARCH_STOPWORDS = %w[
    a an and are at be by for from in is it of on or the to with
  ].freeze

  class << self
    # @param query [String] raw buyer search query
    # @param search_intent [Hash, nil] Grok intent hash — feeds boosts only
    # @param page [Integer] 1-based page
    # @param per_page [Integer] page size
    # @param category [String, Integer, nil] explicit user-selected category (id or exact name)
    # @param subcategory [String, Integer, nil] explicit user-selected subcategory (id or exact name)
    # @return [Hash] { ads: [Ad], total: Integer } — total is the filtered pool size before pagination
    def search_ads(query:, search_intent: nil, page: 1, per_page: 24, category: nil, subcategory: nil)
      query = query.to_s.strip
      page = [page.to_i, 1].max
      per_page = per_page.to_i
      per_page = 24 if per_page < 1

      base = base_scope

      # Blank query: replicate the tier-priority randomized browse ordering.
      if query.blank?
        scope = apply_explicit_filters(base, category, subcategory)
        return { ads: browse_page(scope, page, per_page), total: scope.count }
      end

      normalized_query = normalize_query(query)
      tokens = significant_tokens(normalized_query)
      pool_ids = candidate_pool_ids(base, normalized_query, tokens, per_page)

      pool = apply_explicit_filters(base.where(id: pool_ids), category, subcategory)

      ranked = ranked_candidates(pool, normalized_query, tokens, search_intent)
      { ads: ranked.slice((page - 1) * per_page, per_page) || [], total: ranked.size }
    end

    private

    def base_scope
      Ad.active
        .with_valid_images
        .joins(:seller, :category, :subcategory)
        .where(sellers: { blocked: false, deleted: false, flagged: false })
        .where(flagged: false)
    end

    # Blank-query ordering: seller tier priority, then random. Results are
    # identical for every visitor, so cache per minute — ORDER BY RANDOM()
    # otherwise sorts the whole ads table on every browse request.
    def browse_page(scope, page, per_page)
      Rails.cache.fetch(
        "search_browse_#{page}_#{per_page}_#{Time.current.to_i / 60}",
        expires_in: 2.minutes
      ) do
        browse_page_uncached(scope, page, per_page)
      end
    end

    def browse_page_uncached(scope, page, per_page)
      scope
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
        .limit(per_page)
        .offset((page - 1) * per_page)
        .to_a # materialize — a lazy Relation can't be cached
    end

    # === Candidate pool (recall) ==========================================

    # Tiered fill: strict first; if fewer than per_page candidates, union
    # relaxed; still fewer, union fuzzy/synonym/shop. Tiers never remove
    # candidates — ranking decides order.
    def candidate_pool_ids(base, normalized_query, tokens, per_page)
      pool_ids = strict_tier_ids(base, tokens)

      pool_ids |= relaxed_tier_ids(base, normalized_query, tokens) if pool_ids.size < per_page

      if pool_ids.size < per_page
        pool_ids |= fuzzy_tier_ids(base, normalized_query, tokens)
        pool_ids |= synonym_tier_ids(base, normalized_query, tokens)
        pool_ids |= shop_tier_ids(base, normalized_query)
      end

      pool_ids.first(CANDIDATE_CAP)
    end

    # Ads where ALL significant query words match one of the searched fields.
    def strict_tier_ids(base, tokens)
      return [] if tokens.empty?

      scope = base
      tokens.each do |token|
        scope = scope.where(
          "ads.title ILIKE :p OR ads.brand ILIKE :p OR ads.model ILIKE :p OR ads.description ILIKE :p",
          p: "%#{escape_like(token)}%"
        )
      end
      scope.limit(CANDIDATE_CAP).pluck(:id)
    end

    # Ads where ANY significant query word matches (ORed), plus pg_search
    # tsearch ids which handle stemming/plurals.
    def relaxed_tier_ids(base, normalized_query, tokens)
      ids = []
      if tokens.any?
        clause = tokens.map do
          "(ads.title ILIKE ? OR ads.brand ILIKE ? OR ads.model ILIKE ? OR ads.description ILIKE ?)"
        end.join(" OR ")
        binds = tokens.flat_map { |t| Array.new(4, "%#{escape_like(t)}%") }
        ids = base.where(clause, *binds).limit(CANDIDATE_CAP).pluck(:id)
      end
      ids | tsearch_ids(base, normalized_query)
    end

    def tsearch_ids(base, normalized_query)
      base.merge(Ad.search_by_title_and_description(normalized_query)).limit(CANDIDATE_CAP).pluck(:id)
    rescue StandardError
      []
    end

    # pg_trgm typo tolerance: whole-title similarity plus word-level
    # similarity for each longer query token.
    def fuzzy_tier_ids(base, normalized_query, tokens)
      conditions = ["similarity(ads.title, ?) > ?"]
      binds = [normalized_query, FUZZY_TITLE_THRESHOLD]
      tokens.each do |token|
        next if token.length < 3
        conditions << "word_similarity(?, ads.title) > ?"
        binds += [token, FUZZY_TOKEN_THRESHOLD]
      end
      base.where(conditions.join(" OR "), *binds).limit(CANDIDATE_CAP).pluck(:id)
    rescue StandardError
      []
    end

    # Synonym variants (originals included upstream) added as extra OR'd
    # ILIKE terms over the same searched fields.
    def synonym_tier_ids(base, normalized_query, tokens)
      terms = synonym_terms(normalized_query) - tokens
      return [] if terms.empty?

      clause = terms.map do
        "(ads.title ILIKE ? OR ads.brand ILIKE ? OR ads.model ILIKE ? OR ads.description ILIKE ?)"
      end.join(" OR ")
      binds = terms.flat_map { |t| Array.new(4, "%#{escape_like(t)}%") }
      base.where(clause, *binds).limit(CANDIDATE_CAP).pluck(:id)
    end

    def synonym_terms(normalized_query)
      terms = defined?(SearchSynonymExpander) ? SearchSynonymExpander.terms_for(normalized_query) : nil
      terms = Array(terms)
      terms.map { |t| t.to_s.downcase.strip }.reject { |t| t.length < 2 }.uniq
    rescue StandardError
      []
    end

    # Ads whose seller's shop name is a quality match for the query.
    def shop_tier_ids(base, normalized_query)
      seller_ids = matched_shop_seller_ids(normalized_query)
      return [] if seller_ids.empty?

      base.where(seller_id: seller_ids).limit(CANDIDATE_CAP).pluck(:id)
    end

    # === Ranking ===========================================================

    def ranked_candidates(pool, normalized_query, tokens, search_intent)
      quoted_query = Ad.connection.quote(normalized_query)
      ads = pool
            .select(Arel.sql("ads.*, similarity(ads.title, #{quoted_query}) AS trigram_sim"))
            .includes(:category, :subcategory, seller: { seller_tier: :tier })
            .to_a

      popularity = popularity_scores(ads.map(&:id))
      shop_scores = {}
      syn_terms = synonym_terms(normalized_query) - tokens

      scored = ads.map do |ad|
        score, relevant = deterministic_score(ad, normalized_query, tokens, syn_terms, search_intent, popularity, shop_scores)
        { ad: ad, score: score, relevant: relevant }
      end

      # Noise floor: when strong matches exist, drop candidates with no
      # query-relevance signal — quality and popularity boosts must never be
      # the only reason an ad surfaces.
      if scored.any? { |item| item[:score] >= STRONG_MATCH_SCORE }
        scored = scored.select { |item| item[:relevant] }
      end

      scored.sort_by { |item| [-item[:score], tier_priority(item[:ad]), -item[:ad].created_at.to_i, rand] }
            .map { |item| item[:ad] }
    end

    # Returns [score, relevant]. `relevant` is true when the ad has at least
    # one signal tying it to the query (text, synonym, shop, or intent-term
    # match) — pure quality/popularity points do not count.
    def deterministic_score(record, normalized_query, tokens, syn_terms, search_intent, popularity, shop_scores)
      score = 0.0
      relevant = false
      title = record.title.to_s.downcase.strip
      brand = record.brand.to_s.downcase
      model = record.model.to_s.downcase
      manufacturer = record.manufacturer.to_s.downcase
      description = record.description.to_s.downcase

      # Full-phrase title matches
      if title == normalized_query
        score += 150
        relevant = true
      else
        if title.include?(normalized_query)
          score += 60
          relevant = true
        end
        if title.start_with?(normalized_query) || title.end_with?(normalized_query)
          score += 30
          relevant = true
        end
      end

      # Per-token weighted field matches
      matched_tokens = 0
      tokens.each do |token|
        matched = false
        if token_match?(title, token)
          score += 40
          matched = true
        end
        if token_match?(brand, token)
          score += 25
          matched = true
        end
        if token_match?(model, token)
          score += 25
          matched = true
        end
        if token_match?(manufacturer, token)
          score += 15
          matched = true
        end
        if token_match?(description, token)
          score += 8
          matched = true
        end
        matched_tokens += 1 if matched
      end
      relevant ||= matched_tokens.positive?
      score += (matched_tokens.to_f / tokens.size) * 30 if tokens.any?

      # Synonym-expanded term matches count as relevance at reduced weight.
      syn_terms.each do |term|
        next unless term.length >= 2

        if token_match?(title, term) || token_match?(brand, term) || token_match?(model, term)
          score += 20
          relevant = true
        elsif token_match?(description, term)
          score += 5
          relevant = true
        end
      end

      # Trigram similarity bonus (selected alongside the ad row)
      trigram_sim = record.has_attribute?(:trigram_sim) ? record[:trigram_sim].to_f : 0.0
      if trigram_sim > TRIGRAM_BONUS_THRESHOLD
        score += trigram_sim * 20
        relevant = true
      end

      score += intent_boosts(record, title, brand, model, search_intent)
      # Only the intent-brand component is a text-level signal — category
      # and product-type hints are contextual and must not mark relevance.
      relevant ||= intent_brand_match?(title, brand, model, search_intent)

      # Shop-name match boost (tiered, memoized per seller)
      if normalized_query.length >= SHOP_MATCH_MIN_QUERY_LENGTH && record.seller
        shop_scores[record.seller_id] ||= shop_name_match_score(normalized_query, record.seller)
        shop_boost = shop_scores[record.seller_id]
        score += shop_boost
        relevant ||= shop_boost.positive?
      end

      score += quality_boosts(record, title)
      score += popularity[record.id].to_f

      [[score, 0].max, relevant]
    end

    # Grok/AI intent can only boost — never exclude.
    def intent_boosts(record, title, brand, model, search_intent)
      return 0 unless search_intent.is_a?(Hash)

      boost = 0
      category_name = record.category&.name.to_s.downcase
      subcategory_name = record.subcategory&.name.to_s.downcase

      boost += 15 if intent_brand_match?(title, brand, model, search_intent)

      category_hint = intent_value(search_intent, :category_hint).to_s.downcase
      if category_hint.present?
        keywords = category_hint.tr("_", " ").split
        keywords += keywords.map { |kw| kw.chomp("s") }
        boost += 10 if keywords.any? do |kw|
          kw.length >= 2 && (category_name.include?(kw) || subcategory_name.include?(kw))
        end
      end

      product_type = intent_value(search_intent, :product_type).to_s.downcase
      if product_type.present?
        phrase = product_type.tr("_", " ")
        keywords = phrase.split
        if title.include?(phrase) || subcategory_name.include?(phrase) ||
           keywords.any? do |kw|
             kw.length >= 2 &&
               (token_match?(title, kw) || category_name.include?(kw) || subcategory_name.include?(kw))
           end
          boost += 10
        end
      end

      boost
    end

    def intent_brand_match?(title, brand, model, search_intent)
      intent_brand = intent_value(search_intent, :brand).to_s.downcase.strip
      intent_brand.present? &&
        (title.include?(intent_brand) || brand.include?(intent_brand) || model.include?(intent_brand))
    end

    def intent_value(search_intent, key)
      return nil unless search_intent.is_a?(Hash)

      search_intent[key] || search_intent[key.to_s]
    end

    # Quality boosts carried over from the previous scoring logic.
    def quality_boosts(record, title)
      boost = 0
      boost += 5 if record.seller&.document_verified?
      boost += 5 if record.seller&.seller_tier&.tier_id == 4
      days_old = ((Time.current - record.created_at) / 1.day).to_i
      boost += [0, RECENCY_WINDOW_DAYS - days_old].max
      boost += 2 if record.price.present? && record.price > 0 && record.price < 500_000
      boost -= 5 if title.length > 100
      boost
    end

    def popularity_scores(ad_ids)
      return {} unless defined?(SearchPopularityBoost) && ad_ids.any?

      SearchPopularityBoost.score_map(ad_ids) || {}
    rescue StandardError
      {}
    end

    def tier_priority(record)
      case record.seller&.seller_tier&.tier_id
      when 4 then 1 # Premium
      when 3 then 2 # Standard
      when 2 then 3 # Basic
      when 1 then 4 # Free
      else 5        # Unknown
      end
    end

    # === Explicit user-selected filters (these DO narrow the pool) =========

    def apply_explicit_filters(scope, category, subcategory)
      if category.present? && category != "All"
        if category.to_s.match?(/\A\d+\z/)
          scope = scope.where(category_id: category.to_i)
        else
          found = Category.find_by(name: category)
          scope = scope.where(category_id: found.id) if found
        end
      end

      if subcategory.present? && subcategory != "All"
        if subcategory.to_s.match?(/\A\d+\z/)
          scope = scope.where(subcategory_id: subcategory.to_i)
        else
          found = Subcategory.find_by(name: subcategory)
          scope = scope.where(subcategory_id: found.id) if found
        end
      end

      scope
    end

    # === Query normalization / tokenization ================================

    def normalize_query(query)
      normalized = defined?(SearchQueryNormalizer) ? SearchQueryNormalizer.normalize(query) : query
      normalized = normalized.to_s.downcase.strip
      normalized.presence || query.to_s.downcase.strip
    rescue StandardError
      query.to_s.downcase.strip
    end

    def significant_tokens(normalized_query)
      normalized_query.split(/[^\p{Alnum}]+/)
                      .map(&:downcase)
                      .reject { |t| t.length < 2 || SEARCH_STOPWORDS.include?(t) }
                      .uniq
    end

    def escape_like(token)
      ActiveRecord::Base.sanitize_sql_like(token)
    end

    # Word-boundary-aware match on normalized lowercase text.
    def token_match?(text, token)
      return false if text.blank?

      text.match?(/\b#{Regexp.escape(token)}\b/)
    end

    # === Shop-name matching (mirrors Buyer::AdsController helpers) =========

    # Resolve sellers whose shop name is a quality match for the query.
    # Broad SQL prefilter for recall (full token or 3-char prefix), then
    # scored in Ruby so only strong matches include that shop's products.
    def matched_shop_seller_ids(query)
      tokens = shop_name_tokens(query)
      return [] if tokens.empty?

      patterns = tokens.flat_map do |token|
        token.length >= 4 ? ["%#{token}%", "%#{token[0, 3]}%"] : ["%#{token}%"]
      end.uniq
      like_condition = patterns.map do
        "(sellers.enterprise_name ILIKE ? OR sellers.fullname ILIKE ?)"
      end.join(" OR ")
      # pg_trgm word_similarity catches typos the ILIKE patterns miss.
      condition = "(#{like_condition}) OR word_similarity(?, sellers.enterprise_name) > 0.3 OR word_similarity(?, sellers.fullname) > 0.3"
      binds = patterns.flat_map { |p| [p, p] } + [query, query]

      Seller.where(blocked: false, deleted: false, flagged: false)
            .where(condition, *binds)
            .limit(200)
            .select { |seller| shop_name_match_score(query, seller) >= SHOP_MATCH_MIN_SCORE }
            .map(&:id)
    end

    # Tiered shop-name relevance: exact normalized match (150), all
    # distinctive query tokens in the name (120), containment either way
    # (90), or fuzzy per-token match (60). Requires a distinctive token so
    # generic words alone never match.
    def shop_name_match_score(query, seller)
      return 0 unless seller

      query_norm = normalize_shop_text(query)
      query_tokens = shop_name_tokens(query)
      query_distinctive = query_tokens - GENERIC_SHOP_NAME_TOKENS
      return 0 if query_norm.blank?

      [seller.enterprise_name, seller.fullname].compact.filter_map do |raw_name|
        name_norm = normalize_shop_text(raw_name)
        name_tokens = shop_name_tokens(raw_name)
        next if name_norm.blank? || name_tokens.empty?

        name_distinctive = name_tokens - GENERIC_SHOP_NAME_TOKENS

        if name_norm == query_norm ||
           (name_distinctive.any? && name_distinctive.sort == query_distinctive.sort)
          next 150
        end

        if query_distinctive.any? && (query_distinctive - name_tokens).empty?
          next 120
        end

        if query_distinctive.any? &&
           (name_norm.include?(query_norm) ||
            (name_distinctive.any? && query_norm.include?(name_norm)))
          next 90
        end

        if query_distinctive.any? &&
           query_distinctive.all? { |t| name_tokens.any? { |nt| shop_tokens_close?(t, nt) } }
          next 60
        end

        nil
      end.max || 0
    end

    def shop_tokens_close?(token_a, token_b)
      return true if token_a == token_b
      return true if token_a.length >= 3 && token_b.start_with?(token_a)
      return true if token_b.length >= 3 && token_a.start_with?(token_b)

      token_a.length >= 4 && token_b.length >= 4 && levenshtein_distance(token_a, token_b) <= 1
    end

    def normalize_shop_text(text)
      text.to_s.downcase.gsub(/[^a-z0-9\s]/, " ").gsub(/\s+/, " ").strip
    end

    def shop_name_tokens(text)
      normalize_shop_text(text).split(" ").reject { |t| t.length < 2 }.uniq
    end

    def levenshtein_distance(str_a, str_b)
      return str_a.length if str_b.empty?
      return str_b.length if str_a.empty?

      matrix = Array.new(str_a.length + 1) { Array.new(str_b.length + 1) }

      (0..str_a.length).each { |i| matrix[i][0] = i }
      (0..str_b.length).each { |j| matrix[0][j] = j }

      (1..str_a.length).each do |i|
        (1..str_b.length).each do |j|
          cost = str_a[i - 1] == str_b[j - 1] ? 0 : 1
          matrix[i][j] = [
            matrix[i - 1][j] + 1,
            matrix[i][j - 1] + 1,
            matrix[i - 1][j - 1] + cost
          ].min
        end
      end

      matrix[str_a.length][str_b.length]
    end
  end
end
