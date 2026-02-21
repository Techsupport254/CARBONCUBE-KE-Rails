class Seller::CatalogsController < ApplicationController
  before_action :authenticate_seller

  def show
    @seller = current_seller
    @products = @seller.ads.order(created_at: :desc)
    
    respond_to do |format|
      format.html { render layout: false }
      format.csv do
        require 'csv'
        csv_data = CSV.generate(headers: true) do |csv|
          csv << ["#", "Title", "Description", "Category", "Subcategory", "Price (KES)", "Status", "URL"]
          @products.each_with_index do |p, index|
            csv << [
              index + 1,
              p.title,
              p.description,
              p.category_name,
              p.subcategory_name,
              p.price,
              p.deleted ? "Deleted" : "Active",
              p.deleted ? "" : "https://carboncube-ke.com/ads/#{Ad.slugify(p.title)}?id=#{p.id}"
            ]
          end
        end
        send_data csv_data, filename: "product_catalog_#{@seller.enterprise_name.parameterize}_#{Date.today}.csv"
      end
    end
  end

  private

  def authenticate_seller
    # Try header first
    begin
      @current_seller = SellerAuthorizeApiRequest.new(request.headers).result
    rescue ExceptionHandler::InvalidToken, ExceptionHandler::MissingToken
      @current_seller = nil
    end

    # Try params token if header failed
    if @current_seller.nil? && params[:token].present?
      begin
        @current_seller = SellerAuthorizeApiRequest.new({ 'Authorization' => params[:token] }).result
      rescue ExceptionHandler::InvalidToken, ExceptionHandler::MissingToken
        @current_seller = nil
      end
    end
    
    unless @current_seller && @current_seller.is_a?(Seller)
      render json: { message: "No token provided", error_type: "invalid_token" }, status: :unauthorized
    end
  end

  def current_seller
    @current_seller
  end
end
