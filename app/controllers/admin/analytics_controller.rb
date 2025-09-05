class Admin::AnalyticsController < ApplicationController
  before_action :authenticate_admin

  def index
    @total_sellers = Seller.where(deleted:false).count
    @total_buyers = Buyer.where(deleted:false).count
    
    @total_ads = Ad.count
    @total_reviews = Review.count

    # Top 6 Most Wish-Listed Ads Overall
    top_wishlisted_ads = Ad.joins(:wish_lists)
                        .select('ads.id AS ad_id, ads.title AS ad_title, ads.price AS ad_price, COUNT(wish_lists.id) AS wishlist_count, ads.media AS media')
                        .group('ads.id')
                        .order('wishlist_count DESC')
                        .limit(6)
                        .map { |record| 
                          {
                            ad_id: record.ad_id,
                            ad_title: record.ad_title,
                            ad_price: record.ad_price,
                            wishlist_count: record.wishlist_count,
                            media: record.media
                          }
                        }

    # Total Ads Wish-Listed
    total_ads_wish_listed = WishList.count

#=============================================================PURCHASER INSIGHTS=============================================================#

    # Get selected metric from query parameter, default to 'Total Click Events' if none provided
    selected_metric = params[:metric] || 'Total Wishlists'

    # Calculate buyer total wishlists
    buyers_by_wishlists = Buyer.joins(:wish_lists)
                              .select('buyers.id AS buyer_id, buyers.fullname, COUNT(wish_lists.id) AS total_wishlists')
                              .group('buyers.id')
                              .order('total_wishlists DESC')

    # Calculate buyer total click events (sum of all click types)
    buyers_by_clicks = Buyer.joins(:click_events)
                              .select('buyers.id AS buyer_id, buyers.fullname, COUNT(click_events.id) AS total_clicks')
                              .group('buyers.id')
                              .order('total_clicks DESC')

    # Dynamically select the buyers' insights based on the metric
    buyers_insights = case selected_metric
      when 'Total Wishlists' then buyers_by_wishlists
      when 'Total Click Events' then buyers_by_clicks
      else buyers_by_clicks
    end.limit(10)

#=============================================================SELLER INSIGHTS=============================================================#

    # Get selected metric from query parameter, default to 'Rating' if none provided
    selected_metric = params[:metric] || 'Rating'

    # Calculate seller mean rating
    sellers_by_rating = Seller.joins(ads: :reviews)
                        .select('sellers.id, sellers.fullname, COALESCE(AVG(reviews.rating), 0) AS mean_rating')
                        .group('sellers.id')
                        .order('mean_rating DESC')

    # Calculate seller total ads
    sellers_by_ads = Seller.joins(:ads)
                        .select('sellers.id, sellers.fullname, COUNT(ads.id) AS total_ads')
                        .group('sellers.id')
                        .order('total_ads DESC')

    # Calculate seller total reveal clicks
    sellers_by_reveal_clicks = Seller.joins(ads: :click_events)
                        .where(click_events: { event_type: 'Reveal-Seller-Details' })
                        .select('sellers.id, sellers.fullname, COUNT(click_events.id) AS reveal_clicks')
                        .group('sellers.id')
                        .order('reveal_clicks DESC')

    # Calculate seller total ad clicks
    sellers_by_ad_clicks = Seller.joins(ads: :click_events)
                        .where(click_events: { event_type: 'Ad-Click' })
                        .select('sellers.id, sellers.fullname, COUNT(click_events.id) AS total_ad_clicks')
                        .group('sellers.id')
                        .order('total_ad_clicks DESC')

    # Dynamically select the sellers' insights based on the metric
    sellers_insights = case selected_metric
      when 'Rating' then sellers_by_rating
      when 'Total Ads' then sellers_by_ads
      when 'Reveal Clicks' then sellers_by_reveal_clicks
      when 'Ad Clicks' then sellers_by_ad_clicks
      else sellers_by_rating
    end.limit(10)

    # # Total Revenue
    # total_revenue = Order.sum(:total_amount)

    # Sales Performance (example: revenue by month)
    # Sales Performance for the last 3 months
    current_month = Date.current.beginning_of_month
    three_months_ago = 2.months.ago.beginning_of_month

    sales_performance = Order.joins(:order_items)
                        .where(created_at: three_months_ago..current_month.end_of_month)
                        .group("DATE_TRUNC('month', orders.created_at)")
                        .sum('order_items.price * order_items.quantity')
                        .transform_keys { |k| k.strftime("%B %Y") }

