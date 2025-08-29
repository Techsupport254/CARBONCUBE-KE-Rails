# app/controllers/buyer/categories_controller.rb
class Buyer::CategoriesController < ApplicationController
  def index
    @categories = Rails.cache.fetch('buyer_categories_with_subcategories', expires_in: 12.hours) do
      Category.includes(:subcategories).all.as_json(include: :subcategories)
    end
    render json: @categories
  end
end
