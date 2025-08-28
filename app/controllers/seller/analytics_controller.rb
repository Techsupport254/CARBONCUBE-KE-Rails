class Seller::AnalyticsController < ApplicationController
  before_action :authenticate_seller

  def index
    # Get seller's tier_id
    tier_id = current_seller.seller_tier&.tier_id


    # Prepare the response based on the seller's tier
    response_data = {
      tier_id: tier_id, # Include tier_id in the response
      total_orders: calculate_total_orders,
      total_ads: calculate_total_ads
    }

    # Add more data based on the seller's tier
    case tier_id
    when 1 # Free tier
      response_data.merge!(calculate_free_tier_data)
    when 2 # Basic tier
      response_data.merge!(calculate_basic_tier_data)
    when 3 # Standard tier
      response_data.merge!(calculate_standard_tier_data)
      response_data.merge!(click_events_stats: top_click_event_stats)
    when 4 # Premium tier
      response_data.merge!(calculate_premium_tier_data)
      response_data.merge!(
        wishlist_stats: top_wishlist_stats,
        basic_wishlist_stats: basic_wishlist_stats,
        competitor_stats: calculate_competitor_stats,
        click_events_stats: top_click_event_stats
      )
    else
      render json: { error: 'Invalid tier' }, status: 400
      return
    end

    render json: response_data
  end





  private





  # Data for Free tier
  def calculate_free_tier_data
    {
      total_orders: calculate_total_orders,
      total_ads: calculate_total_ads,
      average_rating: calculate_average_rating
    }
  end

  # Data for Basic tier
  def calculate_basic_tier_data
    {
      total_revenue: calculate_total_revenue
    }
  end

  # Data for Standard tier
  def calculate_standard_tier_data
    {
      total_revenue: calculate_total_revenue,
      total_reviews: calculate_total_reviews,
      sales_performance: calculate_sales_performance,
      best_selling_ads: fetch_best_selling_ads
    }
  end

  # Data for Premium tier
  def calculate_premium_tier_data
    {
      total_revenue: calculate_total_revenue,
      average_rating: calculate_average_rating,
      total_reviews: calculate_total_reviews,
      sales_performance: calculate_sales_performance,
      best_selling_ads: fetch_best_selling_ads,
      wishlist_stats: top_wishlist_stats, # Merge wishlist stats into the response
      click_events_stats: top_click_event_stats,
      basic_wishlist_stats: basic_wishlist_stats,
      basic_click_event_stats: basic_click_event_stats
    }
  end

#================================================= COMBINE ALL WISHLIST STATS =================================================#
  def top_wishlist_stats
    stats = {
      top_age_group: top_age_group,
      top_income_range: top_income_range,
      top_education_level: top_education_level,
      top_employment_status: top_employment_status,
      top_sector: top_sector
    }

    # Rails.logger.info "Final Wishlist Stats: #{stats}"
    stats
  end

  def basic_wishlist_stats
    {
      wishlist_trends: wishlist_trends,
      top_wishlisted_ads: top_wishlisted_ads
    }
  end


#================================================= COMBINE ALL TOP CLICK EVENT STATS =================================================#
  def top_click_event_stats
    stats = {
      top_age_group_clicks: top_clicks_by_age,
      top_income_range_clicks: top_clicks_by_income,
      top_education_level_clicks: top_clicks_by_education,
      top_employment_status_clicks: top_clicks_by_employment,
      top_sector_clicks: top_clicks_by_sector
    }

    # Rails.logger.info "Final Click Events Stats: #{stats}"
    stats
  end

  def basic_click_event_stats
    {
      click_event_trends: click_event_trends
    }
  end

