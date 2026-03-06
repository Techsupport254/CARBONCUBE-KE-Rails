class Seller::CategoriesController < ApplicationController
  def index
    # Optimization: Use includes to fetch subcategories in a single query (avoid N+1)
    @categories = Category.includes(:subcategories).order(:name)
    
    # Return Categories with their Subcategories for a one-shot fetch for the /ads/new form
    render json: @categories.as_json(include: { 
      subcategories: { 
        only: [:id, :name, :image_url, :ads_count] 
      }
    })
  end
end