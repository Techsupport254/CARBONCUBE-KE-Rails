class Seller::SubcategoriesController < ApplicationController
  def index
    category_id = params[:category_id]
    @subcategories = Subcategory.where(category_id: category_id)
    render json: @subcategories
  end
end