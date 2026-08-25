class Sales::DailyReportsController < ApplicationController
  before_action :authenticate_sales_user
  before_action :ensure_can_submit, only: %i[create parse_ai]
  before_action :set_report, only: %i[show update]

  # GET /sales/daily_reports/today
  # Returns status of today's daily report + check-in info for the active sales rep
  def today
    eat_today = FieldLocationRedisService.eat_today rescue Date.current
    is_holiday = SalesHoliday.non_working_day?(eat_today) rescue false
    holiday_name = SalesHoliday.exemption_name(eat_today) rescue nil

    report = SalesDailyReport.find_by(sales_user_id: @current_sales_user.id, report_date: eat_today)

    # Check if user has checked in today via location tracking
    redis_pings = FieldLocationRedisService.fetch_pings(@current_sales_user.id, eat_today) rescue []
    db_record = SalesUserFieldLocation.find_by(sales_user_id: @current_sales_user.id, check_in_date: eat_today)
    checked_in = redis_pings.any? || db_record.present?
    ping_count = redis_pings.size + (db_record&.pings&.size || 0)

    render json: {
      today: eat_today.iso8601,
      is_holiday: is_holiday,
      holiday_name: holiday_name,
      checked_in_today: is_holiday ? true : checked_in,
      ping_count: ping_count,
      has_submitted_report: report.present?,
      report: report ? serialize_report(report) : nil
    }
  end

  # POST /sales/daily_reports/parse_ai
  # AI endpoint to parse freeform text / WhatsApp message into structured fields + categories
  def parse_ai
    raw_text = params[:raw_text]
    result = SalesFieldReportAiService.parse_and_categorize(
      raw_text: raw_text,
      route_areas: params[:route_areas],
      visited: params[:businesses_visited],
      onboarded: params[:businesses_onboarded],
      challenges: params[:challenges],
      notes: params[:notes]
    )

    render json: { success: true, parsed: result }
  end

  # GET /sales/daily_reports/summary
  # Summary KPIs for leads and managers. Optionally scoped to a date range
  # via start_date/end_date params; otherwise defaults to today.
  def summary
    eat_today = FieldLocationRedisService.eat_today rescue Date.current
    start_date = params[:start_date].present? ? parse_report_date(params[:start_date]) : eat_today
    end_date = params[:end_date].present? ? parse_report_date(params[:end_date]) : start_date

    scoped_reports = if @current_sales_user.is_manager
                       SalesDailyReport.all
                     elsif @current_sales_user.is_lead
                       team_ids = [@current_sales_user.id] + @current_sales_user.team_members.pluck(:id)
                       SalesDailyReport.where(sales_user_id: team_ids)
                     else
                       SalesDailyReport.where(sales_user_id: @current_sales_user.id)
                     end

    selected_reports = scoped_reports.where(report_date: start_date..end_date)

    total_visited_today = selected_reports.sum(:businesses_visited)
    total_onboarded_today = selected_reports.sum(:businesses_onboarded)

    active_reps_scope = if @current_sales_user.is_manager
                          SalesUser.active.where(is_manager: false)
                        elsif @current_sales_user.is_lead
                          SalesUser.active.where(lead_id: @current_sales_user.id).or(SalesUser.where(id: @current_sales_user.id))
                        else
                          SalesUser.where(id: @current_sales_user.id)
                        end

    active_reps_count = active_reps_scope.count
    submitted_reps_count = selected_reports.count

    # Category insights within the selected range
    all_categories = selected_reports.pluck(:categories).flatten.compact
    category_counts = all_categories.tally

    render json: {
      today: eat_today.iso8601,
      start_date: start_date.iso8601,
      end_date: end_date.iso8601,
      total_visited_today: total_visited_today,
      total_onboarded_today: total_onboarded_today,
      active_reps_count: active_reps_count,
      submitted_reps_count: submitted_reps_count,
      pending_reps_count: [active_reps_count - submitted_reps_count, 0].max,
      category_breakdown: category_counts
    }
  end

  # GET /sales/daily_reports
  # List reports. Leads & managers see team reports; field reps see their own.
  def index
    page = [params[:page]&.to_i || 1, 1].max
    per_page = [params[:per_page]&.to_i || 20, 100].min

    if @current_sales_user.is_manager
      reports = SalesDailyReport.includes(:sales_user).recent
    elsif @current_sales_user.is_lead
      team_ids = [@current_sales_user.id] + @current_sales_user.team_members.pluck(:id)
      reports = SalesDailyReport.includes(:sales_user).where(sales_user_id: team_ids).recent
    else
      reports = SalesDailyReport.includes(:sales_user).where(sales_user_id: @current_sales_user.id).recent
    end
    
    if params[:sales_user_id].present? && (@current_sales_user.is_manager || @current_sales_user.is_lead)
      reports = reports.where(sales_user_id: params[:sales_user_id])
    end

    if params[:start_date].present?
      reports = reports.where('report_date >= ?', params[:start_date])
    end

    if params[:end_date].present?
      reports = reports.where('report_date <= ?', params[:end_date])
    end

    if params[:category].present?
      reports = reports.where('? = ANY(categories)', params[:category])
    end

    if params[:q].present?
      q = "%#{params[:q].strip.downcase}%"
      reports = reports.joins(:sales_user).where(
        'LOWER(sales_daily_reports.route_areas) LIKE :q OR LOWER(sales_daily_reports.challenges) LIKE :q OR LOWER(sales_daily_reports.notes) LIKE :q OR LOWER(sales_daily_reports.ai_summary) LIKE :q OR LOWER(sales_users.fullname) LIKE :q OR LOWER(sales_users.email) LIKE :q',
        q: q
      )
    end

    total = reports.count
    paginated = reports.offset((page - 1) * per_page).limit(per_page)

    render json: {
      reports: paginated.map { |r| serialize_report(r) },
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total,
        total_pages: (total.to_f / per_page).ceil,
        is_lead_or_manager: @current_sales_user.is_manager || @current_sales_user.is_lead
      }
    }
  end

  # GET /sales/daily_reports/:id
  def show
    render json: { report: serialize_report(@report) }
  end

  # POST /sales/daily_reports
  # Submit or update a daily report (upsert based on report_date)
  def create
    report_date = params[:report_date].presence || (FieldLocationRedisService.eat_today rescue Date.current)

    report = SalesDailyReport.find_or_initialize_by(
      sales_user_id: @current_sales_user.id,
      report_date: report_date
    )

    report.assign_attributes(
      route_areas: params[:route_areas].to_s.strip,
      businesses_visited: params[:businesses_visited].to_i,
      businesses_onboarded: params[:businesses_onboarded].to_i,
      challenges: params[:challenges]&.strip&.presence,
      notes: params[:notes]&.strip&.presence
    )

    # Perform AI Categorization & Extraction
    ai_data = SalesFieldReportAiService.parse_and_categorize(
      route_areas: report.route_areas,
      visited: report.businesses_visited,
      onboarded: report.businesses_onboarded,
      challenges: report.challenges,
      notes: report.notes
    )

    if ai_data
      passed_categories = params[:categories].is_a?(Array) ? params[:categories] : []
      report.categories = (passed_categories.presence || ai_data[:categories] || []).uniq
      report.ai_summary = ai_data[:ai_summary]
      report.sentiment = ai_data[:sentiment]
      report.urgency = ai_data[:urgency]
      report.action_items = ai_data[:action_items] || []
    end

    if report.save
      render json: {
        message: 'Daily field report submitted successfully',
        report: serialize_report(report)
      }, status: :created
    else
      render json: { errors: report.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT/PATCH /sales/daily_reports/:id
  def update
    attrs = {
      route_areas: params[:route_areas].to_s.strip,
      businesses_visited: params[:businesses_visited].to_i,
      businesses_onboarded: params[:businesses_onboarded].to_i,
      challenges: params[:challenges]&.strip&.presence,
      notes: params[:notes]&.strip&.presence
    }

    if params[:categories].is_a?(Array)
      attrs[:categories] = params[:categories].uniq
    end

    if (@current_sales_user.is_manager || @current_sales_user.is_lead) && params.key?(:verified_by_manager)
      attrs[:verified_by_manager] = params[:verified_by_manager]
    end

    # Re-run AI analysis if requested or challenges changed
    ai_data = SalesFieldReportAiService.parse_and_categorize(
      route_areas: attrs[:route_areas],
      visited: attrs[:businesses_visited],
      onboarded: attrs[:businesses_onboarded],
      challenges: attrs[:challenges],
      notes: attrs[:notes]
    )

    if ai_data
      attrs[:categories] = (attrs[:categories].presence || ai_data[:categories] || []).uniq
      attrs[:ai_summary] = ai_data[:ai_summary]
      attrs[:sentiment] = ai_data[:sentiment]
      attrs[:urgency] = ai_data[:urgency]
      attrs[:action_items] = ai_data[:action_items] || []
    end

    if @report.update(attrs)
      render json: {
        message: 'Daily field report updated successfully',
        report: serialize_report(@report)
      }, status: :ok
    else
      render json: { errors: @report.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /sales/daily_reports/onboarded_sellers_count?date=YYYY-MM-DD
  # Returns the number of sellers this sales user onboarded (via carbon codes) on a given date
  # plus the distinct seller locations for that date.
  def onboarded_sellers_count
    target_date = parse_report_date(params[:date])

    tz = ActiveSupport::TimeZone['Africa/Nairobi']
    start_time = tz.local(target_date.year, target_date.month, target_date.day).beginning_of_day
    end_time = tz.local(target_date.year, target_date.month, target_date.day).end_of_day

    carbon_code_ids = CarbonCode.where(associable: @current_sales_user).pluck(:id)
    sellers_scope = Seller.where(carbon_code_id: carbon_code_ids, deleted: false)
                          .where(created_at: start_time..end_time)
    count = sellers_scope.count
    locations = sellers_scope.pluck(:location).compact_blank.uniq

    render json: { count: count, locations: locations }
  end

  private

  def set_report
    if @current_sales_user.is_manager
      @report = SalesDailyReport.find(params[:id])
    elsif @current_sales_user.is_lead
      team_ids = [@current_sales_user.id] + @current_sales_user.team_members.pluck(:id)
      @report = SalesDailyReport.where(sales_user_id: team_ids).find(params[:id])
    else
      @report = SalesDailyReport.find_by!(id: params[:id], sales_user_id: @current_sales_user.id)
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Report not found' }, status: :not_found
  end

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    return if @current_sales_user

    render json: { error: 'Not Authorized' }, status: :unauthorized
  end

  def ensure_can_submit
    # Reps & Leads can submit/parse
  end

  def serialize_report(report)
    sales_user = report.sales_user
    {
      id: report.id,
      sales_user_id: report.sales_user_id,
      sales_user_name: sales_user&.fullname || sales_user&.email&.then { |email| email.split('@').first } || 'Sales Rep',
      sales_user_email: sales_user&.email,
      sales_user_phone: sales_user&.phone_number,
      report_date: report.report_date.iso8601,
      route_areas: report.route_areas,
      businesses_visited: report.businesses_visited,
      businesses_onboarded: report.businesses_onboarded,
      challenges: report.challenges,
      notes: report.notes,
      categories: report.categories || [],
      ai_summary: report.ai_summary,
      sentiment: report.sentiment,
      urgency: report.urgency,
      action_items: report.action_items || [],
      verified_by_manager: report.verified_by_manager,
      created_at: report.created_at.iso8601,
      updated_at: report.updated_at.iso8601
    }
  end

  def parse_report_date(date)
    date.present? ? Date.parse(date) : FieldLocationRedisService.eat_today
  rescue ArgumentError
    FieldLocationRedisService.eat_today
  end
end
