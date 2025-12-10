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

  # GET /categories/:id/locations
  def locations
    # Try to find by ID first, then by name slug
    @category = Category.find_by(id: params[:id])
    if @category.nil?
      # Create slug from name and try to find by that pattern
      Category.all.each do |cat|
        if cat.name.parameterize == params[:id]
          @category = cat
          break
        end
      end
    end

    # Get counties where there are active ads for this category
    counties = @category.ads
                      .joins(seller: :county)
                      .where(deleted: false)
                      .where(sellers: { blocked: false, deleted: false, flagged: false })
                      .select('counties.id, counties.name')
                      .distinct
                      .order('counties.name')

    locations_data = counties.map do |county|
      {
        id: county.id,
        name: county.name,
        slug: county.name.parameterize
      }
    end

    render json: locations_data
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Category not found' }, status: :not_found
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end
end
