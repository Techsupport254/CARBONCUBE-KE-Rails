class Sales::AdSearchesController < ApplicationController
  before_action :authenticate_sales_user

  # GET /sales/ad_searches
  # GET /api/sales/ad_searches
  def index
    page = params[:page].to_i.positive? ? params[:page].to_i : 1
    per_page = [params[:per_page].to_i, 100].select(&:positive?).min || 50  # Max 100 per page for sales

    # Build filters from params
    filters = {}
    filters[:search_term] = params[:search_term] if params[:search_term].present?
    filters[:buyer_id] = params[:buyer_id] if params[:buyer_id].present?
    filters[:start_date] = params[:start_date] if params[:start_date].present?
    filters[:exclude_roles] = ['admin', 'sales']
    
    # Get search history from Redis
    result = SearchRedisService.search_history(
      page: page,
      per_page: per_page,
      filters: filters
    )

    # Format response for sales users
    formatted_searches = result[:searches].map do |search|
        # Convert to format expected by frontend
        {
          id: search[:id] || search['id'],
          search_term: search[:search_term] || search['search_term'],
          buyer_id: search[:buyer_id] || search['buyer_id'],
          user_id: search[:user_id] || search['user_id'],
          seller_id: search[:seller_id] || search['seller_id'],
          role: search[:role] || search['role'] || 'guest',
          created_at: (search[:created_at] || search[:timestamp] || search['created_at'] || search['timestamp']).to_s,
          timestamp: (search[:timestamp] || search['timestamp']).to_s,
          device_hash: search[:device_hash] || search['device_hash'],
          user_agent: search[:user_agent] || search['user_agent'],
          ip_address: search[:ip_address] || search['ip_address']
        }
      end

    # Enrich with user profile (avatar, display name) for buyers and sellers
    user_profiles = enrich_user_profiles(formatted_searches)
    formatted_searches.each do |search|
      uid_raw = search[:user_id].presence || search[:buyer_id].presence || search[:seller_id].presence
      uid = uid_raw.to_s.strip.downcase.presence
      role = search[:role].to_s.strip.downcase.presence || 'guest'
      profile = uid ? user_profiles[[uid, role]] : nil
      search[:user_profile] = if profile
        { avatar: profile[:avatar], display_name: profile[:display_name] }
      else
        { avatar: nil, display_name: nil }
      end
    end

    render json: {
      searches: formatted_searches,
      meta: {
        current_page: result[:current_page],
        per_page: per_page,
        total_count: result[:total_count],
        total_pages: result[:total_pages]
      }
    }, status: :ok
  end

  # GET /sales/ad_searches/analytics
  # GET /api/sales/ad_searches/analytics
  def analytics
    analytics_data = SearchRedisService.analytics

    # Get comprehensive search data for internal sales team (admin-level access)
    popular_searches = {
      all_time: SearchRedisService.popular_searches(50, :all),
      daily: SearchRedisService.popular_searches(30, :daily),
      weekly: SearchRedisService.popular_searches(40, :weekly),
      monthly: SearchRedisService.popular_searches(40, :monthly)
    }

    # Get trending searches over multiple timeframes
    trending_searches = {
      daily: SearchAnalytic.trending_searches(1).first(20),
      weekly: SearchAnalytic.trending_searches(7).first(30),
      monthly: SearchAnalytic.trending_searches(30).first(25)
    }

    # Get search analytics from database for additional insights
    latest_analytics = SearchAnalytic.latest
    db_analytics = latest_analytics ? {
      total_searches_today: latest_analytics.total_searches_today || 0,
      unique_search_terms_today: latest_analytics.unique_search_terms_today || 0,
      popular_searches_all_time: latest_analytics.popular_searches_all_time&.first(50) || [],
      last_updated: latest_analytics.updated_at.iso8601
    } : nil

    # Calculate device and user type distributions from recent searches
    device_stats = calculate_device_stats
    user_type_stats = calculate_user_type_stats

    # Known shop/seller names from DB for NLP intent: enterprise_name, fullname, username.
    # So queries like "pantech kenya", "top zone", or a person name / handle match as Shop.
    shop_names = Seller.where(deleted: false, blocked: false)
                       .pluck(:enterprise_name, :fullname, :username)
                       .each_with_object([]) do |(ent, full, user), arr|
                         arr.push(ent.to_s.strip) if ent.to_s.present?
                         arr.push(full.to_s.strip) if full.to_s.present?
                         arr.push(user.to_s.strip) if user.to_s.present?
                       end
                       .uniq

    # Catalog-driven intent: product terms (title/category/subcategory), brand names, manufacturer names.
    # Used by frontend NLP to show Search intent (Product, Brand, Manufacturer, Shop, etc.) and Top brands / Top products / Top manufacturers.
    catalog_product_terms, catalog_brand_terms, catalog_manufacturer_terms = build_catalog_intent_terms(popular_searches)

    render json: {
      analytics: analytics_data,
      popular_searches: popular_searches,
      trending_searches: trending_searches,
      db_analytics: db_analytics,
      device_stats: device_stats,
      user_type_stats: user_type_stats,
      shop_names: shop_names,
      catalog_product_terms: catalog_product_terms,
      catalog_brand_terms: catalog_brand_terms,
      catalog_manufacturer_terms: catalog_manufacturer_terms,
      data_retention: {
        individual_searches: 'Permanent (no expiration)',
        analytics_data: 'Permanent (no expiration)'
      }
    }, status: :ok
  end

  def calculate_device_stats
    # Get device distribution from recent searches
    recent_searches = SearchRedisService.search_history(page: 1, per_page: 1000)[:searches]

    device_counts = { mobile: 0, desktop: 0, tablet: 0, unknown: 0 }
    total = recent_searches.size

    recent_searches.each do |search|
      user_agent = search[:user_agent] || search['user_agent'] || ''
      device_type = if user_agent =~ /iPad|Android.*Tablet|Tablet|PlayBook|Silk/i
                      'tablet'
                    elsif user_agent =~ /Android.*Mobile|iPhone|iPod|BlackBerry|Windows Phone|Windows Mobile|Mobile Safari|Mobile/i
                      'mobile'
                    else
                      'desktop'
                    end
      device_counts[device_type.to_sym] += 1
    end

    {
      mobile: device_counts[:mobile],
      desktop: device_counts[:desktop],
      tablet: device_counts[:tablet],
      unknown: device_counts[:unknown],
      total: total
    }
  end

  def calculate_user_type_stats
    # Get user type distribution from recent searches
    recent_searches = SearchRedisService.search_history(page: 1, per_page: 1000)[:searches]

    # Count by role, excluding internal users
    role_counts = recent_searches
      .reject { |s| role = s[:role] || s['role']; ['admin', 'sales'].include?(role&.downcase) }
      .group_by { |s| s[:role] || s['role'] || 'guest' }
      .transform_values(&:size)

    total = role_counts.values.sum

    {
      buyers: role_counts['buyer'] || 0,
      sellers: role_counts['seller'] || 0,
      guests: role_counts['guest'] || 0,
      total: total
    }
  end

  private

  # Returns a hash (normalized_user_id, role) => { avatar:, display_name: } for buyers and sellers
  def enrich_user_profiles(searches)
    # Use user_id or buyer_id/seller_id so we always have the correct UUID for lookup
    buyer_ids = searches.select { |s| s[:role].to_s.downcase == 'buyer' }.filter_map { |s| (s[:user_id].presence || s[:buyer_id].presence).to_s.strip.presence }.uniq
    seller_ids = searches.select { |s| s[:role].to_s.downcase == 'seller' }.filter_map { |s| (s[:user_id].presence || s[:seller_id].presence).to_s.strip.presence }.uniq

    # Normalize UUIDs for key lookup (Redis and PostgreSQL may differ in case)
    normalize = ->(id) { id.to_s.strip.downcase.presence }

    profiles = {}
    if buyer_ids.any?
      # Include deleted buyers so we still show name/avatar for historical search records
      Buyer.where(id: buyer_ids).pluck(:id, :fullname, :profile_picture).each do |id, fullname, profile_picture|
        key = [normalize.call(id), 'buyer']
        profiles[key] = {
          avatar: profile_picture.presence,
          display_name: fullname.presence
        }
      end
    end
    if seller_ids.any?
      # Include deleted sellers so we still show name/avatar for historical search records
      Seller.where(id: seller_ids).pluck(:id, :fullname, :enterprise_name, :profile_picture).each do |id, fullname, enterprise_name, profile_picture|
        key = [normalize.call(id), 'seller']
        profiles[key] = {
          avatar: profile_picture.presence,
          display_name: (enterprise_name.presence || fullname.presence)
        }
      end
    end
    profiles
  end

  # Model-like tokens (e.g. s24, a54) are product models, not brand/manufacturer names. Exclude so they stay in product intent.
  MODEL_LIKE_PATTERN = /\A[a-z]+\d+[a-z]*\z|\A\d+[a-z]+\z/i

  # Returns [catalog_product_terms, catalog_brand_terms, catalog_manufacturer_terms] for NLP intent.
  # Product terms: title/category/subcategory matches only (no brand/manufacturer) so Top products shows product-type terms.
  # Brand terms: distinct ads.brand → Top brands and Brand intent (model-like terms excluded).
  # Manufacturer terms: distinct ads.manufacturer → Manufacturer intent (model-like terms excluded).
  def build_catalog_intent_terms(popular_searches)
    brand_raw = Ad.active.where(flagged: false).where.not(brand: [nil, '']).distinct.pluck(:brand).map { |b| b.to_s.strip.downcase.presence }.compact
    manufacturer_raw = Ad.active.where(flagged: false).where.not(manufacturer: [nil, '']).distinct.pluck(:manufacturer).map { |m| m.to_s.strip.downcase.presence }.compact
    brand_set = Set.new(brand_raw.reject { |b| b.match?(MODEL_LIKE_PATTERN) })
    manufacturer_set = Set.new(manufacturer_raw.reject { |m| m.match?(MODEL_LIKE_PATTERN) })

    terms = []
    %i[all_time weekly daily monthly].each do |key|
      list = popular_searches[key]
      next unless list.is_a?(Array)

      list.each { |pair| terms << pair[0].to_s.strip.downcase.presence }
    end
    terms = terms.compact.uniq
    max_terms = 200
    product_terms = Set.new

    # Product terms: search terms that match catalog (title, category, subcategory) but exclude pure brand/manufacturer names
    terms.first(max_terms).each do |normalized|
      next unless CatalogSearchExpansionService.short_product_like?(normalized)
      next if brand_set.include?(normalized) || manufacturer_set.include?(normalized)

      expansion = CatalogSearchExpansionService.expand(normalized)
      product_terms << normalized if expansion.present?
    end

    # Category and subcategory names are product-type terms (not brand/manufacturer)
    Category.pluck(:name).compact.each { |n| product_terms << n.to_s.strip.downcase if n.present? }
    Subcategory.pluck(:name).compact.each { |n| product_terms << n.to_s.strip.downcase if n.present? }

    [product_terms.to_a, brand_set.to_a, manufacturer_set.to_a]
  end

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end