class Admin::Seller::AdsController < ApplicationController
  before_action :authenticate_admin
  before_action :set_seller

  def index
    @ads = @seller.ads
    render json: @ads
  end

  private

  def set_seller
    @seller = Seller.find(params[:seller_id])
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
