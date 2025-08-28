class Admin::RidersController < ApplicationController
  before_action :authenticate_admin
  before_action :set_rider , only: [:show, :update, :destroy, :block, :unblock]

  # GET /admin/riders
  def index
    @riders = Rider.all
    render json: @riders
  end

  # GET /admin/riders/:id
  def show
    render json: @rider
  end

  # PATCH/PUT /admin/riders/:id
  def update
    if @rider.update(rider_params)
      render json: @rider
    else
      render json: @rider.errors, status: :unprocessable_entity
    end
  end

  def block
    @rider = Rider.find_by(id: params[:id])
    if @rider.present?
      if @rider.update(blocked: true)
        render json: @rider.as_json(only: [:id, :full_name, :email, :physical_address, :blocked]), status: :ok
      else
        render json: { errors: @rider.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Rider not found' }, status: :not_found
    end
  end
  
  def unblock
    @rider = Rider.find_by(id: params[:id])
    if @rider.present?
      if @rider.update(blocked: false)
        render json: @rider.as_json(only: [:id, :full_name, :email, :physical_address, :blocked]), status: :ok
      else
        render json: { errors: @rider.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Rider not found' }, status: :not_found
    end
  end
  

  # DELETE /admin/riders/:id
  def destroy
    @rider.destroy
  end

  private

  def set_rider
    @rider = Rider.find(params[:id])
  end

  def rider_params
    params.require(:rider).permit(:full_name, :phone_number, :gender, :age_group_id, :email, :id_number, :driving_license, :physical_address, :vehicle_type, :license_plate, :password, :kin_full_name, :kin_relationship, :kin_phone_number)
  end

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

end