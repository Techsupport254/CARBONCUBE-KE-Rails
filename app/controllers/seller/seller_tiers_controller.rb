class Seller::SellerTiersController < ApplicationController
  before_action :authenticate_seller

  def index
    @current_seller = current_seller
    
    # Get the seller's current tier
    @current_tier = @current_seller.seller_tier&.tier
    
    # Get all available tiers
    @available_tiers = Tier.all.order(:name)
    
    # Get tier requirements and benefits
    @tier_data = @available_tiers.map do |tier|
      {
        id: tier.id,
        name: tier.name,
        ad_limit: tier.ads_limit,
        is_current: @current_tier&.id == tier.id
      }
    end
    
    render json: @tier_data
  end

  def show
    # Handle both tier ID and seller ID cases
    if params[:seller_id]
      # Find seller tier by seller_id
      seller_tier = SellerTier.find_by(seller_id: params[:seller_id])
      
      if seller_tier
        render json: {
          subscription_countdown: seller_tier.subscription_countdown,
          tier: {
            id: seller_tier.tier.id,
            name: seller_tier.tier.name,
            ad_limit: seller_tier.tier.ads_limit
          }
        }
      else
        render json: { error: 'Seller tier not found' }, status: :not_found
      end
    else
      # Original behavior for tier ID
      @tier = Tier.find(params[:id])
      
      render json: {
        id: @tier.id,
        name: @tier.name,
        ad_limit: @tier.ads_limit
      }
    end
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
          ad_limit: @requested_tier.ads_limit
        }
      }
    else
      render json: {
        success: false,
        message: "You don't meet the requirements for this tier"
      }, status: :unprocessable_entity
    end
  end

  private

  def authenticate_seller
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result

    if @current_seller.nil?
      render json: { error: 'Not Authorized' }, status: :unauthorized
    elsif @current_seller.deleted?
      render json: { error: 'Account has been deleted' }, status: :unauthorized
    end
  end

  def current_seller
    @current_seller
  end

  def meets_tier_requirements?(seller, tier)
    # Implement tier requirement checking logic here
    # For now, allow all tier changes
    true
  end
end
