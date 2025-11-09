class Admin::QuarterlyTargetsController < ApplicationController
  before_action :authenticate_admin

  # GET /admin/quarterly_targets
  def index
    status_filter = params[:status] # pending, approved, rejected, or all
    targets = QuarterlyTarget.all

    if status_filter.present? && %w[pending approved rejected].include?(status_filter)
      targets = targets.where(status: status_filter)
    end

    targets = targets.order(year: :desc, quarter: :desc, created_at: :desc)

    render json: {
      targets: targets.map { |t| format_target(t) }
    }
  end

  # GET /admin/quarterly_targets/pending
  def pending
    targets = QuarterlyTarget.pending.order(year: :desc, quarter: :desc, created_at: :desc)

    render json: {
      targets: targets.map { |t| format_target(t) }
    }
  end

  # PATCH/PUT /admin/quarterly_targets/:id/approve
  def approve
    target = QuarterlyTarget.find(params[:id])

    if target.approve!(@current_admin)
      render json: { target: format_target(target), message: 'Target approved successfully' }
    else
      render json: { errors: target.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/quarterly_targets/:id/reject
  def reject
    target = QuarterlyTarget.find(params[:id])
    notes = params[:notes] || params.dig(:quarterly_target, :notes) || params[:rejection_notes]

    if target.reject!(@current_admin, notes: notes)
      render json: { target: format_target(target), message: 'Target rejected successfully' }
    else
      render json: { errors: target.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

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

  def authenticate_admin
    @current_admin = AuthorizeApiRequest.new(request.headers).result
    unless @current_admin && @current_admin.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end

