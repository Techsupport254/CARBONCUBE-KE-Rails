class ClickEventsController < ApplicationController
  # Remove authentication requirement for click events to allow anonymous tracking
  # before_action :authenticate_buyer, only: [:create]

  def create
    # Check if this is an internal user that should be excluded
    if internal_user_excluded?
      render json: { message: 'Click logged successfully (internal user excluded)' }, status: :created
      return
    end

    # Prepare metadata with device fingerprinting information
    metadata = click_event_params[:metadata] || {}
    
    # Add device fingerprinting data to metadata if provided
    if params[:device_hash].present?
      metadata[:device_hash] = params[:device_hash]
    end
    if params[:user_agent].present?
      metadata[:user_agent] = params[:user_agent]
    end
    
    # Create click event with processed parameters
    click_event = ClickEvent.new(
      event_type: click_event_params[:event_type],
      ad_id: click_event_params[:ad_id],
      metadata: metadata
    )

    # Set buyer_id to nil if authentication failed
    click_event.buyer_id = @current_user&.id

    if click_event.save
      render json: { message: 'Click logged successfully' }, status: :created
    else
      render json: { errors: click_event.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # Attempt to authenticate the buyer, but do not halt the request
  def authenticate_buyer
    @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
  rescue ExceptionHandler::MissingToken, ExceptionHandler::InvalidToken
    @current_user = nil
  end

  def click_event_params
    # Only permit the fields that actually exist in the ClickEvent model
    params.permit(:event_type, :ad_id, :device_hash, :user_agent, metadata: {}, click_event: {})
  end

  # Check if the current request should be excluded based on internal user criteria
  def internal_user_excluded?
    # Get identifiers from request
    device_hash = params[:device_hash]
    user_agent = params[:user_agent] || request.user_agent
    ip_address = request.remote_ip
    email = @current_user&.email

    # Check against exclusion rules
    InternalUserExclusion.should_exclude?(
      device_hash: device_hash,
      user_agent: user_agent,
      ip_address: ip_address,
      email: email
    )
  end
end
