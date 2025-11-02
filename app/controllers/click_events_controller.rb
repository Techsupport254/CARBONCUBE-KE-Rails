class ClickEventsController < ApplicationController
  before_action :authenticate_buyer, only: [:create]

  def create
    # Check if this is an internal user that should be excluded
    is_internal_excluded = internal_user_excluded?

    # Wrap entire operation in transaction for ACID compliance
    # This ensures metadata preparation and record creation are atomic
    ActiveRecord::Base.transaction do
      # Prepare metadata with device fingerprinting information
      metadata = click_event_params[:metadata] || {}
      
      # Add device fingerprinting data to metadata if provided
      if params[:device_hash].present?
        metadata[:device_hash] = params[:device_hash]
      end
      if params[:user_agent].present?
        metadata[:user_agent] = params[:user_agent]
      end

      # Extract user information from metadata if available (for non-buyer users or when auth fails)
      user_id_from_metadata = metadata[:user_id] || metadata['user_id']
      user_role_from_metadata = metadata[:user_role] || metadata['user_role']

      # Determine buyer_id:
      # 1. If @current_user is a Buyer, use that
      # 2. If user_id_from_metadata exists and user_role is 'buyer', try to find that buyer
      # 3. Otherwise, set to nil (guest user or non-buyer user)
      buyer_id = nil
      if @current_user&.is_a?(Buyer)
        buyer_id = @current_user.id
        Rails.logger.info "ClickEventsController: Setting buyer_id from authenticated buyer: #{buyer_id}"
      elsif user_id_from_metadata && user_role_from_metadata&.downcase == 'buyer'
        # Try to find buyer from metadata
        buyer = Buyer.find_by(id: user_id_from_metadata)
        if buyer && !buyer.deleted?
          buyer_id = buyer.id
          Rails.logger.info "ClickEventsController: Setting buyer_id from metadata (buyer): #{buyer_id}"
        else
          Rails.logger.warn "ClickEventsController: Buyer ID #{user_id_from_metadata} from metadata not found or deleted"
        end
      elsif user_id_from_metadata
        Rails.logger.info "ClickEventsController: User ID #{user_id_from_metadata} (role: #{user_role_from_metadata}) is not a buyer, buyer_id will be nil"
      end
      
      # Create click event with processed parameters
      click_event = ClickEvent.new(
        event_type: click_event_params[:event_type],
        ad_id: click_event_params[:ad_id],
        buyer_id: buyer_id,
        metadata: metadata
      )

      # Extract authentication status from metadata
      was_authenticated = metadata[:was_authenticated] || metadata['was_authenticated'] || false
      is_guest = metadata[:is_guest] || metadata['is_guest'] || !was_authenticated
      triggered_login_modal = metadata[:triggered_login_modal] || metadata['triggered_login_modal'] || false

      # Log what we're about to save
      Rails.logger.info "ClickEventsController: Creating click event: #{{
        event_type: click_event.event_type,
        ad_id: click_event.ad_id,
        buyer_id: click_event.buyer_id,
        user_id_from_metadata: user_id_from_metadata,
        user_role_from_metadata: user_role_from_metadata,
        was_authenticated: was_authenticated,
        is_guest: is_guest,
        triggered_login_modal: triggered_login_modal,
        is_internal_excluded: is_internal_excluded
      }.to_json}"

      # Use save! to raise exception on failure for proper rollback
      click_event.save!

      # Log successful save with created record details
      if click_event.event_type == 'Reveal-Seller-Details'
        auth_status = was_authenticated ? 'AUTHENTICATED' : 'GUEST'
        Rails.logger.info "ClickEventsController: Reveal-Seller-Details saved: ID=#{click_event.id}, buyer_id=#{click_event.buyer_id}, ad_id=#{click_event.ad_id}, user_status=#{auth_status}, triggered_login=#{triggered_login_modal}"
      else
        Rails.logger.info "ClickEventsController: Click event saved successfully: ID=#{click_event.id}, buyer_id=#{click_event.buyer_id}, event_type=#{click_event.event_type}, ad_id=#{click_event.ad_id}"
      end

      message = is_internal_excluded ? 'Click logged successfully (internal user excluded)' : 'Click logged successfully'
      render json: { 
        message: message,
        click_event: {
          id: click_event.id,
          buyer_id: click_event.buyer_id,
          ad_id: click_event.ad_id,
          event_type: click_event.event_type,
          user_id: user_id_from_metadata,
          user_role: user_role_from_metadata,
          was_authenticated: was_authenticated,
          is_guest: is_guest,
          triggered_login_modal: triggered_login_modal
        }
      }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      # Validation failures don't require rollback (nothing was saved)
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    rescue StandardError => e
      # Log error for debugging
      Rails.logger.error "Click event creation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Manually rollback transaction to ensure data consistency
      ActiveRecord::Base.connection.rollback_db_transaction
      # Render error response
      render json: { errors: ['Failed to log click event'] }, status: :internal_server_error
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
    
    # Get email from authenticated user or from metadata
    email = @current_user&.email
    
    # Check if current user is an admin - exclude all admin users
    begin
      admin = AdminAuthorizeApiRequest.new(request.headers).result
      if admin&.is_a?(Admin)
        return true
      end
      email = admin&.email if email.blank? && admin
    rescue ExceptionHandler::InvalidToken, ExceptionHandler::MissingToken
      # Not an admin, continue
    rescue
      # Unexpected error, continue
    end
    
    # Check if current user is sales@example.com
    begin
      sales_user = SalesAuthorizeApiRequest.new(request.headers).result
      if sales_user
        sales_email = sales_user.email
        return true if sales_email&.downcase == 'sales@example.com'
        email = sales_email if email.blank?
      end
    rescue
      # Not a sales user, continue
    end
    
    # Check other user types
    if email.blank? && @current_user
      email = @current_user.email
    end
    
    if email.blank?
      metadata = click_event_params[:metadata] || {}
      email = metadata[:user_email] || metadata['user_email']
    end

    # Check against exclusion rules
    InternalUserExclusion.should_exclude?(
      device_hash: device_hash,
      user_agent: user_agent,
      ip_address: ip_address,
      email: email
    )
  end
end
