class SalesMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  # Weekly onboarding summary for sales users.
  #
  # @param sales_user [SalesUser] the recipient
  # @param start_date [Time] beginning of the 7-day lookback window
  # @param end_date [Time] end of the 7-day lookback window
  # @param personal_sellers [Array<Hash>] sellers onboarded by the recipient this week
  # @param personal_count [Integer] number of sellers the recipient onboarded this week
  # @param personal_current_total [Integer] total sellers the recipient has onboarded to date
  # @param team_summary [Array<Hash>] { fullname, email, count, currentTotal } for all sales users
  # @param all_team_sellers [Array<Hash>] all sellers onboarded by any sales user this week
  # @param team_total [Integer] number of sellers the team onboarded this week
  # @param team_current_total [Integer] total sellers the team has onboarded to date
  # @param is_manager_or_lead [Boolean] whether the recipient sees team data
  # @param pdf_content [String, nil] PDF bytes for managers and leads
  def weekly_onboarding_summary(
    sales_user,
    start_date,
    end_date,
    personal_sellers,
    personal_count,
    personal_current_total,
    team_summary,
    all_team_sellers,
    team_total,
    team_current_total,
    is_manager_or_lead,
    pdf_content = nil
  )
    @recipient_name = sales_user.fullname.presence || sales_user.email.to_s.split('@').first
    @start_date = start_date.to_date
    @end_date = end_date.to_date
    @personal_sellers = personal_sellers
    @personal_count = personal_count
    @personal_current_total = personal_current_total
    @team_summary = team_summary
    @all_team_sellers = all_team_sellers
    @team_total = team_total
    @team_current_total = team_current_total
    @is_manager_or_lead = is_manager_or_lead
    @dashboard_url = UtmUrlHelper.append_utm(
      'https://carboncube-ke.com/sales/dashboard',
      source: 'email',
      medium: 'sales_onboarding',
      campaign: 'weekly_summary',
      content: 'dashboard'
    )

    if pdf_content.present?
      decoded = begin
        Base64.strict_decode64(pdf_content)
      rescue ArgumentError
        pdf_content
      end
      date_str = @end_date.to_s
      attachments["weekly_onboarding_summary_#{date_str}.pdf"] = { mime_type: 'application/pdf', content: decoded }
    end

    subject_prefix = is_manager_or_lead ? 'Team Onboarding' : 'Your Onboarding'

    mail(
      to: sales_user.email,
      subject: "#{subject_prefix} Summary: #{@start_date.strftime('%b %d')}–#{@end_date.strftime('%b %d')}",
      react: {
        recipient_name: @recipient_name,
        start_date: @start_date.to_s,
        end_date: @end_date.to_s,
        personal_sellers: @personal_sellers,
        personal_count: @personal_count,
        personal_current_total: @personal_current_total,
        team_summary: @team_summary,
        all_team_sellers: @all_team_sellers,
        team_total: @team_total,
        team_current_total: @team_current_total,
        is_manager_or_lead: @is_manager_or_lead,
        dashboard_url: @dashboard_url
      }
    )
  end
end
