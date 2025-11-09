class Sales::QuarterlyTargetsController < ApplicationController
  before_action :authenticate_sales_user

  # GET /sales/quarterly_targets
  def index
    targets = QuarterlyTarget.where(created_by_id: @current_sales_user.id)
                             .order(year: :desc, quarter: :desc, created_at: :desc)
    
    render json: {
      targets: targets.map { |t| format_target(t) }
    }
  end

  # GET /sales/quarterly_targets/current
  def current
    current_targets = {
      total_sellers: QuarterlyTarget.current_target_for('total_sellers'),
      total_buyers: QuarterlyTarget.current_target_for('total_buyers')
    }

    render json: {
      targets: {
        total_sellers: current_targets[:total_sellers] ? format_target(current_targets[:total_sellers]) : nil,
        total_buyers: current_targets[:total_buyers] ? format_target(current_targets[:total_buyers]) : nil
      }
    }
  end

  # POST /sales/quarterly_targets
  def create
    target = QuarterlyTarget.new(target_params)
    target.created_by = @current_sales_user
    target.status = 'pending'

    if target.save
      render json: { target: format_target(target) }, status: :created
    else
      render json: { errors: target.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /sales/quarterly_targets/:id
  def update
    target = QuarterlyTarget.find_by(id: params[:id], created_by_id: @current_sales_user.id)

    unless target
      render json: { error: 'Target not found' }, status: :not_found
      return
    end

    # Only allow updates if status is pending
    if target.status != 'pending'
      render json: { error: 'Cannot update target that has been approved or rejected' }, status: :unprocessable_entity
      return
    end

    if target.update(target_params)
      render json: { target: format_target(target) }
    else
      render json: { errors: target.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /sales/quarterly_targets/:id
  def destroy
    target = QuarterlyTarget.find_by(id: params[:id], created_by_id: @current_sales_user.id)

    unless target
      render json: { error: 'Target not found' }, status: :not_found
      return
    end

    # Only allow deletion if status is pending
    if target.status != 'pending'
      render json: { error: 'Cannot delete target that has been approved or rejected' }, status: :unprocessable_entity
      return
    end

    if target.destroy
      render json: { message: 'Target deleted successfully' }
    else
      render json: { errors: target.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def target_params
    params.require(:quarterly_target).permit(:metric_type, :year, :quarter, :target_value, :notes)
  end

  def format_target(target)
    {
      id: target.id,
      metric_type: target.metric_type,
      year: target.year,
      quarter: target.quarter,
      target_value: target.target_value,
      status: target.status,
      notes: target.notes,
      created_by: {
        id: target.created_by.id,
        email: target.created_by.email,
        fullname: target.created_by.fullname
      },
      approved_by: target.approved_by ? {
        id: target.approved_by.id,
        email: target.approved_by.email,
        fullname: target.approved_by.fullname
      } : nil,
      approved_at: target.approved_at&.iso8601,
      created_at: target.created_at.iso8601,
      updated_at: target.updated_at.iso8601
    }
  end

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end

