class Admin::AdsController < ApplicationController
  before_action :authenticate_admin
  
  # GET /admin/ads
  def index
    per_page = params[:per_page]&.to_i || 20
    page = params[:page]&.to_i || 1
    
    # Build base query without select for counting
    base_query = Ad.joins(seller: :seller_tier)
         .joins(:category, :subcategory)
         .where(sellers: { blocked: false })

    if params[:category_id].present?
      base_query = base_query.where(category_id: params[:category_id])
    end

    if params[:subcategory_id].present?
      base_query = base_query.where(subcategory_id: params[:subcategory_id])
    end

    # Search functionality
    if params[:query].present?
      search_terms = params[:query].downcase.split(/\s+/)
      title_description_conditions = search_terms.map do |term|
        "(LOWER(ads.title) LIKE ? OR LOWER(ads.description) LIKE ?)"
      end.join(" AND ")
      
      base_query = base_query.where(title_description_conditions, *search_terms.flat_map { |term| ["%#{term}%", "%#{term}%"] })
    end

    # Get total count before applying select and pagination
    total_count = base_query.count
    
    # Apply select, order, and pagination
    offset = (page - 1) * per_page
    @ads = base_query
         .order(created_at: :desc)  # Sort by latest first
         .select('ads.*, seller_tiers.tier_id AS seller_tier')  # Select tier_id from seller_tiers
         .limit(per_page)
         .offset(offset)
    
    flagged_ads = @ads.select { |ad| ad.flagged }
    non_flagged_ads = @ads.reject { |ad| ad.flagged }

    render json: {
      flagged: flagged_ads.as_json(methods: :seller_tier),
      non_flagged: non_flagged_ads.as_json(methods: :seller_tier),
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end
  

  def show
    @ad = Ad.includes(:seller, :category, :subcategory, :reviews => :buyer)
                      .find(params[:id])
                      .tap do |ad|
                        ad.define_singleton_method(:mean_rating) do
                          # Use cached reviews if available, otherwise calculate
                          if reviews.loaded?
                            reviews.any? ? reviews.sum(&:rating).to_f / reviews.size : 0.0
                          else
                            reviews.average(:rating).to_f
                          end
                        end
                      end
    render json: @ad.as_json(
      include: {
        seller: { only: [:fullname, :email] },
        category: { only: [:name] },
        subcategory: { only: [:name] },
        reviews: {
          include: {
            buyer: { only: [:fullname] }
          },
          only: [:rating, :review, :created_at]
        }
      },
      methods: [:mean_rating, :media_urls, :first_media_url],
      except: [:deleted]
    )
  end

  # POST /admin/ads
  def create
    @ad = Ad.new(ad_params)
    if @ad.save
      render json: @ad, status: :created
    else
      render json: @ad.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/ads/:id
  def update
    @ad = Ad.find(params[:id])
    if @ad.update(ad_params)
      render json: @ad
    else
      render json: @ad.errors, status: :unprocessable_entity
    end
  end

  # DELETE /admin/ads/:id
  def destroy
    @ad = Ad.find(params[:id])
    @ad.destroy
    head :no_content
  end

  # Update flagged status
  def flag
    @ad = Ad.find(params[:id])
    @ad.update(flagged: true)  # Set flagged to true
    head :no_content
  end

  # Update flagged status
  def restore
    @ad = Ad.find(params[:id])
    @ad.update(flagged: false)  # Set flagged to false
    head :no_content
  end

  # GET /admin/ads/flagged
  def flagged
    per_page = params[:per_page]&.to_i || 20
    page = params[:page]&.to_i || 1
    
    # Build base query without select for counting
    base_query = Ad.joins(seller: :seller_tier)
             .joins(:category, :subcategory)
             .where(sellers: { blocked: false })
             .where(flagged: true)
    
    # Get total count before applying select and pagination
    total_count = base_query.count
    
    # Apply select, order, and pagination
    offset = (page - 1) * per_page
    @ads = base_query
             .order(created_at: :desc)  # Sort by latest first
             .select('ads.*, seller_tiers.tier_id AS seller_tier')
             .limit(per_page)
             .offset(offset)
    
    render json: {
      ads: @ads.as_json(methods: :seller_tier),
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

# GET /admin/ads/search
def search
  if params[:query].present?
    search_terms = params[:query].downcase.split(/\s+/)

    title_description_conditions = search_terms.map do |term|
      "(LOWER(ads.title) LIKE ? OR LOWER(ads.description) LIKE ?)"
    end.join(" AND ")

    title_description_search = Ad.joins(:seller)
                                      .where(sellers: { blocked: false })
                                      .where(title_description_conditions, *search_terms.flat_map { |term| ["%#{term}%", "%#{term}%"] })

    category_search = Ad.joins(:seller, :category)
                             .where(sellers: { blocked: false })
                             .where('LOWER(categories.name) ILIKE ?', "%#{params[:query].downcase}%")
                             .select('ads.*')

    subcategory_search = Ad.joins(:seller, :subcategory)
                                .where(sellers: { blocked: false })
                                .where('LOWER(subcategories.name) ILIKE ?', "%#{params[:query].downcase}%")
                                .select('ads.*')

    # Combine results and remove duplicates
    @ads = (title_description_search.to_a + category_search.to_a + subcategory_search.to_a).uniq
  else
    @ads = Ad.joins(:seller)
                       .where(sellers: { blocked: false })
  end

  render json: @ads
end



  private

  def ad_params
    params.require(:ad).permit(:title, :description, :price, :category_id, :subcategory_id, :brand, :manufacturer, :package_dimensions, :package_weight, :seller_id, :condition)
  end

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
