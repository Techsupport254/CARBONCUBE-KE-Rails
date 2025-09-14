class Api::SubcategoriesController < ApplicationController
  # GET /api/subcategories
  def index
    @subcategories = Rails.cache.fetch('api_subcategories_with_ads_count', expires_in: 24.hours) do
      # Get subcategories with ads count
      Subcategory.includes(:category, :ads).all.map do |subcategory|
        subcategory_data = subcategory.as_json(include: :category)
        subcategory_data['ads_count'] = subcategory.ads.where(deleted: false).count
        subcategory_data
      end
    end
    render json: @subcategories
  end

  # GET /api/subcategories/:id
  def show
    @subcategory = Subcategory.includes(:category).find(params[:id])
    render json: @subcategory.as_json(include: :category)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Subcategory not found' }, status: :not_found
  end
end
