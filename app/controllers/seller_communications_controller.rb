class SellerCommunicationsController < ApplicationController
  before_action :authenticate_admin!

  def send_general_update
    seller_ids = params[:seller_ids] || []
    
    if seller_ids.empty?
      render json: { error: 'No sellers selected' }, status: :bad_request
      return
    end

    sellers = Seller.where(id: seller_ids)
    sent_count = 0

    sellers.each do |seller|
      begin
        SellerCommunicationsMailer.general_update(seller).deliver_now
        sent_count += 1
      rescue => e
        Rails.logger.error "Failed to send email to seller #{seller.id}: #{e.message}"
      end
    end

    render json: { 
      message: "General update email sent to #{sent_count} seller(s)",
      sent_count: sent_count,
      total_selected: sellers.count
    }
  end

  def send_to_test_seller
    test_seller = Seller.find_by(id: 114) || Seller.first
    
    if test_seller
      # Use the job for background processing
      SendSellerCommunicationJob.perform_later(test_seller.id, 'general_update')
      render json: { 
        message: "Test email job queued for #{test_seller.fullname} (#{test_seller.email})",
        seller: {
          id: test_seller.id,
          name: test_seller.fullname,
          email: test_seller.email
        },
        job_status: "queued"
      }
    else
      render json: { error: 'No test seller found' }, status: :not_found
    end
  end

  def send_bulk_emails
    # Queue the bulk email job
    job = SendBulkSellerCommunicationJob.perform_later('general_update')
    
    # Get count of active sellers for response
    active_sellers_count = Seller.where(
      deleted: [false, nil],
      blocked: [false, nil]
    ).count
    
    render json: { 
      message: "Bulk email job queued for #{active_sellers_count} active sellers",
      active_sellers_count: active_sellers_count,
      job_id: job.job_id,
      job_status: "queued"
    }
  end

  private

  def authenticate_admin!
    # Add your admin authentication logic here
    # This should check if the current user is an admin
  end
end