#================================================= CLICK EVENTS PURCHASER DEMOGRAPHICS =================================================#

  # Group clicks by age groups
  def group_clicks_by_age
    clicks = ClickEvent.joins(buyer: :age_group)
                      .includes(:ad)
                      .where(ads: { seller_id: current_seller.id })
                      .group('age_groups.name', :event_type)
                      .count

    clicks.transform_keys do |(age_group_name, event_type)|
      { age_group: age_group_name, event_type: event_type }
    end
  end

  # Group clicks by income ranges
  def group_clicks_by_income
    ClickEvent.joins(ad: {}, buyer: :income)
              .where(ads: { seller_id: current_seller.id })
              .group("incomes.range", :event_type)
              .count
              .transform_keys { |k| { income_range: k[0], event_type: k[1] } }
  end

  # Group clicks by education levels
  def group_clicks_by_education
    ClickEvent.joins(ad: {}, buyer: :education)
              .where(ads: { seller_id: current_seller.id })
              .group("educations.level", :event_type)
              .count
              .transform_keys { |k| { education_level: k[0], event_type: k[1] } }
  end

  # Group clicks by employment statuses
  def group_clicks_by_employment
    ClickEvent.joins(ad: {}, buyer: :employment)
              .where(ads: { seller_id: current_seller.id })
              .group("employments.status", :event_type)
              .count
              .transform_keys { |k| { employment_status: k[0], event_type: k[1] } }
  end

  # Group clicks by sectors
  def group_clicks_by_sector
    ClickEvent.joins(ad: {}, buyer: :sector)
              .where(ads: { seller_id: current_seller.id })
              .group("sectors.name", :event_type)
              .count
              .transform_keys { |k| { sector: k[0], event_type: k[1] } }
  end

  def click_event_trends
    # Define the date range: the current month and the previous 4 months
    end_date = Date.today.end_of_month
    start_date = (end_date - 4.months).beginning_of_month

    # Step 1: Find all ad IDs that belong to the current seller
    ad_ids = Ad.where(seller_id: current_seller.id).pluck(:id)
    # Rails.logger.info("Ad IDs for Seller #{current_seller.id}: #{ad_ids.inspect}")

    if ad_ids.empty?
      # Rails.logger.warn("No Ads found for Seller #{current_seller.id}")
      return (0..4).map do |i|
        month_date = end_date - i.months
        {
          month: month_date.strftime('%B %Y'),
          ad_clicks: 0,
          add_to_wish_list: 0,
          reveal_seller_details: 0
        }
      end.reverse
    end

    # Step 2: Query the click events for those ads within the date range
    click_events = ClickEvent.where(ad_id: ad_ids)
                             .where('created_at BETWEEN ? AND ?', start_date, end_date)
                             .group("DATE_TRUNC('month', created_at)", :event_type)
                             .count

    # Rails.logger.info("Click Events Grouped by Month and Event Type: #{click_events.inspect}")

    # Step 3: Build the monthly data for the past 5 months
    monthly_click_events = (0..4).map do |i|
      month_date = (end_date - i.months).beginning_of_month

      # Ensure key structure matches expected format
      ad_clicks = click_events.select { |(date, event), _| date && date.to_date == month_date.to_date && event == 'Ad-Click' }.values.sum || 0
      add_to_wish_list = click_events.select { |(date, event), _| date && date.to_date == month_date.to_date && event == 'Add-to-Wish-List' }.values.sum || 0
      reveal_seller_details = click_events.select { |(date, event), _| date && date.to_date == month_date.to_date && event == 'Reveal-Seller-Details' }.values.sum || 0

      {
        month: month_date.strftime('%B %Y'), # Format: "Month Year"
        ad_clicks: ad_clicks,
        add_to_wish_list: add_to_wish_list,
        reveal_seller_details: reveal_seller_details
      }
    end.reverse

    # Debugging output
    # Rails.logger.info("Click Event Trends for Seller #{current_seller.id}: #{monthly_click_events.inspect}")

    # Return the result for the frontend
    monthly_click_events
  end

  #================================================= TOP CLICK EVENTS BY PURCHASER DEMOGRAPHICS =================================================#

  # Get the age group with the highest click events
  def top_clicks_by_age
    clicks = group_clicks_by_age
    # Rails.logger.info "Age Group Click Distribution: #{clicks}"

    result = get_top_clicks(clicks, :age_group)
    # Rails.logger.info "Top Age Group Clicks: #{result}"
    result
  end

  # Get the income range with the highest click events
  def top_clicks_by_income
    clicks = group_clicks_by_income
    # Rails.logger.info "Income Range Click Distribution: #{clicks}"

    result = get_top_clicks(clicks, :income_range)
    # Rails.logger.info "Top Income Clicks: #{result}"
    result
  end

  # Get the education level with the highest click events
  def top_clicks_by_education
    clicks = group_clicks_by_education
    # Rails.logger.info "Education Click Distribution: #{clicks}"

    result = get_top_clicks(clicks, :education_level)
    # Rails.logger.info "Top Education Clicks: #{result}"
    result
  end

  # Get the employment status with the highest click events
  def top_clicks_by_employment
    clicks = group_clicks_by_employment
    # Rails.logger.info "Employment Status Click Distribution: #{clicks}"

    result = get_top_clicks(clicks, :employment_status)
    # Rails.logger.info "Top Employment Clicks: #{result}"
    result
  end

  # Get the sector with the highest click events
  def top_clicks_by_sector
    clicks = group_clicks_by_sector
    # Rails.logger.info "Sector Click Distribution: #{clicks}"

    result = get_top_clicks(clicks, :sector)
    # Rails.logger.info "Top Sector Clicks: #{result}"
    result
  end



