# Optimized Ads Service for Performance
# This service provides cached, optimized database queries for ads
class OptimizedAdsService
  include ActiveSupport::Benchmarkable

  # Cache tier priorities to avoid repeated calculations
  TIER_PRIORITIES = {
    4 => 1,  # Premium
    3 => 2,  # Gold  
    2 => 3,  # Silver
    1 => 4,  # Bronze
    0 => 5   # Free
  }.freeze

  class << self
    # Get optimized ads with caching
    def fetch_ads(filters = {})
      cache_key = build_cache_key(filters)
      
      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        benchmark("OptimizedAdsService.fetch_ads") do
          # Use the optimized query but return ActiveRecord objects
          query = build_optimized_query(filters)
          
          # Apply pagination and randomization
          per_page = filters[:per_page] || 24
          page = filters[:page] || 1
          
          # Get the base query and apply randomization
          randomized_query = query.order(
            Arel.sql('RANDOM()'),
            Arel.sql('ads.created_at DESC'),
            Arel.sql('ads.id')
          ).limit(per_page).offset((page - 1) * per_page)
          
          # Return as ActiveRecord objects with includes for associations
          randomized_query.includes(:category, :subcategory, seller: { seller_tier: :tier })
        end
      end
    end

    # Get categories with ads count (cached)
    def categories_with_counts
      Rails.cache.fetch('categories_with_ads_count', expires_in: 1.hour) do
        benchmark("OptimizedAdsService.categories_with_counts") do
          Category.joins(:ads)
                  .where(ads: { deleted: false, flagged: false })
                  .joins('JOIN sellers ON ads.seller_id = sellers.id')
                  .where(sellers: { blocked: false, deleted: false, flagged: false })
                  .group('categories.id, categories.name')
                  .select('categories.id, categories.name, COUNT(ads.id) as ads_count')
                  .order('ads_count DESC')
        end
      end
    end

    # Get subcategories with ads count (cached)
    def subcategories_with_counts
      Rails.cache.fetch('subcategories_with_ads_count', expires_in: 1.hour) do
        benchmark("OptimizedAdsService.subcategories_with_counts") do
          Subcategory.joins(:ads)
                     .where(ads: { deleted: false, flagged: false })
                     .joins('JOIN sellers ON ads.seller_id = sellers.id')
                     .where(sellers: { blocked: false, deleted: false, flagged: false })
                     .group('subcategories.id, subcategories.name, subcategories.category_id')
                     .select('subcategories.id, subcategories.name, subcategories.category_id, COUNT(ads.id) as ads_count')
                     .order('ads_count DESC')
        end
      end
    end

    # Pre-calculate tier priorities for faster sorting
    def tier_priority_for(tier_id)
      TIER_PRIORITIES[tier_id] || 5
    end

    # Clear all related caches
    def clear_caches
      Rails.cache.delete_matched('optimized_ads_*')
      Rails.cache.delete('categories_with_ads_count')
      Rails.cache.delete('subcategories_with_ads_count')
    end

    private

    def build_cache_key(filters)
      key_parts = [
        'optimized_ads',
        filters[:per_page] || 24,
        filters[:page] || 1,
        filters[:category_id],
        filters[:subcategory_id],
        filters[:balanced] ? 'balanced' : 'normal',
        Time.current.to_i / 300 # 5-minute cache buckets
      ]
      key_parts.compact.join('_')
    end

    def build_optimized_query(filters)
      # Base query with optimized joins - return ActiveRecord objects
      query = Ad.active.with_valid_images
                .joins(:seller, :category, :subcategory)
                .joins('LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id')
                .joins('LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id')
                .where(sellers: { blocked: false, deleted: false, flagged: false })
                .where(flagged: false)

      # Apply filters
      query = query.where(category_id: filters[:category_id]) if filters[:category_id].present?
      query = query.where(subcategory_id: filters[:subcategory_id]) if filters[:subcategory_id].present?

      # Return the query without custom SELECT to maintain ActiveRecord object behavior
      query
    end
  end
end
