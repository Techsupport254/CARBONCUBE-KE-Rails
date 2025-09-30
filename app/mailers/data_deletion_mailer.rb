class DataDeletionMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  # Send data deletion request notification to admin
  def admin_notification
    @deletion_request = params[:deletion_request]
    @name = @deletion_request.full_name
    @email = @deletion_request.email
    @phone = @deletion_request.phone
    @account_type = @deletion_request.account_type
    @reason = @deletion_request.reason
    @token = @deletion_request.token
    @timestamp = @deletion_request.requested_at.strftime("%B %d, %Y at %I:%M %p")

    mail(
      to: ENV['ADMIN_EMAIL'] || 'info@carboncube-ke.com',
      subject: "New Data Deletion Request - #{@account_type.capitalize} Account",
      reply_to: @email
    )
  end

  # Send confirmation email to user
  def user_confirmation
    @deletion_request = params[:deletion_request]
    @name = @deletion_request.full_name
    @email = @deletion_request.email
    @account_type = @deletion_request.account_type
    @token = @deletion_request.token
    @timestamp = @deletion_request.requested_at.strftime("%B %d, %Y at %I:%M %p")

    mail(
      to: @email,
      subject: "Data Deletion Request Received - Carbon Cube Kenya"
    )
  end

  # Send status update to user
  def status_update
    @deletion_request = params[:deletion_request]
    @name = @deletion_request.full_name
    @email = @deletion_request.email
    @status = @deletion_request.status
    @token = @deletion_request.token
    @timestamp = Time.current.strftime("%B %d, %Y at %I:%M %p")

    mail(
      to: @email,
      subject: "Data Deletion Request Update - #{@status.capitalize}"
    )
  end
end
