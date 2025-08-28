class SellersController < ApplicationController
  def ads
    seller = Seller.find(params[:seller_id])
    ads = seller.ads.includes(:category, :subcategory) # eager-load if needed
    render json: ads.map { |ad| ad.as_json.merge(
      {
        media_urls: ad.media_urls, # Adjust to how you handle images
        category_name: ad.category&.name,
        subcategory_name: ad.subcategory&.name
      }
    ) }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Seller not found' }, status: :not_found
  end
end