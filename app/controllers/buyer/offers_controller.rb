class Buyer::OffersController < ApplicationController
  before_action :authenticate_buyer, except: [:index, :show, :active_offers]
  
  # GET /buyer/offers
  # Returns ALL active offers with their ads for the deals page
  # OPTIMIZED: Uses raw SQL for better performance instead of complex ActiveRecord includes
  def index
    # OPTIMIZATION: Build dynamic WHERE conditions
    where_conditions = ["offers.status IN ('active', 'scheduled')"]
    where_params = []

    where_conditions << "offers.end_time > ?"
    where_params << Time.current

    # Add offer type filter
    if params[:offer_type].present?
      where_conditions << "offers.offer_type = ?"
      where_params << params[:offer_type]
    end

    # Add category filter
    if params[:category_id].present?
      where_conditions << "offers.target_categories @> ?"
      where_params << [params[:category_id]].to_json
    end

    # Add search filter
    if params[:search].present?
      search_term = params[:search]
      where_conditions << "(offers.name ILIKE ? OR offers.description ILIKE ?)"
      where_params << "%#{search_term}%" << "%#{search_term}%"
    end

    # Pagination
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 100).to_i
    per_page = [per_page, 100].min # Max 100 per page
    offset = (page - 1) * per_page

    # OPTIMIZATION: Use raw SQL for better performance
    # Get offers with essential data only (no heavy includes)
    sql = <<-SQL
      SELECT
        offers.id,
        offers.name,
        offers.description,
        offers.offer_type,
        offers.discount_type,
        offers.discount_percentage,
        offers.fixed_discount_amount,
        offers.start_time,
        offers.end_time,
        offers.featured,
        offers.priority,
        offers.show_on_homepage,
        offers.target_categories,
        offers.minimum_order_amount,
        offers.banner_color,
        offers.badge_color,
        offers.icon_name,
        offers.badge_text,
        offers.cta_text,
        offers.view_count,
        offers.click_count,
        offers.conversion_count,
        offers.revenue_generated,
        sellers.id as seller_id,
        sellers.enterprise_name as seller_name,
        sellers.fullname as seller_fullname,
        tiers.id as seller_tier_id,
        tiers.name as seller_tier_name
      FROM offers
      INNER JOIN sellers ON sellers.id = offers.seller_id
      LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id
      LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id
      WHERE #{where_conditions.join(' AND ')}
        AND sellers.blocked = false
        AND sellers.deleted = false
        AND sellers.flagged = false
      ORDER BY offers.priority DESC, offers.created_at DESC
      LIMIT ? OFFSET ?
    SQL

    # Add pagination params
    query_params = where_params + [per_page, offset]

    # Execute query
    offers_data = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.send(:sanitize_sql_array, [sql] + query_params)
    )

    # Get total count for pagination
    count_sql = <<-SQL
      SELECT COUNT(*) as total
      FROM offers
      INNER JOIN sellers ON sellers.id = offers.seller_id
      WHERE #{where_conditions.join(' AND ')}
        AND sellers.blocked = false
        AND sellers.deleted = false
        AND sellers.flagged = false
    SQL

    total_count_result = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.send(:sanitize_sql_array, [count_sql] + where_params)
    )
    total_count = total_count_result.first['total'].to_i

    # OPTIMIZATION: Get ads for all offers in a single query
    if offers_data.any?
      offer_ids = offers_data.map { |row| row['id'] }

        ads_sql = <<-SQL
          SELECT
            offer_ads.offer_id,
            offer_ads.original_price,
            offer_ads.discounted_price,
            offer_ads.discount_percentage,
            ads.id,
            ads.title,
            ads.price,
            ads.media,
            ads.created_at,
            categories.name as category_name,
            subcategories.name as subcategory_name,
            ad_sellers.fullname as seller_name,
            ad_tiers.id as seller_tier_id,
            ad_tiers.name as seller_tier_name,
            COALESCE(review_stats.review_count, 0) as review_count,
            COALESCE(review_stats.avg_rating, 0.0) as avg_rating
          FROM offer_ads
          INNER JOIN ads ON ads.id = offer_ads.ad_id
          INNER JOIN categories ON categories.id = ads.category_id
          INNER JOIN subcategories ON subcategories.id = ads.subcategory_id
          INNER JOIN sellers ad_sellers ON ad_sellers.id = ads.seller_id
          LEFT JOIN seller_tiers ad_seller_tiers ON ad_sellers.id = ad_seller_tiers.seller_id
          LEFT JOIN tiers ad_tiers ON ad_seller_tiers.tier_id = ad_tiers.id
          LEFT JOIN (
            SELECT
              ad_id,
              COUNT(*) as review_count,
              AVG(rating) as avg_rating
            FROM reviews
            GROUP BY ad_id
          ) review_stats ON review_stats.ad_id = ads.id
          WHERE offer_ads.offer_id IN (#{offer_ids.map { '?' }.join(',')})
            AND ads.deleted = false
            AND ads.flagged = false
            AND ad_sellers.blocked = false
            AND ad_sellers.deleted = false
            AND ad_sellers.flagged = false
          ORDER BY offer_ads.offer_id, ads.created_at DESC
        SQL

      ads_data = ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.send(:sanitize_sql_array, [ads_sql] + offer_ids)
      )

      # Group ads by offer_id
      ads_by_offer = {}
      ads_data.each do |row|
        offer_id = row['offer_id']
        ads_by_offer[offer_id] ||= []
        ads_by_offer[offer_id] << row
      end

      # OPTIMIZATION: Build optimized response structure
      offers = offers_data.map do |offer_row|
        offer_id = offer_row['id']
        ads = ads_by_offer[offer_id] || []

        # Build optimized offer structure
        {
          id: offer_id,
          name: offer_row['name'],
          description: offer_row['description'],
          offer_type: offer_row['offer_type'],
          discount_type: offer_row['discount_type'],
          discount_percentage: offer_row['discount_percentage'],
          fixed_discount_amount: offer_row['fixed_discount_amount'],
          start_time: offer_row['start_time'],
          end_time: offer_row['end_time'],
          featured: offer_row['featured'],
          priority: offer_row['priority'],
          show_on_homepage: offer_row['show_on_homepage'],
          target_categories: offer_row['target_categories'],
          minimum_order_amount: offer_row['minimum_order_amount'],
          banner_color: offer_row['banner_color'],
          badge_color: offer_row['badge_color'],
          icon_name: offer_row['icon_name'],
          badge_text: offer_row['badge_text'],
          cta_text: offer_row['cta_text'],
          view_count: offer_row['view_count'],
          click_count: offer_row['click_count'],
          conversion_count: offer_row['conversion_count'],
          revenue_generated: offer_row['revenue_generated'],
          seller: {
            id: offer_row['seller_id'],
            name: offer_row['seller_name'] || offer_row['seller_fullname'],
            tier_id: offer_row['seller_tier_id'],
            tier_name: offer_row['seller_tier_name']
          },
          ads: ads.map do |ad_row|
            {
              id: ad_row['id'],
              title: ad_row['title'],
              price: ad_row['price'],
              original_price: ad_row['original_price'],
              discounted_price: ad_row['discounted_price'],
              discount_percentage: ad_row['discount_percentage'],
              media: ad_row['media'],
              created_at: ad_row['created_at'],
              category_name: ad_row['category_name'],
              subcategory_name: ad_row['subcategory_name'],
              seller_name: ad_row['seller_name'],
              seller_tier_id: ad_row['seller_tier_id'],
              seller_tier_name: ad_row['seller_tier_name'],
              review_count: ad_row['review_count'],
              avg_rating: ad_row['avg_rating']
            }
          end
        }
      end

      total_pages = (total_count.to_f / per_page).ceil

      render json: {
        offers: offers,
        pagination: {
          current_page: page,
          per_page: per_page,
          total_pages: total_pages,
          total_count: total_count,
          has_next_page: page < total_pages,
          has_prev_page: page > 1,
          next_page: page < total_pages ? page + 1 : nil,
          prev_page: page > 1 ? page - 1 : nil
        }
      }
    else
      # No offers found
      render json: {
        offers: [],
        pagination: {
          current_page: page,
          per_page: per_page,
          total_pages: 0,
          total_count: 0,
          has_next_page: false,
          has_prev_page: false,
          next_page: nil,
          prev_page: nil
        }
      }
    end
  end
  
  # GET /buyer/offers/:id
  def show
    @offer = Offer.find(params[:id])
    
    # Track view
    @offer.increment_view_count!
    
    render json: OfferSerializer.new(@offer).as_json
  end
  
  # GET /buyer/offers/active
  # OPTIMIZED: Used for homepage deals display
  def active_offers
    # OPTIMIZATION: Use raw SQL for better performance
    sql = <<-SQL
      SELECT
        offers.id,
        offers.name,
        offers.description,
        offers.offer_type,
        offers.discount_type,
        offers.discount_percentage,
        offers.fixed_discount_amount,
        offers.start_time,
        offers.end_time,
        offers.featured,
        offers.priority,
        offers.banner_color,
        offers.badge_color,
        offers.icon_name,
        offers.badge_text,
        offers.cta_text,
        offers.view_count,
        offers.click_count,
        sellers.id as seller_id,
        sellers.enterprise_name as seller_name,
        sellers.fullname as seller_fullname,
        tiers.id as seller_tier_id,
        tiers.name as seller_tier_name,
        COUNT(offer_ads.id) as ads_count
      FROM offers
      INNER JOIN sellers ON sellers.id = offers.seller_id
      LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id
      LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id
      LEFT JOIN offer_ads ON offer_ads.offer_id = offers.id
      WHERE offers.status = 'active'
        AND offers.start_time <= ?
        AND offers.end_time >= ?
        AND offers.show_on_homepage = true
        AND offers.featured = true
        AND sellers.blocked = false
        AND sellers.deleted = false
        AND sellers.flagged = false
      GROUP BY offers.id, sellers.id, seller_tiers.id, tiers.id
      ORDER BY offers.priority DESC, offers.created_at DESC
      LIMIT 5
    SQL

    offers_data = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, Time.current, Time.current])
    )

    # OPTIMIZATION: Build optimized response structure
    offers = offers_data.map do |row|
      {
        id: row['id'],
        name: row['name'],
        description: row['description'],
        offer_type: row['offer_type'],
        discount_type: row['discount_type'],
        discount_percentage: row['discount_percentage'],
        fixed_discount_amount: row['fixed_discount_amount'],
        start_time: row['start_time'],
        end_time: row['end_time'],
        featured: row['featured'],
        priority: row['priority'],
        banner_color: row['banner_color'],
        badge_color: row['badge_color'],
        icon_name: row['icon_name'],
        badge_text: row['badge_text'],
        cta_text: row['cta_text'],
        view_count: row['view_count'],
        click_count: row['click_count'],
        seller: {
          id: row['seller_id'],
          name: row['seller_name'] || row['seller_fullname'],
          tier_id: row['seller_tier_id'],
          tier_name: row['seller_tier_name']
        },
        ads_count: row['ads_count']
      }
    end

    render json: offers
  end

  # GET /buyer/offers/featured
  # OPTIMIZED: Used for featured deals display
  def featured_offers
    # OPTIMIZATION: Use raw SQL for better performance
    sql = <<-SQL
      SELECT
        offers.id,
        offers.name,
        offers.description,
        offers.offer_type,
        offers.discount_type,
        offers.discount_percentage,
        offers.fixed_discount_amount,
        offers.start_time,
        offers.end_time,
        offers.featured,
        offers.priority,
        offers.banner_color,
        offers.badge_color,
        offers.icon_name,
        offers.badge_text,
        offers.cta_text,
        offers.view_count,
        offers.click_count,
        sellers.id as seller_id,
        sellers.enterprise_name as seller_name,
        sellers.fullname as seller_fullname,
        tiers.id as seller_tier_id,
        tiers.name as seller_tier_name,
        COUNT(offer_ads.id) as ads_count
      FROM offers
      INNER JOIN sellers ON sellers.id = offers.seller_id
      LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id
      LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id
      LEFT JOIN offer_ads ON offer_ads.offer_id = offers.id
      WHERE offers.status = 'active'
        AND offers.start_time <= ?
        AND offers.end_time >= ?
        AND offers.featured = true
        AND sellers.blocked = false
        AND sellers.deleted = false
        AND sellers.flagged = false
      GROUP BY offers.id, sellers.id, seller_tiers.id, tiers.id
      ORDER BY offers.priority DESC, offers.created_at DESC
      LIMIT 10
    SQL

    offers_data = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, Time.current, Time.current])
    )

    # OPTIMIZATION: Build optimized response structure
    offers = offers_data.map do |row|
      {
        id: row['id'],
        name: row['name'],
        description: row['description'],
        offer_type: row['offer_type'],
        discount_type: row['discount_type'],
        discount_percentage: row['discount_percentage'],
        fixed_discount_amount: row['fixed_discount_amount'],
        start_time: row['start_time'],
        end_time: row['end_time'],
        featured: row['featured'],
        priority: row['priority'],
        banner_color: row['banner_color'],
        badge_color: row['badge_color'],
        icon_name: row['icon_name'],
        badge_text: row['badge_text'],
        cta_text: row['cta_text'],
        view_count: row['view_count'],
        click_count: row['click_count'],
        seller: {
          id: row['seller_id'],
          name: row['seller_name'] || row['seller_fullname'],
          tier_id: row['seller_tier_id'],
          tier_name: row['seller_tier_name']
        },
        ads_count: row['ads_count']
      }
    end

    render json: offers
  end
  
  # GET /buyer/offers/upcoming
  def upcoming_offers
    @offers = Offer.upcoming
                   .joins(:seller)
                   .where(sellers: { blocked: false, deleted: false, flagged: false })
                   .homepage_visible
                   .by_priority
                   .limit(5)
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/by_type/:type
  def by_type
    offer_type = params[:type]
    
    unless Offer.offer_types.key?(offer_type)
      render json: { error: 'Invalid offer type' }, status: :bad_request
      return
    end
    
    @offers = Offer.active_now
                   .joins(:seller)
                   .where(sellers: { blocked: false, deleted: false, flagged: false })
                   .where(offer_type: offer_type)
                   .homepage_visible
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # POST /buyer/offers/:id/click
  def track_click
    @offer = Offer.find(params[:id])
    @offer.increment_click_count!
    
    render json: { message: 'Click tracked successfully' }
  end
  
  # GET /buyer/offers/black-friday
  def black_friday
    @offers = Offer.active_now
                   .joins(:seller)
                   .where(sellers: { blocked: false, deleted: false, flagged: false })
                   .where(offer_type: 'black_friday')
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/cyber-monday
  def cyber_monday
    @offers = Offer.active_now
                   .joins(:seller)
                   .where(sellers: { blocked: false, deleted: false, flagged: false })
                   .where(offer_type: 'cyber_monday')
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/flash-sales
  def flash_sales
    @offers = Offer.active_now
                   .joins(:seller)
                   .where(sellers: { blocked: false, deleted: false, flagged: false })
                   .where(offer_type: 'flash_sale')
                   .includes(:seller, :offer_ads, ads: [:category, :subcategory, :reviews, seller: :seller_tier])
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/clearance
  def clearance
    @offers = Offer.active_now
                   .joins(:seller)
                   .where(sellers: { blocked: false, deleted: false, flagged: false })
                   .where(offer_type: 'clearance')
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/seasonal
  def seasonal
    @offers = Offer.active_now
                   .joins(:seller)
                   .where(sellers: { blocked: false, deleted: false, flagged: false })
                   .where(offer_type: 'seasonal')
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/holiday
  def holiday
    @offers = Offer.active_now
                   .joins(:seller)
                   .where(sellers: { blocked: false, deleted: false, flagged: false })
                   .where(offer_type: 'holiday')
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  # GET /buyer/offers/calendar
  def calendar
    start_date = params[:start_date] || Date.current.beginning_of_month
    end_date = params[:end_date] || Date.current.end_of_month
    
    @offers = Offer.where(
      'start_time >= ? AND end_time <= ?', 
      start_date, 
      end_date
    ).order(:start_time)
    
    calendar_data = @offers.map do |offer|
      {
        id: offer.id,
        title: offer.name,
        start: offer.start_time,
        end: offer.end_time,
        type: offer.offer_type,
        status: offer.status,
        color: offer.banner_color,
        featured: offer.featured
      }
    end
    
    render json: calendar_data
  end
  
  # GET /buyer/offers/search
  def search
    query = params[:q]
    return render json: { offers: [] } if query.blank?
    
    @offers = Offer.active_now
                   .joins(:seller)
                   .where(sellers: { blocked: false, deleted: false, flagged: false })
                   .where(
                     'name ILIKE ? OR description ILIKE ? OR badge_text ILIKE ?', 
                     "%#{query}%", 
                     "%#{query}%",
                     "%#{query}%"
                   )
                   .by_priority
    
    render json: @offers.map { |offer| OfferSerializer.new(offer).as_json }
  end
  
  private
  
  def authenticate_buyer
    # Implement buyer authentication
    # This should check if the current user is a buyer
  end
end
