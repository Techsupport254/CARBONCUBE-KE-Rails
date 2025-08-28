class Admin::Seller::ReviewsController < ApplicationController
  before_action :authenticate_admin
  before_action :set_seller
  before_action :set_ad

  def index
    @reviews = @ad.reviews
    render json: @reviews
  end

  private

  def set_seller
    @seller = Seller.find(params[:seller_id])
  end

  def set_ad
    @ad = @seller.ads.find(params[:ad_id])
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
  