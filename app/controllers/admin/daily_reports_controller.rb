class Admin::DailyReportsController < ApplicationController
  before_action :authenticate_admin

  # GET /admin/daily_reports
  def index
    page = [params[:page]&.to_i || 1, 1].max
    per_page = [params[:per_page]&.to_i || 25, 100].min

    reports = SalesDailyReport.includes(:sales_user).recent

    if params[:sales_user_id].present?
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
      reports: paginated.map { |r| serialize_admin_report(r) },
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total,
        total_pages: (total.to_f / per_page).ceil
      }
    }
  end

  # GET /admin/daily_reports/summary
  def summary
    today = FieldLocationRedisService.eat_today rescue Date.current
    today_reports = SalesDailyReport.where(report_date: today)

    total_visited_today = today_reports.sum(:businesses_visited)
    total_onboarded_today = today_reports.sum(:businesses_onboarded)
    active_reps_count = SalesUser.active.where(is_manager: false).count
    submitted_reps_count = today_reports.count

    all_categories = SalesDailyReport.where('report_date >= ?', today - 30.days).pluck(:categories).flatten.compact
    category_counts = all_categories.each_with_object(Hash.new(0)) { |cat, h| h[cat] += 1 }

    render json: {
      today: today.iso8601,
      total_visited_today: total_visited_today,
      total_onboarded_today: total_onboarded_today,
      active_reps_count: active_reps_count,
      submitted_reps_count: submitted_reps_count,
      pending_reps_count: [active_reps_count - submitted_reps_count, 0].max,
      category_breakdown: category_counts
    }
  end

  private

  def authenticate_admin
    @current_admin = AdminAuthorizeApiRequest.new(request.headers).result
    return if @current_admin

    render json: { error: 'Not Authorized' }, status: :unauthorized
  end

  def serialize_admin_report(r)
    sales_user = r.sales_user
    {
      id: r.id,
      sales_user_id: r.sales_user_id,
      sales_user_name: sales_user&.fullname || sales_user&.email&.split('@')&.first || 'Sales Rep',
      sales_user_email: sales_user&.email,
      sales_user_phone: sales_user&.phone_number,
      report_date: r.report_date.iso8601,
      route_areas: r.route_areas,
      businesses_visited: r.businesses_visited,
      businesses_onboarded: r.businesses_onboarded,
      challenges: r.challenges,
      notes: r.notes,
      categories: r.categories || [],
      ai_summary: r.ai_summary,
      sentiment: r.sentiment,
      urgency: r.urgency,
      action_items: r.action_items || [],
      verified_by_manager: r.verified_by_manager,
      created_at: r.created_at.iso8601,
      updated_at: r.updated_at.iso8601
    }
  end
end
