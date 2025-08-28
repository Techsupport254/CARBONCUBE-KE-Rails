class Buyer::PromotionsController < ApplicationController
  before_action :authenticate_buyer # Ensure the buyer is authenticated

  def validate_coupon
    code = params[:coupon_code]
    promotion = Promotion.find_by(coupon_code: code)
  
    if promotion.nil?
      render json: { error: 'Coupon does not exist' }, status: :not_found
    elsif Time.current.between?(promotion.start_date, promotion.end_date)
      render json: { discount_percentage: promotion.discount_percentage }, status: :ok
    else
      render json: { error: 'Coupon is not valid at this time' }, status: :unprocessable_entity
    end
  end
  
  

  private
  def authenticate_buyer
    @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Buyer)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_buyer
    @current_user
  end
end
