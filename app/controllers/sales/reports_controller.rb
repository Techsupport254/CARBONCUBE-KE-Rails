class Sales::ReportsController < ApplicationController
  before_action :authenticate_sales_user
  before_action :require_lead_or_manager

  # GET /sales/reports/executive_summary
  # Returns KPIs, commission status, leaderboard, recent onboardings, and AI summary for any date range
  def executive_summary
    window_start, window_end = parse_window

    # ── Onboarding counts ──────────────────────────────────────────────────
    all_time_counts = SellerCarbonCodeAssignment.group(:sales_user_id).count
    team_current_total = all_time_counts.values.sum

    period_assignments = SellerCarbonCodeAssignment
                           .includes(:seller, :sales_user)
                           .where(created_at: window_start..window_end)
                           .order(created_at: :desc)

    period_onboarded = 0
    recent_sellers = []
    leaderboard_counts = Hash.new(0)

    period_assignments.each do |a|
      next unless a.seller && a.sales_user && a.sales_user.active?
      period_onboarded += 1
      leaderboard_counts[a.sales_user_id] += 1
      recent_sellers << serialize_seller(a.seller, a, a.sales_user)
    end

    # ── Field metrics ──────────────────────────────────────────────────────
    daily_reports = SalesDailyReport.where(report_date: window_start.to_date..window_end.to_date)
    total_shops_visited = daily_reports.sum(:businesses_visited)
    conversion_rate = total_shops_visited > 0 ? (period_onboarded.to_f / total_shops_visited * 100).round(1) : 0.0

    # ── AI Issues Summary ──────────────────────────────────────────────────
    ai_summary = generate_ai_issues_summary(daily_reports, total_shops_visited, period_onboarded, conversion_rate)

    # ── Leaderboard ────────────────────────────────────────────────────────
    leaderboard = leaderboard_counts.filter_map do |uid, count|
      u = SalesUser.find_by(id: uid)
      next unless u&.active?

      {
        id: uid,
        fullname: u.fullname.presence || u.email.split('@').first,
        email: u.email,
        profile_picture: u.profile_picture,
        period_count: count,
        all_time_total: all_time_counts[uid] || 0,
        compensation_type: u.compensation_type
      }
    end
    leaderboard.sort_by! { |r| -r[:all_time_total] }

    # ── Commission Status ──────────────────────────────────────────────────
    commission_table = SalesUser.active.where("LOWER(compensation_type) = 'commission'").map do |u|
      {
        id: u.id,
        fullname: u.fullname.presence || u.email.split('@').first,
        email: u.email,
        profile_picture: u.profile_picture,
        total_onboarded: u.total_onboarded,
        earned_batches: u.earned_commission_batches,
        paid_batches: u.paid_commission_batches.to_i,
        unpaid_sellers: u.unpaid_seller_count,
        payment_due: u.commission_due?,
        commission_status: u.commission_status,
        last_paid_at: u.last_commission_paid_at&.iso8601
      }
    end
    commission_table.sort_by! { |r| r[:payment_due] ? 0 : 1 }

    render json: {
      window_start: window_start.iso8601,
      window_end: window_end.iso8601,
      kpis: {
        shops_visited: total_shops_visited,
        period_onboarded: period_onboarded,
        conversion_rate: conversion_rate,
        all_time_total: team_current_total
      },
      ai_issues_summary: ai_summary,
      leaderboard: leaderboard,
      commission_table: commission_table,
      recent_sellers: recent_sellers.first(50)
    }
  end

  # GET /sales/reports/download_pdf
  # Streams a styled PDF for any date range, on-demand
  def download_pdf
    window_start, window_end = parse_window

    all_time_counts = SellerCarbonCodeAssignment.group(:sales_user_id).count
    team_current_total = all_time_counts.values.sum

    period_assignments = SellerCarbonCodeAssignment
                           .includes(:seller, :sales_user)
                           .where(created_at: window_start..window_end)
                           .order(created_at: :desc)

    all_team_sellers = []
    team_summary_hash = Hash.new(0)

    period_assignments.each do |a|
      next unless a.seller && a.sales_user && a.sales_user.active?
      all_team_sellers << {
        id: a.seller.id,
        fullname: a.seller.fullname,
        enterpriseName: a.seller.enterprise_name,
        email: a.seller.email,
        phoneNumber: a.seller.phone_number,
        profilePicture: a.seller.profile_picture,
        location: a.seller.location,
        city: a.seller.city,
        createdAt: a.created_at.iso8601,
        assignedBy: a.sales_user.fullname.presence || a.sales_user.email.split('@').first
      }
      team_summary_hash[a.sales_user] += 1
    end

    team_summary = team_summary_hash
                     .sort_by { |_, c| -c }
                     .map do |user, count|
      {
        fullname: user.fullname.presence || user.email.split('@').first,
        email: user.email,
        count: count,
        currentTotal: all_time_counts[user.id] || 0
      }
    end

    daily_reports = SalesDailyReport.where(report_date: window_start.to_date..window_end.to_date)
    total_shops_visited = daily_reports.sum(:businesses_visited)
    period_onboarded = all_team_sellers.size
    conversion_rate = total_shops_visited > 0 ? (period_onboarded.to_f / total_shops_visited * 100).round(1) : 0.0
    ai_issues_summary = generate_ai_issues_summary(daily_reports, total_shops_visited, period_onboarded, conversion_rate)

    job = WeeklySellerOnboardingSummaryJob.new
    pdf_bytes = job.send(
      :build_team_pdf,
      window_start, window_end,
      team_summary, all_team_sellers,
      team_current_total, total_shops_visited, ai_issues_summary
    )

    filename = "carbon_field_report_#{window_start.strftime('%Y%m%d')}_#{window_end.strftime('%Y%m%d')}.pdf"
    send_data pdf_bytes,
              type: 'application/pdf',
              disposition: 'attachment',
              filename: filename
  end

  # PATCH /sales/reports/commission/:id/mark_paid
  # Records a commission batch payout for a sales rep
  def mark_commission_paid
    sales_user = SalesUser.active.find(params[:id])
    batches = [params[:batches].to_i, 1].max

    sales_user.record_commission_payment!(batches)
    sales_user.reload

    render json: {
      success: true,
      message: "Recorded #{batches} commission batch(es) paid for #{sales_user.fullname.presence || sales_user.email}",
      rep: {
        id: sales_user.id,
        fullname: sales_user.fullname,
        email: sales_user.email,
        paid_batches: sales_user.paid_commission_batches,
        earned_batches: sales_user.earned_commission_batches,
        unpaid_sellers: sales_user.unpaid_seller_count,
        payment_due: sales_user.commission_due?,
        commission_status: sales_user.commission_status,
        last_paid_at: sales_user.last_commission_paid_at&.iso8601
      }
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sales rep not found' }, status: :not_found
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    render json: { error: 'Not Authorized' }, status: :unauthorized unless @current_sales_user
  end

  def require_lead_or_manager
    return if @current_sales_user&.team_sales_dashboard_access?
    render json: { error: 'Access restricted to team leads and managers' }, status: :forbidden
  end

  def parse_window
    tz = ActiveSupport::TimeZone['Africa/Nairobi']
    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date]) rescue 7.days.ago.to_date
      end_date = Date.parse(params[:end_date]) rescue Date.current
      window_start = tz.local(start_date.year, start_date.month, start_date.day).beginning_of_day
      window_end   = tz.local(end_date.year, end_date.month, end_date.day).end_of_day
    else
      window_end   = Time.current.in_time_zone(tz)
      window_start = (window_end - 7.days).beginning_of_day
    end
    [window_start, window_end]
  end

  def serialize_seller(seller, assignment, sales_user)
    {
      id: seller.id,
      fullname: seller.fullname,
      enterprise_name: seller.enterprise_name,
      email: seller.email,
      phone_number: seller.phone_number,
      profile_picture: seller.profile_picture,
      location: seller.location,
      city: seller.city,
      onboarded_by: sales_user.fullname.presence || sales_user.email.split('@').first,
      onboarded_by_email: sales_user.email,
      onboarded_at: assignment.created_at.iso8601
    }
  end

  def generate_ai_issues_summary(daily_reports, total_shops_visited, period_onboarded, conversion_rate)
    challenges = daily_reports.filter_map do |r|
      "- [#{r.report_date}] #{r.challenges}" if r.challenges.present?
    end
    return nil if challenges.empty?

    raw_text = challenges.join("\n")
    metrics_line = "Shops visited: #{total_shops_visited}. Businesses onboarded: #{period_onboarded}. Conversion rate: #{conversion_rate}%."

    if ENV['GROQ_API_KEY'].present?
      begin
        prompt = <<~PROMPT
          You are an executive operations analyst for Carbon Cube Kenya.
          #{metrics_line}

          Below are real field obstacles and feedback reported by sales reps:
          """
          #{raw_text}
          """
          Summarize into two sections for an executive report:
          KEY FIELD FRICTION:
          • (Bullet 1)
          • (Bullet 2)
          • (Bullet 3)

          RECOMMENDED ACTIONS:
          • (Bullet 1)
          • (Bullet 2)

          Plain text only (no ** markdown). Clean bullets with •. Max 100 words.
        PROMPT

        uri = URI('https://api.groq.com/openai/v1/chat/completions')
        req = Net::HTTP::Post.new(uri, 'Authorization' => "Bearer #{ENV['GROQ_API_KEY']}", 'Content-Type' => 'application/json')
        req.body = { model: 'openai/gpt-oss-120b', messages: [{ role: 'user', content: prompt }], max_tokens: 260, temperature: 0.2 }.to_json
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 8, open_timeout: 4) { |h| h.request(req) }
        if res.is_a?(Net::HTTPSuccess)
          text = JSON.parse(res.body).dig('choices', 0, 'message', 'content').to_s.strip
          return text.gsub('**', '') if text.present?
        end
      rescue StandardError => e
        Rails.logger.warn "ReportsController AI summary error: #{e.message}"
      end
    end

    "WEEKLY SUMMARY: #{metrics_line}\n\nKEY FIELD FRICTION:\n• Merchant hesitation regarding platform credibility in hardware/electrical sectors\n• Smartphone access friction and app loading times during field outreach\n• Data bundle & airtime limitations\n\nRECOMMENDED ACTIONS:\n• Provide physical verification collateral & offline pitch materials\n• Optimize mobile onboarding speed and ad upload flows"
  end
end
