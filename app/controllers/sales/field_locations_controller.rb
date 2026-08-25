class Sales::FieldLocationsController < ApplicationController
  before_action :authenticate_sales_user
  before_action :ensure_not_manager

  # GET /sales/field_locations/status
  # Returns whether the user has pinged today, how many pings, and holiday info.
  # Checks Redis for live ping count (during the day) and Postgres for persisted data.
  def status
    today = FieldLocationRedisService.eat_today
    is_holiday = SalesHoliday.non_working_day?(today)
    holiday_name = SalesHoliday.exemption_name(today)

    # Check Redis for today's live pings
    redis_pings = FieldLocationRedisService.fetch_pings(@current_sales_user.id, today)
    # Check Postgres for a flushed record (from a previous day's sync)
    db_record = SalesUserFieldLocation.find_by(sales_user_id: @current_sales_user.id, check_in_date: today)

    checked_in = redis_pings.any? || db_record.present?
    ping_count = redis_pings.size + (db_record&.pings&.size || 0)

    render json: {
      checked_in_today: is_holiday ? true : checked_in,
      ping_count: ping_count,
      pings: redis_pings.map { |p| p.except('hour') },
      check_in: db_record&.as_json(only: %i[id latitude longitude display_name area city county country notes check_in_date created_at]),
      is_holiday: is_holiday,
      holiday_name: holiday_name,
      today: today.iso8601
    }
  end

  # GET /sales/field_locations/history
  # Returns recent check-ins (from Postgres — flushed data) for the current user
  def history
    limit = [params[:per_page]&.to_i || 30, 90].min
    check_ins = SalesUserFieldLocation
                  .where(sales_user_id: @current_sales_user.id)
                  .order(check_in_date: :desc)
                  .limit(limit)

    render json: {
      check_ins: check_ins.map do |c|
        c.as_json(only: %i[id latitude longitude display_name area city county country notes check_in_date created_at])
          .merge(ping_count: c.pings&.size || 0)
      end,
      total: check_ins.size
    }
  end

  # POST /sales/field_locations
  # Records an hourly location ping in Redis (not Postgres directly).
  # The frontend calls this every hour from 8am to 4pm.
  # SyncFieldLocationsJob flushes Redis → Postgres at 5pm EAT.
  def create
    today = FieldLocationRedisService.eat_today

    if SalesHoliday.non_working_day?(today)
      return render json: { error: 'No check-in required today' }, status: :bad_request
    end

    ping = {
      lat: params[:latitude],
      lng: params[:longitude],
      display_name: params[:display_name],
      address: params[:address] || {},
      area: params[:area],
      city: params[:city],
      county: params[:county],
      country: params[:country],
      notes: params[:notes]&.strip&.presence
    }

    if FieldLocationRedisService.add_ping(@current_sales_user.id, ping)
      ping_count = FieldLocationRedisService.fetch_pings(@current_sales_user.id, today).size
      render json: {
        message: 'Location ping recorded',
        ping_count: ping_count
      }, status: :created
    else
      # Either outside work hours, duplicate hour, or invalid data
      render json: {
        message: 'Ping not recorded (outside work hours or already pinged this hour)',
        ping_count: FieldLocationRedisService.fetch_pings(@current_sales_user.id, today).size
      }, status: :ok
    end
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    return if @current_sales_user

    render json: { error: 'Not Authorized' }, status: :unauthorized
  end

  # Managers are exempt from field location check-ins
  def ensure_not_manager
    return unless @current_sales_user&.is_manager

    render json: { error: 'Managers are not required to share field locations' }, status: :forbidden
  end
end
