class Seller::CatalogsController < ApplicationController
  # GET /seller/catalog/search
  def search
    query = params[:query] || params[:q]
    category = params[:subcategory] || params[:category] || 'phones'
    return render json: { phones: [] } if query.blank?

    devices = DeviceCatalogService.search(query, category)
    
    render json: {
      phones: devices.map do |p|
        {
          title: p['title'],
          slug: p['slug'],
          brand: p['brand'],
          specifications: p['specifications']
        }
      end
    }
  end

  # GET /seller/catalog/brands
  def brands
    category = params[:subcategory] || params[:category] || 'phones'
    render json: { brands: DeviceCatalogService.brands(category) }
  end

  # GET /seller/catalog/models
  def models
    brand = params[:brand]
    category = params[:subcategory] || params[:category] || 'phones'
    return render json: { models: [] } if brand.blank?
    
    render json: { models: DeviceCatalogService.models_for_brand(brand, category) }
  end

  # GET /seller/catalog/model/:slug
  def show
    category = params[:subcategory] || params[:category] || 'phones'
    device = DeviceCatalogService.find_by_slug(params[:slug], category)
    if device
      render json: device
    else
      render json: { error: 'Model not found' }, status: :not_found
    end
  end

  private

  def authenticate_seller
    @current_user = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end
