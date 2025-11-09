class Seller::ReviewRequestsController < ApplicationController
  before_action :authenticate_seller

  # GET /seller/review_requests
  def index
    seller = current_seller
    pending_request = ReviewRequest.where(seller_id: seller.id, status: 'pending').order(requested_at: :desc).first
    
    if pending_request
      render json: {
        has_pending_request: true,
        review_request: {
          id: pending_request.id,
          status: pending_request.status,
          requested_at: pending_request.requested_at,
          reason: pending_request.reason
        }
      }
    else
      render json: {
        has_pending_request: false
      }
    end
  end

  # POST /seller/review_requests
  def create
    seller = current_seller
    
    unless seller.flagged?
      render json: { error: 'Your account is not flagged' }, status: :bad_request
      return
    end

    # Check if there's already a pending review request
    existing_request = ReviewRequest.where(seller_id: seller.id, status: 'pending').order(requested_at: :desc).first
    
    if existing_request
      # Check if it was requested recently (within last 24 hours)
      if existing_request.requested_at > 24.hours.ago
        render json: { 
          error: 'You already have a pending review request. Please wait for our team to review it.',
          existing_request_id: existing_request.id
        }, status: :unprocessable_entity
        return
      end
    end

    # Create a new review request
    review_request = ReviewRequest.new(
      seller: seller,
      reason: params[:reason],
      status: 'pending',
      requested_at: Time.current
    )

    if review_request.save
      # Log the review request
      Rails.logger.info "Review request created for seller #{seller.id} (ID: #{review_request.id}): #{params[:reason]}"
      
      # TODO: Send notification to admin team
      # NotificationService.notify_admins_of_review_request(review_request)

      render json: { 
        message: 'Review request submitted successfully. Our team will review your account shortly.',
        review_request: {
          id: review_request.id,
          status: review_request.status,
          requested_at: review_request.requested_at
        }
      }, status: :created
    else
      render json: { 
        error: 'Failed to submit review request',
        errors: review_request.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def authenticate_seller
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_seller && @current_seller.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_seller
    @current_seller
  end
end

