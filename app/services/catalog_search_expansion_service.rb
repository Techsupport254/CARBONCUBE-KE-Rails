# frozen_string_literal: true

# Catalog-driven search expansion: infers brand, category, and model from actual
# ad data (Ad model fields and related Category/Subcategory). No hardcoded synonym lists.
#
# Uses Ad fields: title, brand, manufacturer; and Category/Subcategory names.
# Research: Amazon "Unsupervised synonym extraction for document enhancement in e-commerce search"
#
class CatalogSearchExpansionService
  CACHE_PREFIX = "catalog_expansion"
  CACHE_TTL = 1.hour
  MIN_QUERY_LENGTH = 2
  MAX_QUERY_LENGTH = 30
  SAMPLE_LIMIT = 300

  class << self
    # @param query [String] short search query (e.g. "a54", "s24", "petromax")
    # @return [Hash, nil] { brand:, model:, category_hint:, category_id: } or nil if no catalog signal
    def expand(query)
      return nil if query.blank?

      normalized = query.to_s.strip.downcase
      return nil if normalized.length < MIN_QUERY_LENGTH || normalized.length > MAX_QUERY_LENGTH

      cache_key = "#{CACHE_PREFIX}:v3:#{normalized}"
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        infer_from_catalog(normalized)
      end
    end

    # Check if query looks like a short product/model-style token (alphanumeric, optional spaces)
    def short_product_like?(query)
      return false if query.blank?

      q = query.to_s.strip
      return false if q.length < MIN_QUERY_LENGTH || q.length > MAX_QUERY_LENGTH

      q.match?(/\A[\p{Alnum}\s]+\z/)
    end

    private

    def infer_from_catalog(normalized_query)
      base_scope = Ad.active
                     .with_valid_images
                     .joins(:seller, :category, :subcategory)
                     .where(sellers: { blocked: false, deleted: false, flagged: false })
                     .where(ads: { flagged: false })

      # Match query against Ad fields (title, brand, manufacturer) and Category/Subcategory names
      pattern = "%#{normalized_query}%"
      sql = <<~SQL.squish
        LOWER(ads.title) LIKE :pat
        OR LOWER(COALESCE(ads.brand, '')) LIKE :pat
        OR LOWER(COALESCE(ads.manufacturer, '')) LIKE :pat
        OR LOWER(COALESCE(categories.name, '')) LIKE :pat
        OR LOWER(COALESCE(subcategories.name, '')) LIKE :pat
      SQL
      matching = base_scope
                   .where(sql, pat: pattern)
                   .limit(SAMPLE_LIMIT)
                   .pluck(:category_id, "categories.name", "subcategories.name", :brand)

      return nil if matching.empty?

      # Infer top category (by frequency)
      category_counts = Hash.new(0)
      category_names = {}
      matching.each do |cat_id, cat_name, sub_name, _brand|
        key = cat_id
        category_counts[key] += 1
        category_names[key] = [cat_name, sub_name].compact.join(" ").downcase
      end

      top_category_id = category_counts.max_by { |_, count| count }&.first
      top_category_name = category_names[top_category_id].to_s

      # Infer top brand (by frequency), normalized
      brand_counts = Hash.new(0)
      matching.each do |_cat_id, _cat_name, _sub_name, brand|
        next if brand.blank?

        b = brand.to_s.strip.downcase
        brand_counts[b] += 1
      end
      top_brand = brand_counts.max_by { |_, count| count }&.first

      # Map category name to category_hint for downstream (e.g. filter by "phone")
      category_hint = category_hint_from_name(top_category_name)

      {
        brand: top_brand,
        model: normalized_query,
        category_hint: category_hint,
        category_id: top_category_id
      }
    end

    def category_hint_from_name(name)
      return nil if name.blank?

      n = name.downcase
      return "phones" if n.include?("phone") || n.include?("mobile") || n.include?("smartphone")
      return "laptops" if n.include?("laptop") || n.include?("notebook") || n.include?("computer")

      nil
    end
  end
end
