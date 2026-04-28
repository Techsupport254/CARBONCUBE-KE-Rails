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
    token = request.headers['Authorization']&.split(' ')&.last
    expected_token = ENV['ADMIN_API_TOKEN']

    unless token == expected_token
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
end
