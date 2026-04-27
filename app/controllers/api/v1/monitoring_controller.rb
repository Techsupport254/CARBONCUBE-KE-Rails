class Api::V1::MonitoringController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  # POST /api/v1/monitoring/errors
  def create_error
    begin
      error = MonitoringError.create!(
        message: params[:message],
        stack_trace: params[:stack_trace],
        level: params[:level] || 'error',
        context: params[:context] || {}
      )
      
      render json: { success: true, error_id: error.id }, status: :created
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/monitoring/metrics
  def create_metric
    begin
      metric = MonitoringMetric.create!(
        name: params[:name],
        value: params[:value],
        timestamp: params[:timestamp] ? Time.parse(params[:timestamp]) : Time.current,
        tags: params[:tags] || {}
      )
      
      render json: { success: true, metric_id: metric.id }, status: :created
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
