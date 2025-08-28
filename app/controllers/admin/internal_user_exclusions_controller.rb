class Admin::InternalUserExclusionsController < ApplicationController
  before_action :authenticate_admin
  before_action :set_request, only: [:show, :approve, :reject]

  # GET /admin/internal_user_exclusions
  def index
    # Start with all records
    @exclusions = InternalUserExclusion.all.order(created_at: :desc)
    
    if params[:type].present?
      case params[:type]
      when 'removal_requests'
        # Show only removal requests (where requester_name is present)
        @exclusions = @exclusions.where.not(requester_name: [nil, ''])
      when 'exclusions'
        # Show only direct exclusions (where requester_name is null)
        @exclusions = @exclusions.where(requester_name: [nil, ''])
      end
    end
    
    if params[:status].present?
      @exclusions = @exclusions.where(status: params[:status])
    end
    
    render json: @exclusions, status: :ok
  end

  # GET /admin/internal_user_exclusions/:id
  def show
    render json: @exclusion, status: :ok
  end

  # POST /admin/internal_user_exclusions/:id/approve
  def approve
    if @exclusion.removal_request? && @exclusion.approve!
      render json: {
        message: 'Request approved successfully',
        exclusion: @exclusion,
        exclusion_activated: true
      }, status: :ok
    else
      render json: { 
        errors: @exclusion.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # POST /admin/internal_user_exclusions/:id/reject
  def reject
    rejection_reason = params[:rejection_reason]
    
    if @exclusion.removal_request? && @exclusion.reject!(rejection_reason)
      render json: {
        message: 'Request rejected successfully',
        exclusion: @exclusion
      }, status: :ok
    else
      render json: { 
        errors: @exclusion.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # GET /admin/internal_user_exclusions/stats
  def stats
    total_exclusions = InternalUserExclusion.count
    total_removal_requests = InternalUserExclusion.removal_requests.count
    pending_requests = InternalUserExclusion.pending_requests.count
    approved_requests = InternalUserExclusion.approved_requests.count
    rejected_requests = InternalUserExclusion.rejected_requests.count
    active_exclusions = InternalUserExclusion.active.count
    
    recent_requests = InternalUserExclusion.removal_requests.where('created_at >= ?', 30.days.ago).count

    render json: {
      total_exclusions: total_exclusions,
      total_removal_requests: total_removal_requests,
      pending_requests: pending_requests,
      approved_requests: approved_requests,
      rejected_requests: rejected_requests,
      active_exclusions: active_exclusions,
      recent_requests: recent_requests
    }, status: :ok
  end

  private

  def set_request
    @exclusion = InternalUserExclusion.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Exclusion not found' }, status: :not_found
  end

  def authenticate_admin
    @current_admin = AdminAuthorizeApiRequest.new(request.headers).result
    render json: { error: 'Not authorized' }, status: :unauthorized unless @current_admin
  rescue ExceptionHandler::InvalidToken
    render json: { error: 'Invalid token' }, status: :unauthorized
  end
end
