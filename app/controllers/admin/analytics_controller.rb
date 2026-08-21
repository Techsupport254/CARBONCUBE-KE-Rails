class Admin::AnalyticsController < ApplicationController
  before_action :authenticate_admin

  def index
    @total_sellers = Seller.where(deleted:false).count
    @total_buyers = Buyer.where(deleted:false).count
    
    @total_ads = Ad.count
    @total_reviews = Review.count

    # Top 6 Most Wish-Listed Ads Overall
    wishlist_counts = WishList.group(:ad_id).count
    top_wishlisted_ad_ids = wishlist_counts.sort_by { |_, c| -c }.first(24).map(&:first)
    top_wishlisted_ads = Ad.where(id: top_wishlisted_ad_ids).map do |ad|
      {
        ad_id: ad.id,
        ad_title: ad.title,
        ad_price: ad.price,
        wishlist_count: wishlist_counts[ad.id] || 0,
        media: ad.media
      }
    end
    top_wishlisted_ads = top_wishlisted_ads.sort_by { |ad| -ad[:wishlist_count] }

    # Total Ads Wish-Listed
    total_ads_wish_listed = WishList.count

#=============================================================PURCHASER INSIGHTS=============================================================#

    # Get selected metric from query parameter, default to 'Total Click Events' if none provided
    selected_metric = params[:metric] || 'Total Wishlists'

    # Calculate buyer total wishlists
    buyers_by_wishlists = Buyer.joins(:wish_lists)
                              .select('buyers.id AS buyer_id, buyers.fullname, buyers.email, buyers.profile_picture, COUNT(wish_lists.id) AS total_wishlists')
                              .group('buyers.id, buyers.profile_picture')
                              .order('total_wishlists DESC')

    # Calculate buyer total click events (sum of all click types)
    buyers_by_clicks = Buyer.joins(:click_events)
                              .select('buyers.id AS buyer_id, buyers.fullname, buyers.email, buyers.profile_picture, COUNT(click_events.id) AS total_clicks')
                              .group('buyers.id, buyers.profile_picture')
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
                        .select('sellers.id, sellers.fullname, sellers.email, sellers.enterprise_name, sellers.profile_picture, COALESCE(AVG(reviews.rating), 0) AS mean_rating')
                        .group('sellers.id, sellers.profile_picture')
                        .order('mean_rating DESC')

    # Calculate seller total ads
    sellers_by_ads = Seller.joins(:ads)
                        .select('sellers.id, sellers.fullname, sellers.email, sellers.enterprise_name, sellers.profile_picture, COUNT(ads.id) AS total_ads')
                        .group('sellers.id, sellers.profile_picture')
                        .order('total_ads DESC')

    # Calculate seller total reveal clicks
    sellers_by_reveal_clicks = Seller.joins(ads: :click_events)
                        .where(click_events: { event_type: 'Reveal-Seller-Details' })
                        .select('sellers.id, sellers.fullname, sellers.email, sellers.enterprise_name, sellers.profile_picture, COUNT(click_events.id) AS reveal_clicks')
                        .group('sellers.id, sellers.profile_picture')
                        .order('reveal_clicks DESC')

    # Calculate seller total ad clicks
    sellers_by_ad_clicks = Seller.joins(ads: :click_events)
                        .where(click_events: { event_type: 'Ad-Click' })
                        .select('sellers.id, sellers.fullname, sellers.email, sellers.enterprise_name, sellers.profile_picture, COUNT(click_events.id) AS total_ad_clicks')
                        .group('sellers.id, sellers.profile_picture')
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
    # total_revenue = PaymentTransaction.where(status: 'completed').sum(:amount)

    # Sales Performance (example: revenue by month)
    # Sales Performance for the last 3 months
    current_month = Date.current.beginning_of_month
    three_months_ago = 2.months.ago.beginning_of_month

    sales_performance = PaymentTransaction.where(status: 'completed')
                        .where(created_at: three_months_ago..current_month.end_of_month)
                        .group("DATE_TRUNC('month', payment_transactions.created_at)")
                        .sum(:amount)
                        .transform_keys { |k| k.strftime("%B %Y") }

