class Admin::Buyer::ProfilesController < ApplicationController
  before_action :authenticate_admin
  before_action :set_buyer

  # GET /admin/buyers/:buyer_id/profile
  def show
    render json: @buyer
  end

  private

  def set_buyer
    @buyer = Buyer.find(params[:buyer_id])
  end

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end
