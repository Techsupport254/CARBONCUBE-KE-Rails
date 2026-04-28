class AutomationController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_around_action :track_request_performance
  before_action :authenticate_automation

  # POST /automation/trigger_friday_seller_checkpoint
  def trigger_friday_seller_checkpoint
    output = `RAILS_ENV=#{Rails.env} bin/rails admin:friday_seller_checkpoint 2>&1`
    success = $?.success?

    if success
      render json: {
        status: 'success',
        message: 'Friday seller checkpoint executed successfully',
        output: output
      }, status: :ok
    else
      render json: {
        status: 'error',
        message: 'Failed to execute Friday seller checkpoint',
        output: output
      }, status: :internal_server_error
    end
  rescue => e
    render json: {
      status: 'error',
      message: 'Failed to execute Friday seller checkpoint',
      output: e.message
    }, status: :internal_server_error
  end

  private

  def authenticate_automation
    # Try different header name formats
    token = request.headers['Authorization']&.split(' ')&.last
    token ||= request.headers['HTTP_AUTHORIZATION']&.split(' ')&.last
    token ||= request.headers['authorization']&.split(' ')&.last

    expected_token = ENV['ADMIN_API_TOKEN']

    # Log for debugging (remove in production)
    Rails.logger.info "Automation auth - Token present: #{token.present?}, Expected: #{expected_token.present?}"

    unless token == expected_token
      Rails.logger.error "Automation auth failed - Token: #{token&.first(10)}..., Expected: #{expected_token&.first(10)}..."
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
end
