class Admin::CategoriesController < ApplicationController
  before_action :authenticate_admin
  before_action :set_category, only: [:show, :update, :destroy]

  def index
    @categories = Category.includes(:subcategories).all
    render json: @categories.to_json(include: :subcategories)
  end

  def show
    render json: @category.to_json(include: :subcategories)
  end

  def create
    @category = Category.new(category_params)
    if @category.save
      render json: @category.to_json(include: :subcategories), status: :created
    else
      render json: @category.errors, status: :unprocessable_entity
    end
  end

  def update
    if @category.update(category_params)
      render json: @category.to_json(include: :subcategories)
    else
      render json: @category.errors, status: :unprocessable_entity
    end
  end

  def destroy
    ActiveRecord::Base.transaction do
      # Find the category
      category = Category.find(params[:id])

      # Delete associated subcategories
      category.subcategories.destroy_all

      # Alternatively, if you want to delete related ads:
      # category.ads.update_all(subcategory_id: nil) # Or handle them as needed

      # Delete the category
      category.destroy!
    end

    head :no_content
  rescue StandardError => e
    Rails.logger.error(e.message)
    render json: { error: 'Failed to delete category' }, status: :unprocessable_entity
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :description, subcategories_attributes: [:id, :name, :_destroy])
  end

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_admin
    @current_user
  end
end
