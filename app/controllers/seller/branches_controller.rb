class Seller::BranchesController < ApplicationController
  before_action :authenticate_seller
  before_action :set_branch, only: [:show, :update, :destroy]
  before_action :ensure_seller_owns_branch, only: [:show, :update, :destroy]

  # GET /seller/branches
  def index
    @branches = @current_seller.branches.order(created_at: :desc)
    render json: @branches
  end

  # GET /seller/branches/:id
  def show
    render json: @branch
  end

  # POST /seller/branches
  def create
    @branch = @current_seller.branches.build(branch_params)

    if @branch.save
      render json: @branch, status: :created
    else
      render json: { errors: @branch.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /seller/branches/:id
  def update
    if @branch.update(branch_params)
      render json: @branch
    else
      render json: { errors: @branch.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /seller/branches/:id
  def destroy
    # Prevent deleting the main branch if it's the only branch
    if @branch.is_main_branch? && @current_seller.branches.count == 1
      render json: { error: "Cannot delete the only branch" }, status: :unprocessable_entity
      return
    end

    if @branch.is_main_branch?
      # If deleting main branch, promote another branch to main
      next_branch = @current_seller.branches.where.not(id: @branch.id).first
      if next_branch
        next_branch.update(is_main_branch: true)
      end
    end

    @branch.destroy
    head :no_content
  end

  private

  def set_branch
    @branch = Branch.find(params[:id])
  end

  def ensure_seller_owns_branch
    unless @branch.seller_id == @current_seller.id
      render json: { error: "Unauthorized" }, status: :forbidden
    end
  end

  def branch_params
    params.require(:branch).permit(
      :name,
      :description,
      :location,
      :latitude,
      :longitude,
      :phone,
      :is_main_branch
    )
  end

  def authenticate_seller
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_seller && @current_seller.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end
