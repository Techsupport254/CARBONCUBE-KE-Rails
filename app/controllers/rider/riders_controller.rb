class Rider::RidersController < ApplicationController
  before_action :set_rider, only: [:show, :update]
  before_action :authenticate_rider, only: [:identify, :show, :update]

  # Identify current rider
  def identify
    render json: { rider_id: current_rider.id }
  end

  # GET /rider/profile
  def show
    render json: current_rider
  end

  # PATCH/PUT /rider/profile
  def update
    if current_rider.update(rider_params)
      render json: current_rider
    else
      render json: current_rider.errors, status: :unprocessable_entity
    end
  end

  # POST /rider/signup
  def create
    @rider = Rider.new(rider_params)

    if @rider.save
      token = JsonWebToken.encode(rider_id: @rider.id, role: 'Rider')
      render json: { token: token, rider: @rider }, status: :created
    else
      render json: @rider.errors, status: :unprocessable_entity
    end
  end

  private

  # Set rider instance for specific actions
  def set_rider
    @rider = Rider.find(params[:id])
  end

  # Strong parameters for rider
  def rider_params
    params.require(:rider).permit(
      :full_name, 
      :phone_number, 
      :age_group_id, 
      :email, 
      :id_number, 
      :driving_license, 
      :vehicle_type, 
      :license_plate, 
      :physical_address, 
      :gender, 
      :kin_full_name, 
      :kin_relationship, 
      :kin_phone_number, 
      :password, 
      :password_confirmation
    )
  end

  # Authenticate rider
  def authenticate_rider
    @current_rider = RiderAuthorizeApiRequest.new(request.headers).result
    unless @current_rider
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  # Current authenticated rider
  def current_rider
    @current_rider
  end
end
