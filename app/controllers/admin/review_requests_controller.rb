class Admin::ReviewRequestsController < ApplicationController
  before_action :authenticate_admin

  # GET /admin/review_requests
  def index
    # Only filter by status if it's provided, otherwise show all
    review_requests = ReviewRequest.includes(:seller)
                                   .order(requested_at: :desc)
    
    # Apply status filter only if provided
    if params[:status].present?
      review_requests = review_requests.where(status: params[:status])
    end
    
    # Apply pagination
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    per_page = [per_page, 100].min # Cap at 100
    
    total_count = review_requests.count
    paginated_requests = review_requests.offset((page - 1) * per_page).limit(per_page)
    
    render json: {
      review_requests: paginated_requests.map do |rr|
        {
          id: rr.id,
          seller_id: rr.seller_id,
          seller_name: rr.seller.enterprise_name || rr.seller.fullname,
          seller_email: rr.seller.email,
          status: rr.status,
          reason: rr.reason,
          requested_at: rr.requested_at,
          reviewed_at: rr.reviewed_at,
          reviewed_by: rr.reviewed_by_type ? "#{rr.reviewed_by_type}##{rr.reviewed_by_id}" : nil,
          review_notes: rr.review_notes,
          created_at: rr.created_at,
          updated_at: rr.updated_at
        }
      end,
      pagination: {
        page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  # GET /admin/review_requests/:id
  def show
    review_request = ReviewRequest.includes(:seller).find(params[:id])
    
    render json: {
      id: review_request.id,
      seller_id: review_request.seller_id,
      seller: {
        id: review_request.seller.id,
        name: review_request.seller.enterprise_name || review_request.seller.fullname,
        email: review_request.seller.email,
        phone: review_request.seller.phone_number,
        flagged: review_request.seller.flagged,
        blocked: review_request.seller.blocked,
        deleted: review_request.seller.deleted
      },
      status: review_request.status,
      reason: review_request.reason,
      requested_at: review_request.requested_at,
      reviewed_at: review_request.reviewed_at,
      reviewed_by: review_request.reviewed_by_type ? "#{review_request.reviewed_by_type}##{review_request.reviewed_by_id}" : nil,
      review_notes: review_request.review_notes,
      created_at: review_request.created_at,
      updated_at: review_request.updated_at
    }
  end

  # PATCH /admin/review_requests/:id/approve
  def approve
    review_request = ReviewRequest.find(params[:id])
    seller = review_request.seller
    
    if review_request.status != 'pending'
      render json: { error: 'Review request is not pending' }, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      # Unflag the seller
      seller.update(flagged: false)
      
      # Update review request
      review_request.update(
        status: 'approved',
        reviewed_at: Time.current,
        reviewed_by: current_admin,
        review_notes: params[:review_notes]
      )
    end

    render json: {
      message: 'Review request approved and seller unflagged',
      review_request: {
        id: review_request.id,
        status: review_request.status,
        reviewed_at: review_request.reviewed_at
      }
    }
  end

  # PATCH /admin/review_requests/:id/reject
  def reject
    review_request = ReviewRequest.find(params[:id])
    
    if review_request.status != 'pending'
      render json: { error: 'Review request is not pending' }, status: :unprocessable_entity
      return
    end

    review_request.update(
      status: 'rejected',
      reviewed_at: Time.current,
      reviewed_by: current_admin,
      review_notes: params[:review_notes]
    )

    render json: {
      message: 'Review request rejected',
      review_request: {
        id: review_request.id,
        status: review_request.status,
        reviewed_at: review_request.reviewed_at
      }
    }
  end

  private

  def authenticate_admin
    @current_admin = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_admin && @current_admin.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
      return
    end
  end

  def current_admin
    @current_admin
  end
end

