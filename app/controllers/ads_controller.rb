class AdsController < ApplicationController
  # GET /ads
  def index
    # Fetch ads from sellers who are subscribed to the "Premium" tier
    @ads = Ad.joins(:seller => :seller_tier)
             .where(seller_tiers: { tier_id: 4 }) # Tier ID 4 corresponds to "Premium"
             .where(sellers: { blocked: false }) # Ensure the seller is not blocked
             .where(flagged: false) # Exclude flagged ads
             .distinct
             .sample(3) # Select three random ads

    render json: @ads, each_serializer: AdSerializer
  end
end