#================================================= HELPER METHOD FOR GETTING TOP CLICKS =================================================#

  def get_top_clicks(clicks, group_key)
    top_ad_click = clicks.select { |k, _| k[:event_type] == 'Ad-Click' }.max_by { |_, count| count }
    top_wishlist = clicks.select { |k, _| k[:event_type] == 'Add-to-Wish-List' }.max_by { |_, count| count }
    top_reveal = clicks.select { |k, _| k[:event_type] == 'Reveal-Seller-Details' }.max_by { |_, count| count }

    {
      top_ad_click: top_ad_click ? { group_key => top_ad_click[0][group_key], clicks: top_ad_click[1] } : nil,
      top_wishlist: top_wishlist ? { group_key => top_wishlist[0][group_key], clicks: top_wishlist[1] } : nil,
      top_reveal: top_reveal ? { group_key => top_reveal[0][group_key], clicks: top_reveal[1] } : nil
    }
  end




#================================================= WISHLISTS PURCHASER DEMOGRAPHICS =================================================#
  # Get the age group with the highest wishlists
  def top_age_group
    age_group_counts = Buyer.joins(:wish_lists)
                                .where(wish_lists: { ad_id: seller_ad_ids })
                                .group(:age_group_id)
                                .count

    top_group_id, count = age_group_counts.max_by { |_, c| c }

    if top_group_id
      age_group = AgeGroup.find_by(id: top_group_id)
      {
        age_group: age_group&.name || 'Unknown',
        count: count
      }
    else
      nil
    end
  end


  # Get the income range with the highest wishlists
  def top_income_range
    data = WishList.joins(:ad, buyer: :income)
                  .joins("INNER JOIN ads ON wish_lists.ad_id = ads.id")
                  .where(ads: { seller_id: current_seller.id })
                  .group("incomes.range")
                  .count
    
    # Rails.logger.info "Income Range Wishlist Distribution: #{data}"

    group = data.max_by { |_, count| count }

    result = group ? { income_range: group[0], wishlists: group[1] } : nil
    # Rails.logger.info "Top Income Range: #{result}"
    
    result
  end

  # Get the education level with the highest wishlists
  def top_education_level
    data = WishList.joins(:ad, buyer: :education)
                  .joins("INNER JOIN ads ON wish_lists.ad_id = ads.id")
                  .where(ads: { seller_id: current_seller.id })
                  .group("educations.level")
                  .count

    # Rails.logger.info "Education Level Wishlist Distribution: #{data}"

    group = data.max_by { |_, count| count }

    result = group ? { education_level: group[0], wishlists: group[1] } : nil
    # Rails.logger.info "Top Education Level: #{result}"
    
    result
  end

  # Get the employment status with the highest wishlists
  def top_employment_status
    data = WishList.joins(:ad, buyer: :employment)
                  .joins("INNER JOIN ads ON wish_lists.ad_id = ads.id")
                  .where(ads: { seller_id: current_seller.id })
                  .group("employments.status")
                  .count

    # Rails.logger.info "Employment Status Wishlist Distribution: #{data}"

    group = data.max_by { |_, count| count }

    result = group ? { employment_status: group[0], wishlists: group[1] } : nil
    # Rails.logger.info "Top Employment Status: #{result}"
    
    result
  end

  # Get the sector with the highest wishlists
  def top_sector
    data = WishList.joins(:ad, buyer: :sector)
                  .joins("INNER JOIN ads ON wish_lists.ad_id = ads.id")
                  .where(ads: { seller_id: current_seller.id })
                  .group("sectors.name")
                  .count

    # Rails.logger.info "Sector Wishlist Distribution: #{data}"

    group = data.max_by { |_, count| count }

    result = group ? { sector: group[0], wishlists: group[1] } : nil
    # Rails.logger.info "Top Sector: #{result}"
    
    result
  end

  def top_wishlisted_ads
    begin
      WishList.joins(:ad)
              .where(ads: { seller_id: current_seller.id })
              .group('ads.id', 'ads.title', 'ads.media', 'ads.price')
              .select('ads.title AS ad_title, COUNT(wish_lists.id) AS wishlist_count, ads.media AS ad_media, ads.price AS ad_price')
              .order('wishlist_count DESC')
              .limit(3)
              .map do |record|
                {
                  ad_title: record.ad_title,
                  wishlist_count: record.wishlist_count,
                  ad_media: JSON.parse(record.ad_media || '[]'), # Parse media as an array
                  ad_price: record.ad_price
                }
              end
    rescue StandardError
      []
    end
  end
  

  def wishlist_trends
    # Define the date range: the current month and the previous 4 months
    end_date = Date.today.end_of_month
    start_date = (end_date - 4.months).beginning_of_month
  
    # Step 1: Find all ad IDs that belong to the current seller
    ad_ids = Ad.where(seller_id: current_seller.id).pluck(:id)
    # Rails.logger.info("Ad IDs for Seller #{current_seller.id}: #{ad_ids.inspect}")
  
    if ad_ids.empty?
      # Rails.logger.warn("No Ads found for Seller #{current_seller.id}")
      return (0..4).map do |i|
        month_date = end_date - i.months
        {
          month: month_date.strftime('%B %Y'),
          wishlist_count: 0
        }
      end.reverse
    end
  
    # Step 2: Query the wishlists for those ads within the date range
    wishlist_counts = WishList.where(ad_id: ad_ids)
                              .where('created_at BETWEEN ? AND ?', start_date, end_date)
                              .group("DATE_TRUNC('month', created_at)")
                              .count
    # Rails.logger.info("Wishlist Counts Grouped by Month: #{wishlist_counts.inspect}")
  
    # Step 3: Build the monthly data for the past 5 months
    monthly_wishlist_counts = (0..4).map do |i|
      month_date = (end_date - i.months).beginning_of_month
      wishlist_count = wishlist_counts.find { |key, _| key.to_date == month_date.to_date }&.last || 0
  
      {
        month: month_date.strftime('%B %Y'), # Format: "Month Year"
        wishlist_count: wishlist_count
      }
    end.reverse
  
    # Debugging output
    # Rails.logger.info("Wishlist Trends for Seller #{current_seller.id}: #{monthly_wishlist_counts.inspect}")
  
    # Return the result for the frontend
    monthly_wishlist_counts
  end



  #================================================= COMPETITOR STATS =================================================#
  # Competitor Stats
  def calculate_competitor_stats
    category_id = current_seller.ads.select(:category_id).distinct.pluck(:category_id).first
    return [] unless category_id

    {
      revenue_share: calculate_revenue_share(category_id),
      top_competitor_ads: fetch_top_competitor_ads(category_id),
      competitor_average_price: calculate_competitor_average_price(category_id)
    }
  end

  def calculate_revenue_share(category_id)
    total_category_revenue = Seller.joins(ads: { order_items: :order })
                                    .where(ads: { category_id: category_id })
                                    .sum('order_items.quantity * ads.price')
    seller_revenue = calculate_total_revenue

    { seller_revenue: seller_revenue, total_category_revenue: total_category_revenue, revenue_share: ((seller_revenue / total_category_revenue.to_f) * 100).round(2) }
  end

  def fetch_top_competitor_ads(category_id)
    Seller.joins(ads: :wish_lists)
          .where(ads: { category_id: category_id })
          .where.not(id: current_seller.id)
          .select('ads.id AS ad_id, ads.title AS ad_title, COUNT(wish_lists.id) AS total_wishlists, ads.price AS ad_price, ads.media AS ad_media')
          .group('ads.id')
          .order('total_wishlists DESC')
          .limit(3)
          .map { |record| 
            { 
              ad_id: record.ad_id,
              ad_title: record.ad_title,
              total_wishlists: record.total_wishlists,
              ad_price: record.ad_price,
              ad_media: JSON.parse(record.ad_media || '[]') # Parse the media as an array
            } 
          }
  end  
  

  def calculate_competitor_average_price(category_id)
    Seller.joins(:ads)
          .where(ads: { category_id: category_id })
          .where.not(id: current_seller.id)
          .average('ads.price')
          .to_f.round(2)
  end  




  #===================================== HELPER METHODS =================================================#
  def calculate_total_orders
    current_seller.orders.count
  end

  def calculate_total_revenue
    current_seller.orders.joins(order_items: :ad).sum('order_items.quantity * ads.price')
  end

  def calculate_total_ads
    current_seller.ads.count
  end

  def seller_ad_ids
    current_seller.ads.pluck(:id)
  end

  def calculate_average_rating
    current_seller.ads.joins(:reviews).average(:rating).to_f.round(1)
  end

  def calculate_total_reviews
    current_seller.reviews.count
  end

  def calculate_sales_performance
    current_month = Date.current.beginning_of_month
    three_months_ago = 3.months.ago.beginning_of_month

    sales_performance = current_seller.orders.joins(:order_items)
                            .where(created_at: three_months_ago..current_month.end_of_month)
                            .group("DATE_TRUNC('month', orders.created_at)")
                            .sum('order_items.quantity * order_items.price')
                            .transform_keys { |k| k.strftime("%B %Y") }
    sales_performance
  end

  def fetch_best_selling_ads
    current_seller.ads.joins(:order_items)
                      .select('ads.id AS ad_id, ads.title AS ad_title, ads.price AS ad_price, SUM(order_items.quantity) AS total_sold, ads.media AS media')
                      .group('ads.id')
                      .order('total_sold DESC')
                      .limit(3)
                      .map { |record| 
                        {
                          ad_id: record.ad_id,
                          ad_title: record.ad_title,
                          ad_price: record.ad_price,
                          total_sold: record.total_sold,
                          media: record.media
                        }
                      }
  end

  def authenticate_seller
    @current_user = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: 401
    end
  end

  def current_seller
    @current_user
  end
end