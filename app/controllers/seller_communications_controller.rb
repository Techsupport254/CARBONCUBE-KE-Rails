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
        SellerCommunicationsMailer.general_update(seller).deliver_later
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

  def send_bulk_communication
    subject = params[:subject]
    body = params[:body]
    audience = params[:audience]
    user_ids = params[:user_ids]
    user_type = params[:user_type]
    channels = params[:channels] || { email: true, whatsapp: false }

    # Validate required parameters
    if subject.blank? || body.blank?
      render json: { error: 'Subject and body are required' }, status: :bad_request
      return
    end

    if channels[:email] == false && channels[:whatsapp] == false
      render json: { error: 'At least one communication channel must be selected' }, status: :bad_request
      return
    end

    if user_ids.present? && user_ids.is_a?(Array)
      # Send to specific users
      send_to_specific_users(user_ids, user_type, subject, body, channels)
    else
      # Send to audience (fallback to existing logic)
      send_to_audience(audience, subject, body, channels)
    end
  end

  private

  def send_to_specific_users(user_ids, user_type, subject, body, channels)
    # Determine model class based on user type
    model_class = case user_type
    when 'buyers'
      Buyer
    when 'sellers'
      Seller
    else
      Seller # Default to sellers
    end

    # Find users by IDs
    users = model_class.where(id: user_ids)
    users_count = users.count

    if users_count == 0
      render json: { error: 'No valid users found' }, status: :bad_request
      return
    end

    # Queue individual communication jobs for each user
    sent_count = 0
    users.each do |user|
      begin
        SendSellerCommunicationJob.perform_later(
          user.id,
          'general_update',
          channels,
          subject,
          body,
          user_type.singularize # Convert 'buyers'/'sellers' to 'buyer'/'seller'
        )
        sent_count += 1
      rescue => e
        Rails.logger.error "Failed to queue communication for user #{user.id}: #{e.message}"
      end
    end

    render json: {
      message: "Communication jobs queued for #{sent_count} #{user_type}",
      channels: channels,
      user_type: user_type,
      users_count: users_count,
      queued_count: sent_count,
      job_status: "queued"
    }
  end

  def send_to_audience(audience, subject, body, channels)
    # Build seller scope based on audience
    sellers_scope = case audience
    when 'active_sellers'
      Seller.where(deleted: [false, nil], blocked: [false, nil])
    when 'new_sellers'
      # Consider sellers created in the last 30 days as new
      Seller.where('created_at >= ?', 30.days.ago)
            .where(deleted: [false, nil], blocked: [false, nil])
    else # 'all_sellers'
      Seller.where(deleted: [false, nil])
    end

    sellers_count = sellers_scope.count

    # Queue the bulk communication job
    job = SendBulkSellerCommunicationJob.perform_later(
      'general_update',
      true, # auto_confirm
      channels,
      subject,
      body
    )

    render json: {
      message: "Bulk communication job queued for #{sellers_count} sellers",
      channels: channels,
      audience: audience,
      sellers_count: sellers_count,
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
