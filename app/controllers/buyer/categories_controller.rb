# app/controllers/buyer/categories_controller.rb
class Buyer::CategoriesController < ApplicationController
  def index
    @categories = Category.includes(:subcategories).all
    render json: @categories.to_json(include: :subcategories)
  end
end
