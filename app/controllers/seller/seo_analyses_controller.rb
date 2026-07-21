class Seller::SeoAnalysesController < ApplicationController
  before_action :authenticate_seller

  # POST /seller/seo_analysis
  def create
    url = params[:url]

    if url.blank?
      return render json: { success: false, error: 'URL is required' }, status: :bad_request
    end

    unless valid_url?(url)
      return render json: { success: false, error: 'Invalid URL format' }, status: :bad_request
    end

    result = SeoScraperService.new(url).analyze

    if result[:success]
      render json: result, status: :ok
    else
      render json: result, status: :ok
    end
  end

  private

  def valid_url?(url)
    uri = URI.parse(url)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue
    false
  end

  def authenticate_seller
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_seller && @current_seller.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end
