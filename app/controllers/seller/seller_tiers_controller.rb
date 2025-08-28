class Seller::SellerTiersController < ApplicationController
  before_action :authenticate_seller

  def index
    @current_seller = current_seller
    
    # Get the seller's current tier
    @current_tier = @current_seller.seller_tier&.tier
    
    # Get all available tiers
    @available_tiers = Tier.all.order(:level)
    
    # Get tier requirements and benefits
    @tier_data = @available_tiers.map do |tier|
      {
        id: tier.id,
        name: tier.name,
        level: tier.level,
        description: tier.description,
        ad_limit: tier.ad_limit,
        is_current: @current_tier&.id == tier.id,
        requirements: tier.requirements,
        benefits: tier.benefits
      }
    end
    
    render json: @tier_data
  end

  def show
    @tier = Tier.find(params[:id])
    
    render json: {
      id: @tier.id,
      name: @tier.name,
      level: @tier.level,
      description: @tier.description,
      ad_limit: @tier.ad_limit,
      requirements: @tier.requirements,
      benefits: @tier.benefits
    }
  end

  def update
    @current_seller = current_seller
    
    # Get the requested tier
    @requested_tier = Tier.find(params[:id])
    
    # Check if seller meets requirements for the tier
    if meets_tier_requirements?(@current_seller, @requested_tier)
      # Update seller's tier
      @current_seller.seller_tier&.update!(tier: @requested_tier)
      
      render json: {
        success: true,
        message: "Tier updated successfully",
        new_tier: {
          id: @requested_tier.id,
          name: @requested_tier.name,
          level: @requested_tier.level,
          ad_limit: @requested_tier.ad_limit
        }
      }
    else
      render json: {
        success: false,
        message: "You don't meet the requirements for this tier",
        requirements: @requested_tier.requirements
      }, status: :unprocessable_entity
    end
  end

  private

  def meets_tier_requirements?(seller, tier)
    # Implement tier requirement checking logic here
    # For now, allow all tier changes
    true
  end
end
