# frozen_string_literal: true

# Sends a weekly onboarding summary email to every sales user every Wednesday at 7:00 AM EAT.
# Non-manager/lead users receive their own onboarded sellers from the past 7 days.
# Managers and leads receive their own sellers plus a team-wide leaderboard and full list, plus a PDF attachment.
class WeeklySellerOnboardingSummaryJob < ApplicationJob
  queue_as :low

  LOOKBACK_DAYS = 7

  # @param base_time [Time, String, nil] optional override for the "now" used to calculate the window (defaults to EAT now)
  def perform(base_time = nil)
    base_time = Time.parse(base_time.to_s) if base_time.present?
    base_time ||= Time.current.in_time_zone('Africa/Nairobi')

    window_start = (base_time - LOOKBACK_DAYS.days).beginning_of_day
    window_end = base_time

    # All carbon-code assignments in the past 7 days, eager-loaded
    weekly_assignments = SellerCarbonCodeAssignment
                           .includes(:seller, :sales_user)
                           .where(created_at: window_start..window_end)
                           .order(created_at: :desc)

    sellers_by_sales_user = {}
    team_summary = Hash.new(0)
    all_team_sellers = []

    weekly_assignments.each do |assignment|
      seller = assignment.seller
      next if seller.nil?

      user = assignment.sales_user
      next if user.nil?

      seller_data = build_seller_data(seller, assignment, user)
      all_team_sellers << seller_data

      sellers_by_sales_user[user.id] ||= []
      sellers_by_sales_user[user.id] << seller_data

      team_summary[user] += 1
    end

    # All-time totals per sales user
    all_time_counts = SellerCarbonCodeAssignment
                        .group(:sales_user_id)
                        .count

    team_summary_array = team_summary
                           .sort_by { |_, count| -count }
                           .map do |user, count|
      {
        fullname: user.fullname.presence || user.email.to_s.split('@').first,
        email: user.email,
        count: count,
        currentTotal: all_time_counts[user.id] || 0
      }
    end

    team_current_total = all_time_counts.values.sum

    # Build one PDF for the team; only managers/leads get it attached
    team_pdf = build_team_pdf(window_start, window_end, team_summary_array, all_team_sellers, team_current_total)

    SalesUser.find_each do |sales_user|
      personal_sellers = sellers_by_sales_user[sales_user.id] || []
      personal_count = personal_sellers.size
      personal_current_total = all_time_counts[sales_user.id] || 0
      is_manager_or_lead = sales_user.is_manager || sales_user.is_lead

      # Leads and managers get the full team view; regular sales users only get their own data
      summary_for_email = is_manager_or_lead ? team_summary_array : []
      all_sellers_for_email = is_manager_or_lead ? all_team_sellers : []
      team_total_for_email = is_manager_or_lead ? all_team_sellers.size : 0

      SalesMailer.weekly_onboarding_summary(
        sales_user,
        window_start,
        window_end,
        personal_sellers,
        personal_count,
        personal_current_total,
        summary_for_email,
        all_sellers_for_email,
        team_total_for_email,
        is_manager_or_lead ? team_current_total : 0,
        is_manager_or_lead,
        is_manager_or_lead ? team_pdf : nil
      ).deliver_later
    end
  end

  private

  def build_seller_data(seller, assignment, sales_user)
    {
      id: seller.id,
      fullname: seller.fullname,
      enterpriseName: seller.enterprise_name,
      email: seller.email,
      phoneNumber: seller.phone_number,
      profilePicture: seller.profile_picture,
      location: seller.location,
      city: seller.city,
      createdAt: assignment.created_at.iso8601,
      assignedBy: sales_user.fullname.presence || sales_user.email.to_s.split('@').first
    }
  end

  # Build a landscape PDF report of the week's team onboardings.
  # PDF is generated once and attached to all manager/lead emails.
  def build_team_pdf(window_start, window_end, team_summary, all_team_sellers, team_current_total)
    require 'prawn'
    require 'prawn/table'

    pdf = Prawn::Document.new(page_layout: :landscape)
    pdf.font 'Helvetica'

    start_str = window_start.to_date.to_s
    end_str = window_end.to_date.to_s

    pdf.text 'Weekly Onboarding Summary', size: 20, style: :bold
    pdf.text "#{start_str} to #{end_str}", size: 12, color: '666666'
    pdf.move_down 10

    pdf.text "Team total (this week): #{all_team_sellers.size}    All-time: #{team_current_total}", size: 11
    pdf.move_down 20

    # Team leaderboard
    pdf.text 'Team Leaderboard', size: 14, style: :bold
    pdf.move_down 5

    leaderboard_data = [['Rank', 'Sales User', 'This Week', 'All-Time']]
    team_summary.each_with_index do |member, i|
      leaderboard_data << [i + 1, sanitize(member[:fullname]), member[:count], member[:currentTotal]]
    end

    if leaderboard_data.size > 1
      pdf.table(leaderboard_data, header: true, width: 400) do
        row(0).font_style = :bold
        row(0).background_color = 'F59E0B'
        row(0).text_color = 'FFFFFF'
        cells.padding = [5, 5]
        cells.size = 10
      end
    else
      pdf.text 'No team onboardings this week.', size: 10, color: '666666'
    end

    pdf.move_down 20

    # All team onboardings
    pdf.text 'All Team Onboardings', size: 14, style: :bold
    pdf.move_down 5

    if all_team_sellers.empty?
      pdf.text 'No onboardings this week.', size: 10, color: '666666'
    else
      onboardings_data = [['Date', 'Company / Name', 'Email', 'Phone', 'Location', 'Onboarded By']]
      all_team_sellers.each do |s|
        onboardings_data << [
          format_pdf_date(s[:createdAt]),
          sanitize(s[:enterpriseName] || s[:fullname]),
          sanitize(s[:email]),
          sanitize(s[:phoneNumber]),
          sanitize([s[:location], s[:city]].compact.join(', ')),
          sanitize(s[:assignedBy])
        ]
      end

      pdf.table(onboardings_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = 'F59E0B'
        row(0).text_color = 'FFFFFF'
        cells.padding = [5, 5]
        cells.size = 9
      end
    end

    pdf.render
  end

  def sanitize(text)
    text.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  end

  def format_pdf_date(iso_string)
    Time.parse(iso_string).strftime('%Y-%m-%d')
  rescue
    iso_string.to_s
  end
end
