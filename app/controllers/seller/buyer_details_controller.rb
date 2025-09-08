class Seller::BuyerDetailsController < ApplicationController
  include ExceptionHandler
  
  before_action :authenticate_seller

  # GET /seller/ads/:ad_id/buyer_details
  def show
    Rails.logger.info "=== BuyerDetailsController#show - START ==="
    Rails.logger.info "=== Request received at: #{Time.current} ==="
    ad_id = params[:ad_id]
    
    Rails.logger.info "BuyerDetailsController#show - START - ad_id: #{ad_id}"
    Rails.logger.info "BuyerDetailsController#show - current_seller: #{current_seller&.email}"
    Rails.logger.info "BuyerDetailsController#show - current_seller_id: #{current_seller&.id}"
    
    # Verify the ad belongs to the current seller
    ad = current_seller&.ads&.find_by(id: ad_id)
    Rails.logger.info "BuyerDetailsController#show - ad found: #{ad&.title}"
    Rails.logger.info "BuyerDetailsController#show - ad seller_id: #{ad&.seller_id}"
    
    unless ad
      Rails.logger.error "BuyerDetailsController#show - Ad not found or access denied for ad_id: #{ad_id}, seller: #{current_seller&.email}"
      Rails.logger.error "BuyerDetailsController#show - Seller ads count: #{current_seller&.ads&.count}"
      Rails.logger.error "BuyerDetailsController#show - Ad exists check: #{Ad.exists?(id: ad_id)}"
      render json: { error: 'Ad not found or access denied' }, status: :not_found
      return
    end

    begin
      buyer_details = BuyerDetailsUtility.get_ad_reviewers_details(ad_id)
      render json: {
        success: true,
        data: buyer_details
      }
    rescue => e
      render json: { 
        error: 'Failed to fetch buyer details',
        message: e.message 
      }, status: :internal_server_error
    end
  end

  # GET /seller/ads/:ad_id/buyer_details/summary
  def summary
    ad_id = params[:ad_id]
    
    # Verify the ad belongs to the current seller
    ad = current_seller.ads.find_by(id: ad_id)
    unless ad
      render json: { error: 'Ad not found or access denied' }, status: :not_found
      return
    end

    begin
      buyer_details = BuyerDetailsUtility.get_ad_reviewers_details(ad_id)
      
      # Return only summary statistics
      render json: {
        success: true,
        data: {
          ad_id: ad_id,
          total_reviews: buyer_details[:total_reviews],
          unique_reviewers: buyer_details[:unique_reviewers],
          summary: buyer_details[:summary]
        }
      }
    rescue => e
      render json: { 
        error: 'Failed to fetch buyer summary',
        message: e.message 
      }, status: :internal_server_error
    end
  end

  private

  def authenticate_seller
    @current_user = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_seller
    @current_user
  end
end
