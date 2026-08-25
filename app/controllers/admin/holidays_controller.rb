class Admin::HolidaysController < ApplicationController
  before_action :authenticate_admin

  # GET /admin/holidays
  def index
    holidays = SalesHoliday.order(date: :asc)
    render json: { holidays: holidays.as_json(only: %i[id name date recurring notes created_at]) }
  end

  # POST /admin/holidays
  def create
    holiday = SalesHoliday.new(
      name: params[:name]&.strip,
      date: params[:date],
      recurring: params[:recurring].to_s == 'true',
      notes: params[:notes]&.strip&.presence
    )

    if holiday.save
      render json: { message: 'Holiday created successfully', holiday: holiday.as_json(only: %i[id name date recurring notes created_at]) }, status: :created
    else
      render json: { error: 'Validation failed', errors: holiday.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /admin/holidays/:id
  def destroy
    holiday = SalesHoliday.find_by(id: params[:id])
    return render json: { error: 'Holiday not found' }, status: :not_found unless holiday

    holiday.destroy
    render json: { message: 'Holiday deleted successfully' }
  end

  private

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    return if @current_user.is_a?(Admin)

    render json: { error: 'Not Authorized' }, status: :unauthorized
  end
end
