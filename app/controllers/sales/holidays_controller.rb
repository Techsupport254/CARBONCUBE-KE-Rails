class Sales::HolidaysController < ApplicationController
  before_action :authenticate_sales_user

  # GET /sales/holidays
  # Returns upcoming holidays so the sales user can see which days are exempt
  def index
    today = Date.current
    holidays = SalesHoliday.where('date >= ? OR recurring = ?', today, true).order(date: :asc)
    render json: {
      holidays: holidays.map do |h|
        # For recurring holidays, compute the next occurrence
        next_date = if h.recurring
                      next_recurring_date(h.date, today)
                    else
                      h.date
                    end
        h.as_json(only: %i[id name recurring notes]).merge(date: next_date&.iso8601)
      end
    }
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    return if @current_sales_user

    render json: { error: 'Not Authorized' }, status: :unauthorized
  end

  def next_recurring_date(holiday_date, from)
    year = from.year
    candidate = Date.new(year, holiday_date.month, holiday_date.day)
    candidate = Date.new(year + 1, holiday_date.month, holiday_date.day) if candidate < from
    candidate
  rescue Date::Error
    nil
  end
end