#===============================================================CATEGORY ANALYTICS===============================================================#

    # Count the number of ads for each category
    ads_per_category = Category.joins(:ads)
                      .select('categories.name AS category_name, COUNT(ads.id) AS total_ads')
                      .group('categories.id')
                      .order('total_ads DESC')
                      .limit(4)
                      .map { |record| { category_name: record.category_name, total_ads: record.total_ads } }

    #Count of Click Events for each category
    category_click_events = Category.joins(ads: :click_events)
                            .where(ads: { deleted: false })
                            .select('categories.name AS category_name, 
                                    SUM(CASE WHEN click_events.event_type = \'Ad-Click\' THEN 1 ELSE 0 END) AS ad_clicks,
                                    SUM(CASE WHEN click_events.event_type = \'Add-to-Wish-List\' THEN 1 ELSE 0 END) AS wish_list_clicks,
                                    SUM(CASE WHEN click_events.event_type = \'Reveal-Seller-Details\' THEN 1 ELSE 0 END) AS reveal_clicks')
                            .group('categories.id')
                            .order('category_name')
                            .map { |record| 
                              {
                                category_name: record.category_name,
                                ad_clicks: record.ad_clicks,
                                wish_list_clicks: record.wish_list_clicks,
                                reveal_clicks: record.reveal_clicks
                              }
                            }

    # Log the data for tracking purposes
    # Rails.logger.info "Fetched Category Click Event Data: #{category_click_events.inspect}"
    # 
    category_wishlists = Category
      .joins(ads: :wish_lists)
      .where(ads: { deleted: false })
      .select('categories.id, categories.name, COUNT(wish_lists.id) AS total_wishlists')
      .group('categories.id, categories.name')
      .order('total_wishlists DESC')

    # Get total wishlists across all categories
    total_wishlists = category_wishlists.sum(&:total_wishlists)

    # Calculate percentage of wishlists per category
    category_wishlist_data = category_wishlists.map do |category|
      {
        category_id: category.id,
        category_name: category.name,
        total_wishlists: category.total_wishlists,
        wishlist_percentage: total_wishlists.zero? ? 0 : ((category.total_wishlists.to_f / total_wishlists) * 100).round(2)
      }
    end

    # Log the data for tracking purposes
    # Rails.logger.info "Fetched Category Wishlist Data: #{category_wishlist_data.inspect}"

    # Total number of orders by status
    statuses = ['Processing', 'Dispatched', 'In-Transit', 'Delivered', 'Cancelled', 'Returned']
    order_counts_by_status = statuses.map do |status|
      { name: status, count: Order.where(status: status).count }
    end

#===============================================================PURCHASER ANALYTICS===============================================================#

    buyer_age_groups = {
      '18-25' => 0,
      '26-35' => 0,
      '36-45' => 0,
      '46-55' => 0,
      '56-65' => 0,
      '65+'   => 0
    }

    Buyer.find_each do |buyer|
      case buyer.age_group_id
      when 1 then buyer_age_groups['18-25'] += 1
      when 2 then buyer_age_groups['26-35'] += 1
      when 3 then buyer_age_groups['36-45'] += 1
      when 4 then buyer_age_groups['46-55'] += 1
      when 5 then buyer_age_groups['56-65'] += 1
      when 6 then buyer_age_groups['65+']   += 1
      end
    end

    # Rails.logger.info "Buyer Age Groups Computed: #{buyer_age_groups}"

    # Gender Distribution
    gender_distribution = Buyer.group(:gender).count

    # Employment Breakdown
    employment_data = Employment.joins(:buyers)
                                      .select('employments.status, COUNT(buyers.id) AS total')
                                      .group('employments.status')

    # Income Distribution
    income_data = Income.joins(:buyers)
                            .select('incomes.range, COUNT(buyers.id) AS total')
                            .group('incomes.range')

    # Education Breakdown
    education_data = Education.joins(:buyers)
                                  .select('educations.level, COUNT(buyers.id) AS total')
                                  .group('educations.level')

    # Sector Breakdown
    sector_data = Sector.joins(:buyers)
                        .select('sectors.name, COUNT(buyers.id) AS total')
                        .group('sectors.name')

#================================================================SELLER DEMOGRAPHICS===============================================================#

    seller_age_groups = {
      '18-25' => 0,
      '26-35' => 0,
      '36-45' => 0,
      '46-55' => 0,
      '56-65' => 0,
      '65+'   => 0
    }

    Seller.find_each do |seller|
      case seller.age_group_id
      when 1 then seller_age_groups['18-25'] += 1
      when 2 then seller_age_groups['26-35'] += 1
      when 3 then seller_age_groups['36-45'] += 1
      when 4 then seller_age_groups['46-55'] += 1
      when 5 then seller_age_groups['56-65'] += 1
      when 6 then seller_age_groups['65+']   += 1
      end
    end

    # Rails.logger.info "Seller Age Groups Computed: #{seller_age_groups}"

    # Gender Distribution
    seller_gender_distribution = Seller.group(:gender).count
    # Rails.logger.info "Gender Distribution Computed: #{seller_gender_distribution}"

    # Seller Tier Breakdown
    # Corrected query
    tier_data = SellerTier.joins(:seller)
                .joins(:tier)
                .select('tiers.name AS tier_name, COUNT(seller_tiers.seller_id) AS total')
                .group('tiers.name')
                .as_json

    # Rails.logger.info "Seller Tier Data: #{tier_data}"

    # Seller Category Breakdown
    category_data = CategoriesSeller.joins(:seller)
                                .joins(:category)
                                .select('categories.name, COUNT(categories_sellers.seller_id) AS total')
                                .group('categories.name')
                                .as_json

    # Rails.logger.info "Seller Category Data: #{category_data}"


#================================================================RENDER SECTION===============================================================#

    render json: {
      total_sellers: @total_sellers,
      total_buyers: @total_buyers,
      total_ads: @total_ads,
      total_reviews: @total_reviews,
      top_wishlisted_ads: top_wishlisted_ads,
      total_ads_wish_listed: total_ads_wish_listed,
      buyers_insights: buyers_insights,
      sellers_insights: sellers_insights,
      sales_performance: sales_performance,
      ads_per_category: ads_per_category,
      order_counts_by_status: order_counts_by_status,
      category_click_events: category_click_events,
      category_wishlist_data: category_wishlist_data,
      buyer_age_groups: buyer_age_groups,
      seller_age_groups: seller_age_groups,
      gender_distribution: gender_distribution,
      employment_data: employment_data.map { |e| { e.status => e.total } },
      income_data: income_data.map { |i| { i.range => i.total } },
      education_data: education_data.map { |e| { e.level => e.total } },
      sector_data: sector_data.map { |s| { s.name => s.total } },
      seller_gender_distribution: seller_gender_distribution,
      tier_data: tier_data.map { |t| { t['tier_name'] => t['total'] } },
      category_data: category_data.map { |c| { c['name'] => c['total'] } }
    }
  end

  private

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_admin
    @current_user
  end
end
