class Admin::SellersController < ApplicationController
  before_action :authenticate_admin
  before_action :set_seller, only: [:block, :unblock, :show, :update, :destroy, :analytics, :orders, :ads, :reviews]

  def index
    if params[:search_query].present?
      @sellers = Seller.where("phone_number = :query OR id = :query", query: params[:search_query])
    else
      @sellers = Seller.all
    end
  
    render json: @sellers.as_json(only: [:id, :fullname, :phone_number, :email, :enterprise_name, :location, :blocked])
  end
  

  def show
    seller_data = @seller.as_json(
      only: [:id, :fullname, :phone_number, :email, :enterprise_name, :location, :blocked],
      methods: [:category_names]
    )
    analytics_data = fetch_analytics(@seller)
    seller_data.merge!(analytics: analytics_data)
    render json: seller_data
  end

  def create
    @seller = Seller.new(seller_params)
    if @seller.save
      render json: @seller.as_json(only: [:id, :fullname, :enterprise_name, :location, :blocked]), status: :created
    else
      render json: @seller.errors, status: :unprocessable_entity
    end
  end

  def update
    if @seller.update(seller_params)
      render json: @seller.as_json(only: [:id, :fullname, :phone_number, :email, :enterprise_name, :location, :blocked])
    else
      render json: @seller.errors, status: :unprocessable_entity
    end
  end

  def verify_document
    seller = Seller.find(params[:id])
    seller.update(document_verified: true)
    render json: { message: 'Seller document verified.' }, status: :ok
  end

  def destroy
    @seller.destroy
    head :no_content
  end

  def reviews
    reviews = @seller.reviews.joins(:ad, :buyer)
                           .where(ads: { id: @seller.ads.pluck(:id) })
                           .select('reviews.*, buyers.fullname AS buyer_name, ads.title AS ad_title')
    render json: reviews.as_json(only: [:id, :rating, :review, :created_at],
                                 methods: [:buyer_name, :ad_title])
  end
  

  def ads
    ads = @seller.ads
    render json: ads
  end

  def block
    if @seller
      mean_rating = @seller.reviews.average(:rating).to_f

      if mean_rating < 3.0
        if @seller.update(blocked: true)
          render json: @seller.as_json(only: [:id, :fullname, :enterprise_name, :location, :blocked]), status: :ok
        else
          render json: @seller.errors, status: :unprocessable_entity
        end
      else
        render json: { error: 'Seller cannot be blocked because their mean rating is above 3.0' }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Seller not found' }, status: :not_found
    end
  end

  def unblock
    if @seller
      if @seller.update(blocked: false)
        render json: @seller.as_json(only: [:id, :fullname, :enterprise_name, :location, :blocked]), status: :ok
      else
        render json: @seller.errors, status: :unprocessable_entity
      end
    else
      render json: { error: 'Seller not found' }, status: :not_found
    end
  end

  def analytics
    analytics_data = fetch_analytics(@seller)
    render json: analytics_data
  end

  def orders
  
    orders = @seller.orders.includes(order_items: [:ad, :order], buyer: :orders)
                          .where(order_items: { ad_id: @seller.ads.pluck(:id) })
  
    filtered_orders = orders.map do |order|
      {
        id: order.id,
        status: order.status,
        total_amount: order.total_amount,
        processing_fee: order.processing_fee,
        delivery_fee: order.delivery_fee,
        created_at: order.created_at,
        updated_at: order.updated_at,
        mpesa_transaction_code: order.mpesa_transaction_code,
        buyer: {
          id: order.buyer.id,
          fullname: order.buyer.fullname,
          email: order.buyer.email,
          phone_number: order.buyer.phone_number
        },
        order_items: order.order_items
                          .select { |item| @seller.ads.exists?(item.ad_id) }
                          .map do |item|
          {
            id: item.id,
            quantity: item.quantity,
            price: item.price,
            total_price: item.total_price,
            ad: {
              id: item.ad.id,
              title: item.ad.title,
              seller_id: item.ad.seller_id,
              price: item.ad.price
            }
          }
        end
      }
    end
  
    render json: filtered_orders, status: :ok
  end

  private

  def set_seller
    @seller = Seller.find(params[:id])
  end

  def seller_params
    params.require(:seller).permit(:fullname, :phone_number, :email, :enterprise_name, :location, :password, :business_registration_number, category_ids: [])
  end

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end


  def most_clicked_ad(seller)
    most_clicked = ClickEvent.where(ad_id: seller.ads.pluck(:id))
                             .group(:ad_id)
                             .order('count_id DESC')
                             .limit(1)
                             .count(:id)
                             .first
  
    if most_clicked
      ad = Ad.find(most_clicked[0])
      {
        ad_id: ad.id,
        title: ad.title,
        total_clicks: most_clicked[1],
        category: ad.category.name
      }
    else
      nil
    end
  end
  
  def fetch_analytics(seller)
    seller_ads = seller.ads
    ad_ids = seller_ads.pluck(:id)
    click_events = ClickEvent.where(ad_id: ad_ids)
    click_event_counts = click_events.group(:event_type).count
  
    # Seller Engagement & Visibility
    total_clicks = click_event_counts["Ad-Click"] || 0
    total_profile_views = click_event_counts["Reveal-Seller-Details"] || 0
    reveal_seller_details_clicks = click_event_counts["Reveal-Seller-Details"] || 0
    ad_performance_rankings = Seller.joins(ads: :click_events)
                                .group("sellers.id")
                                .order(Arel.sql("COUNT(click_events.id) DESC"))
                                .count("click_events.id")
                                .keys

    ad_performance_rank = ad_performance_rankings.index(seller.id)&.next || nil
    
    # Seller Activity & Consistency
    last_activity = seller.ads.order(updated_at: :desc).limit(1).pluck(:updated_at).first
    total_ads_updated = seller_ads.where.not("updated_at = created_at").count
    ad_approval_rate = (seller_ads.where(approved: true).count.to_f / seller_ads.count * 100).round(2) rescue 0
  
    # Competitor & Category Insights
    top_category = seller_ads.joins("JOIN categories_sellers ON ads.seller_id = categories_sellers.seller_id")
                      .joins("JOIN categories ON categories_sellers.category_id = categories.id")
                      .group("categories.name")
                      .order("COUNT(ads.id) DESC")
                      .limit(1)
                      .count
                      .keys.first rescue "Unknown"

    category_comparison = Seller.joins(:ads)
                      .joins("JOIN categories_sellers ON sellers.id = categories_sellers.seller_id")
                      .where("categories_sellers.category_id = ?", seller.category.id)
                      .group("sellers.id")
                      .count
                      .sort_by { |_seller_id, ad_count| -ad_count }
                      .to_h

    seller_category_rank = category_comparison.keys.index(seller.id).to_i + 1 rescue nil
  
    # Customer Interest & Conversion
    wishlist_to_click_ratio = (click_event_counts["Add-to-Wish-List"].to_f / total_clicks * 100).round(2) rescue 0
    wishlist_to_contact_ratio = (click_event_counts["Add-to-Wish-List"].to_f / reveal_seller_details_clicks * 100).round(2) rescue 0
    most_wishlisted_ad = WishList.where(ad_id: ad_ids)
                        .group(:ad_id)
                        .order("count_id DESC")
                        .limit(1)
                        .count(:id)
                        .first
  
    most_wishlisted_ad_data = most_wishlisted_ad ? Ad.find(most_wishlisted_ad[0]).as_json(only: [:id, :title]) : nil
  
    {
      # Ad Inventory
      total_ads: seller_ads.count,

      # Ad Performance
      total_ads_wishlisted: WishList.where(ad_id: ad_ids).count,

      # Rating
      mean_rating: seller.reviews.joins(:ad)
                                .where(ads: { id: ad_ids })
                                .average(:rating).to_f.round(2),
  
      # Total Reviews
      total_reviews: seller.reviews.joins(:ad)
                                   .where(ads: { id: ad_ids })
                                   .group(:rating)
                                   .count
                                   .values.sum,
  
      # Rating Breakdown
      rating_pie_chart: (1..5).map do |rating|
        {
          rating: rating,
          count: seller.reviews.joins(:ad)
                              .where(ads: { id: ad_ids })
                              .group(:rating)
                              .count[rating] || 0
        }
      end,
  
      # Reviews
      reviews: seller.reviews.joins(:ad, :buyer)
                      .where(ads: { id: ad_ids })
                      .select('reviews.*, buyers.fullname AS buyer_name')
                      .as_json(only: [:id, :rating, :review, :created_at],
                                include: { buyer: { only: [:fullname] } }),
  
      # Click Event Breakdown
      ad_clicks: total_clicks,
      add_to_wish_list: click_event_counts["Add-to-Wish-List"] || 0,
      reveal_seller_details: reveal_seller_details_clicks,
      total_click_events: click_events.count,
  
      # Engagement & Visibility Metrics
      total_profile_views: total_profile_views,
      ad_performance_rank: ad_performance_rank,
  
      # Activity & Consistency
      last_activity: last_activity,
      total_ads_updated: total_ads_updated,
      ad_approval_rate: ad_approval_rate,
  
      # Competitor & Category Insights
      seller_category: seller.category.name,
      top_performing_category: top_category,
      category_rank: seller_category_rank,
  
      # Customer Interest & Conversion
      wishlist_to_click_ratio: wishlist_to_click_ratio,
      wishlist_to_contact_ratio: wishlist_to_contact_ratio,
      most_wishlisted_ad: most_wishlisted_ad_data,
      most_clicked_ad: most_clicked_ad(seller),
  
      last_ad_posted_at: seller_ads.order(created_at: :desc).limit(1).pluck(:created_at).first,
      account_age_days: (Time.current.to_date - seller.created_at.to_date).to_i
    }
  end  
end
