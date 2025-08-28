class TiersController < ApplicationController
  def index
    @tiers = Tier.includes(:tier_features, :tier_pricings).all
    render json: @tiers.to_json(include: [:tier_features, :tier_pricings])
  end
end
