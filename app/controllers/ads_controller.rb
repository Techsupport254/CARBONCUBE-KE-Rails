class AdsController < ApplicationController
  # GET /ads
  def index
    per_page = params[:per_page]&.to_i || 100
    per_page = [per_page, 500].min # Cap at 500 for performance
    
    # Fetch ads from all active sellers (not just premium) with valid images
    @ads = Ad.active.with_valid_images.joins(:seller)
             .where(sellers: { blocked: false, deleted: false })
             .where(flagged: false)
             .includes(
               :category,
               :subcategory,
               seller: { seller_tier: :tier }
             )
             .order(Arel.sql('RANDOM()'))
             .limit(per_page)

    render json: @ads, each_serializer: AdSerializer
  end

  # GET /ads/:id
  def show
    @ad = Ad.active.joins(:seller)
            .where(sellers: { blocked: false, deleted: false })
            .where(flagged: false)
            .includes(
              :category,
              :subcategory,
              seller: { seller_tier: :tier }
            )
            .find(params[:id])

    render json: @ad, serializer: AdSerializer
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ad not found' }, status: :not_found
  end
end

