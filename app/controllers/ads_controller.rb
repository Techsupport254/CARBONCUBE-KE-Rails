class AdsController < ApplicationController
  # GET /ads
  def index
    per_page = params[:per_page]&.to_i || 100
    per_page = [per_page, 500].min # Cap at 500 for performance
    
    # Fetch ads from all active sellers (not just premium)
    @ads = Ad.active.joins(:seller)
             .where(sellers: { blocked: false })
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
end

