class Api::AdsController < ApplicationController
  # GET /api/ads
  def index
    per_page = params[:per_page]&.to_i || 100
    per_page = [per_page, 500].min # Cap at 500 for performance
    
    # Fetch ads from all active sellers (not just premium)
    @ads = Ad.active.joins(:seller)
             .where(sellers: { blocked: false, deleted: false })
             .where(flagged: false)
             .includes(
               :category,
               :subcategory,
               seller: { seller_tier: :tier }
             )
             .order(created_at: :desc)
             .limit(per_page)

    render json: @ads, each_serializer: AdSerializer
  end

  # GET /api/ads/:id
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