#===============================================================CATEGORY ANALYTICS===============================================================#

    # Count the number of ads for each category (all categories, including 0 ads)
    all_category_ads = Category.left_joins(:ads)
                      .select('categories.id, categories.name AS category_name, COUNT(ads.id) AS total_ads')
                      .group('categories.id')
                      .order('total_ads DESC')

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

    # Seller counts per category
    category_sellers = Category.joins(ads: :seller)
                        .where(ads: { deleted: false })
                        .select('categories.name AS category_name, COUNT(DISTINCT sellers.id) AS total_sellers')
                        .group('categories.id')
                        .map { |record| { category_name: record.category_name, total_sellers: record.total_sellers } }

    # Build full category breakdown with ads, clicks, reveals, wishlists and sellers
    ads_per_category = all_category_ads.map do |record|
      clicks = category_click_events.find { |c| c[:category_name] == record.category_name } || {}
      wishlists = category_wishlist_data.find { |c| c[:category_name] == record.category_name } || {}
      sellers = category_sellers.find { |c| c[:category_name] == record.category_name } || {}
      {
        category_name: record.category_name,
        total_sellers: sellers[:total_sellers].to_i,
        total_ads: record.total_ads.to_i,
        ad_clicks: clicks[:ad_clicks].to_i,
        wish_list_clicks: clicks[:wish_list_clicks].to_i,
        reveal_clicks: clicks[:reveal_clicks].to_i,
        total_wishlists: wishlists[:total_wishlists].to_i,
        wishlist_percentage: wishlists[:wishlist_percentage].to_f
      }
    end

    # Subcategory breakdowns (ads, clicks, reveals, wishlists)
    all_subcategory_ads = Subcategory.joins(:category)
                          .left_joins(:ads)
                          .select('subcategories.id, subcategories.name AS subcategory_name, subcategories.category_id, categories.name AS category_name, COUNT(ads.id) AS ads_count')
                          .group('subcategories.id, categories.name')
                          .order('ads_count DESC')

    subcategory_click_events = Subcategory.joins(:category, ads: :click_events)
                              .where(ads: { deleted: false })
                              .select('subcategories.id, subcategories.name AS subcategory_name, categories.name AS category_name,
                                      SUM(CASE WHEN click_events.event_type = \'Ad-Click\' THEN 1 ELSE 0 END) AS ad_clicks,
                                      SUM(CASE WHEN click_events.event_type = \'Add-to-Wish-List\' THEN 1 ELSE 0 END) AS wish_list_clicks,
                                      SUM(CASE WHEN click_events.event_type = \'Reveal-Seller-Details\' THEN 1 ELSE 0 END) AS reveal_clicks')
                              .group('subcategories.id, categories.name, subcategories.name')
                              .order('subcategory_name')

    subcategory_wishlists = Subcategory.joins(:category, ads: :wish_lists)
                            .where(ads: { deleted: false })
                            .select('subcategories.id, subcategories.name AS subcategory_name, categories.name AS category_name, COUNT(wish_lists.id) AS total_wishlists')
                            .group('subcategories.id, categories.name, subcategories.name')
                            .order('total_wishlists DESC')

    subcategory_breakdowns = all_subcategory_ads.map do |record|
      clicks = subcategory_click_events.find { |c| c[:subcategory_name] == record.subcategory_name && c[:category_name] == record.category_name } || {}
      wish = subcategory_wishlists.find { |c| c[:subcategory_name] == record.subcategory_name && c[:category_name] == record.category_name } || {}
      {
        subcategory_id: record.id,
        subcategory_name: record.subcategory_name,
        category_id: record.category_id,
        category_name: record.category_name,
        ads_count: record.ads_count.to_i,
        ad_clicks: clicks[:ad_clicks].to_i,
        wish_list_clicks: clicks[:wish_list_clicks].to_i,
        reveal_clicks: clicks[:reveal_clicks].to_i,
        total_wishlists: wish[:total_wishlists].to_i
      }
    end

    # Log the data for tracking purposes
    # Rails.logger.info "Fetched Category Wishlist Data: #{category_wishlist_data.inspect}"

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
      subcategory_breakdowns: subcategory_breakdowns,
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
