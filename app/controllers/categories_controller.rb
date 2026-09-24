class CategoriesController < ApplicationController
  # GET /categories
  def index
    @categories = Rails.cache.fetch('public_categories_with_ads_count', expires_in: 1.hour) do
      # Grouped count — the old includes(:ads) loaded every ad row into memory
      # and still ran a COUNT per category.
      counts = Ad.where(deleted: false).group(:category_id).count
      Category.includes(:subcategories).all.map do |category|
        category_data = category.as_json(include: :subcategories)
        category_data['ads_count'] = counts[category.id] || 0
        category_data
      end
    end
    expires_in 1.hour, public: true
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
      # Match the parameterized name in SQL instead of loading every category.
      # regexp_replace mirrors String#parameterize for our names.
      slug = params[:id].to_s
      @category = Category.where(
        "trim(both '-' from regexp_replace(lower(name), '[^a-z0-9]+', '-', 'g')) = ?",
        slug
      ).first
    end

    if @category.nil?
      render json: { error: 'Category not found' }, status: :not_found
      return
    end

    # Get counties where there are active ads for this category
    # Only return counties from onboarded Kenyan counties
    counties = @category.ads
                      .joins(seller: :county)
                      .where(deleted: false)
                      .where(sellers: { blocked: false, deleted: false, flagged: false })
                      .where.not(sellers: { county_id: nil })
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
