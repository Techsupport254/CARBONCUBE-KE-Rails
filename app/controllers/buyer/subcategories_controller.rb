# app/controllers/buyer/subcategories_controller.rb
class Buyer::SubcategoriesController < ApplicationController
  before_action :set_subcategory, only: [:show]

  # GET /buyer/subcategories
  def index
    @subcategories = Rails.cache.fetch('buyer_subcategories_all_v2', expires_in: 12.hours) do
      Subcategory.all.as_json(
        only: [:id, :name, :category_id, :created_at, :updated_at, :image_url]
      )
    end
    render json: @subcategories
  end

  # GET /buyer/subcategories/:id
  def show
    render json: @subcategory
  end

  private

  def set_subcategory
    @subcategory = Subcategory.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Subcategory not found' }, status: :not_found
  end

  def subcategory_params
    params.require(:subcategory).permit(:name, :category_id)
  end
end
