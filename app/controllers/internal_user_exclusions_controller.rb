class InternalUserExclusionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]
  before_action :authenticate_admin, only: [:update_status]
  
  # POST /internal_user_exclusions
  def create
    device_hash = params[:device_hash]
    
    # Check if there's already any record for this device hash
    existing_record = InternalUserExclusion.where(identifier_type: 'device_hash', identifier_value: device_hash).first
    
    if existing_record
      if existing_record.removal_request?
        # It's a removal request
        case existing_record.status
        when 'pending'
          render json: { 
            message: 'You already have a pending request for this device',
            status: 'pending'
          }, status: :conflict
          return
        when 'approved'
          render json: { 
            message: 'Your device is already excluded from tracking',
            status: 'approved'
          }, status: :ok
          return
        when 'rejected'
          # Allow creating a new request if the previous one was rejected
        end
      else
        # It's a direct exclusion (not a removal request)
        render json: { 
          message: 'Your device is already excluded from tracking',
          status: 'approved'
        }, status: :ok
        return
      end
    end
    
    begin
      @request = InternalUserExclusion.create_removal_request(request_params)
      
      if @request.persisted?
        render json: {
          message: 'Your request has been submitted successfully. An admin will review it shortly.',
          request_id: @request.id,
          status: 'submitted'
        }, status: :created
      else
        render json: { 
          errors: @request.errors.full_messages 
        }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique => e
      # Handle unique constraint violation by modifying the device hash
      if e.message.include?('index_internal_user_exclusions_on_type_and_value')
        # Try with a modified device hash
        modified_params = request_params.dup
        original_hash = modified_params[:device_hash]
        
        # Find an available hash by appending characters
        counter = 1
        loop do
          modified_hash = "#{original_hash}#{counter}"
          modified_params[:device_hash] = modified_hash
          
          begin
            @request = InternalUserExclusion.create_removal_request(modified_params)
            if @request.persisted?
              render json: {
                message: 'Your request has been submitted successfully. An admin will review it shortly.',
                request_id: @request.id,
                status: 'submitted',
                note: "Device hash modified to ensure uniqueness"
              }, status: :created
              break
            end
          rescue ActiveRecord::RecordNotUnique
            counter += 1
            # Prevent infinite loop
            if counter > 100
              render json: { 
                errors: ['Unable to create unique device hash. Please try again.'] 
              }, status: :unprocessable_entity
              break
            end
          end
        end
      else
        render json: { 
          errors: ['An error occurred while creating the request. Please try again.'] 
        }, status: :unprocessable_entity
      end
    end
  end
  
  # GET /internal_user_exclusions/check/:device_hash
  def check_status
    device_hash = params[:device_hash]
    
    # First, try exact match
    record = InternalUserExclusion.where(identifier_type: 'device_hash', identifier_value: device_hash).first
    
    # If no exact match, try to find records that start with the base hash
    # This handles cases where the hash was modified (e.g., q4bjv0 -> q4bjv01, q4bjv02, etc.)
    if !record
      base_hash = device_hash.gsub(/\d+$/, '') # Remove trailing numbers
      if base_hash != device_hash
        # Look for records that start with the base hash
        record = InternalUserExclusion.where(
          identifier_type: 'device_hash'
        ).where(
          "identifier_value LIKE ?", "#{base_hash}%"
        ).order(created_at: :desc).first
      end
    end
    
    if record
      if record.removal_request?
        # It's a removal request
        render json: {
          status: record.status,
          message: get_status_message(record),
          request_id: record.id,
          created_at: record.created_at,
          rejection_reason: record.rejection_reason,
          approved_at: record.approved_at,
          rejected_at: record.rejected_at,
          device_hash: record.identifier_value
        }, status: :ok
      else
        # It's a direct exclusion (not a removal request)
        render json: {
          status: 'approved',
          message: 'Your device is excluded from tracking',
          request_id: record.id,
          created_at: record.created_at,
          rejection_reason: nil,
          approved_at: record.created_at,
          rejected_at: nil,
          device_hash: record.identifier_value
        }, status: :ok
      end
    else
      render json: {
        status: 'none',
        message: 'No request found for this device',
        request_id: nil,
        created_at: nil,
        device_hash: device_hash
      }, status: :ok
    end
  end
  
  # PATCH /internal_user_exclusions/update_status/:device_hash
  def update_status
    device_hash = params[:device_hash]
    new_status = params[:status]

    request = InternalUserExclusion.removal_requests
                                   .where(identifier_value: device_hash)
                                   .order(created_at: :desc)
                                   .first

    if request
      case new_status
      when 'approved'
        if request.approve!
          render json: {
            message: 'Request approved successfully',
            status: 'approved'
          }, status: :ok
        else
          render json: {
            errors: request.errors.full_messages
          }, status: :unprocessable_entity
        end
      when 'rejected'
        rejection_reason = params[:rejection_reason]
        if request.reject!(rejection_reason)
          render json: {
            message: 'Request rejected successfully',
            status: 'rejected'
          }, status: :ok
        else
          render json: {
            errors: request.errors.full_messages
          }, status: :unprocessable_entity
        end
      else
        render json: {
          error: 'Invalid status'
        }, status: :bad_request
      end
    else
      render json: {
        error: 'Request not found'
      }, status: :not_found
    end
  end

  private
  
  def request_params
    params.permit(:requester_name, :device_description, :device_hash, :user_agent, :additional_info)
  end
  
  def get_status_message(request)
    case request.status
    when 'pending'
      'Your request is pending review by an administrator.'
    when 'approved'
      'Your request has been approved. Your device is now excluded from tracking.'
    when 'rejected'
      "Your request was rejected. Reason: #{request.rejection_reason || 'No reason provided'}"
    else
      'Unknown status'
    end
  end

  def authenticate_admin
    @current_admin = AdminAuthorizeApiRequest.new(request.headers).result
    render json: { error: 'Not authorized' }, status: :unauthorized unless @current_admin
  rescue ExceptionHandler::InvalidToken
    render json: { error: 'Invalid token' }, status: :unauthorized
  rescue ExceptionHandler::MissingToken
    render json: { error: 'Missing authentication token' }, status: :unauthorized
  end
end
