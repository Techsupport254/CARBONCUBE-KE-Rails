class SellersController < ApplicationController
  def ads
    seller = Seller.find(params[:seller_id])
    ads = seller.ads.includes(:category, :subcategory) # eager-load if needed
    
    # Add pagination support (only if page and limit are provided)
    if params[:page] && params[:limit]
      page = params[:page].to_i
      limit = params[:limit].to_i
      offset = (page - 1) * limit
      
      # Apply pagination
      ads = ads.offset(offset).limit(limit)
    end
    
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