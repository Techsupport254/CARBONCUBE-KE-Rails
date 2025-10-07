class CategoriesController < ApplicationController
  # GET /categories
  def index
    @categories = Rails.cache.fetch('public_categories_with_ads_count', expires_in: 24.hours) do
      # Get categories with subcategories and ads count for public display
      Category.includes(:subcategories, :ads).all.map do |category|
        category_data = category.as_json(include: :subcategories)
        category_data['ads_count'] = category.ads.where(deleted: false).count
        category_data
      end
    end
    render json: @categories
  end

  # GET /categories/:id
  def show
    @category = Category.includes(:subcategories, :ads).find(params[:id])
    category_data = @category.as_json(include: :subcategories)
    category_data['ads_count'] = @category.ads.where(deleted: false).count
    render json: category_data
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Category not found' }, status: :not_found
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end
end
