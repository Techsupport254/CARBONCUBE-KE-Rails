class Api::CategoriesController < ApplicationController
  # GET /api/categories
  def index
    @categories = Rails.cache.fetch('api_categories_with_ads_count', expires_in: 24.hours) do
      # Get categories with subcategories and ads count
      Category.includes(:subcategories, :ads).all.map do |category|
        category_data = category.as_json(include: :subcategories)
        category_data['ads_count'] = category.ads.where(deleted: false).count
        category_data
      end
    end
    render json: @categories
  end

  # GET /api/categories/:id
  def show
    @category = Category.includes(:subcategories).find(params[:id])
    render json: @category.as_json(include: :subcategories)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Category not found' }, status: :not_found
  end
end
