class Admin::SubcategoriesController < ApplicationController
  before_action :authenticate_admin
  before_action :set_subcategory, only: [:show, :update, :destroy]

  def index
    @subcategories = Subcategory.all
    render json: @subcategories
  end

  def show
    render json: @subcategory
  end

  def create
    @subcategory = Subcategory.new(subcategory_params)
    if @subcategory.save
      render json: @subcategory, status: :created
    else
      render json: @subcategory.errors, status: :unprocessable_entity
    end
  end

  def update
    if @subcategory.update(subcategory_params)
      render json: @subcategory
    else
      render json: @subcategory.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @subcategory.destroy
    head :no_content
  end

  private

  def set_subcategory
    @subcategory = Subcategory.find(params[:id])
  end

  def subcategory_params
    params.require(:subcategory).permit(:name, :description, :category_id)
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
