# app/controllers/buyer/categories_controller.rb
class Buyer::CategoriesController < ApplicationController
  def index
    @categories = Rails.cache.fetch('buyer_categories_simple', expires_in: 24.hours) do
      # Simplified query - just get categories with subcategories, no complex analytics
      Category.includes(:subcategories).all.map do |category|
        category.as_json(include: :subcategories)
      end
    end
    render json: @categories
  end
end
