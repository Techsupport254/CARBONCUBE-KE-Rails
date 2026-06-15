require 'google/apis/analyticsdata_v1beta'
require 'googleauth'

class GoogleAnalyticsService
  PROPERTY_ID = ENV['GA4_PROPERTY_ID']

  def initialize
    @service = Google::Apis::AnalyticsdataV1beta::AnalyticsDataService.new
    @service.authorization = authorize
  end

  def sources_report(start_date: '30daysAgo', end_date: 'today')
    return empty_response unless PROPERTY_ID.present?

    property = "properties/#{PROPERTY_ID}"

    request = Google::Apis::AnalyticsdataV1beta::RunReportRequest.new(
      date_ranges: [
        Google::Apis::AnalyticsdataV1beta::DateRange.new(
          start_date: start_date,
          end_date: end_date
        )
      ],
      dimensions: [
        Google::Apis::AnalyticsdataV1beta::Dimension.new(name: 'sessionDefaultChannelGrouping')
      ],
      metrics: [
        Google::Apis::AnalyticsdataV1beta::Metric.new(name: 'sessions'),
        Google::Apis::AnalyticsdataV1beta::Metric.new(name: 'totalUsers'),
        Google::Apis::AnalyticsdataV1beta::Metric.new(name: 'newUsers')
      ]
    )

    response = @service.run_property_report(property, request)
    parse_sources_response(response)
  rescue Google::Apis::Error => e
    Rails.logger.error("GA4 API error: #{e.message}")
    empty_response.merge(error: e.message)
  rescue StandardError => e
    Rails.logger.error("GA4 service error: #{e.message}")
    empty_response.merge(error: e.message)
  end

  def totals_report(start_date: '30daysAgo', end_date: 'today')
    return empty_totals unless PROPERTY_ID.present?

    property = "properties/#{PROPERTY_ID}"

    request = Google::Apis::AnalyticsdataV1beta::RunReportRequest.new(
      date_ranges: [
        Google::Apis::AnalyticsdataV1beta::DateRange.new(
          start_date: start_date,
          end_date: end_date
        )
      ],
      metrics: [
        Google::Apis::AnalyticsdataV1beta::Metric.new(name: 'sessions'),
        Google::Apis::AnalyticsdataV1beta::Metric.new(name: 'totalUsers'),
        Google::Apis::AnalyticsdataV1beta::Metric.new(name: 'newUsers'),
        Google::Apis::AnalyticsdataV1beta::Metric.new(name: 'screenPageViews')
      ]
    )

    response = @service.run_property_report(property, request)
    parse_totals_response(response)
  rescue Google::Apis::Error => e
    Rails.logger.error("GA4 API error (totals): #{e.message}")
    empty_totals.merge(error: e.message)
  rescue StandardError => e
    Rails.logger.error("GA4 service error (totals): #{e.message}")
    empty_totals.merge(error: e.message)
  end

  private

  def authorize
    scope = 'https://www.googleapis.com/auth/analytics.readonly'

    if ENV['GA4_OAUTH_REFRESH_TOKEN'].present?
      # OAuth2 via personal Google admin account (refresh token flow)
      Google::Auth::UserRefreshCredentials.new(
        client_id: ENV['GA4_OAUTH_CLIENT_ID'],
        client_secret: ENV['GA4_OAUTH_CLIENT_SECRET'],
        refresh_token: ENV['GA4_OAUTH_REFRESH_TOKEN'],
        scope: scope
      )
    else
      # Service account via JSON file (preferred — avoids dotenv newline corruption)
      key_io = load_service_account_key_io
      Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: key_io,
        scope: scope
      )
    end
  end

  def load_service_account_key_io
    # 1. Dedicated credentials file (most reliable — no dotenv parsing issues)
    creds_file = Rails.root.join('config', 'ga4_credentials.json')
    return File.open(creds_file) if File.exist?(creds_file)

    # 2. ENV var — fix newlines that dotenv may have corrupted
    json_str = ENV['GA4_SERVICE_ACCOUNT_JSON'] || ENV['FIREBASE_SERVICE_ACCOUNT_JSON']
    raise "No GA4 credentials found. Add config/ga4_credentials.json or set GA4_SERVICE_ACCOUNT_JSON in .env" unless json_str.present?

    key_data = JSON.parse(json_str)
    key_data['private_key'] = key_data['private_key'].to_s.gsub('\n', "\n")
    StringIO.new(key_data.to_json)
  end

  def parse_sources_response(response)
    channel_distribution = {}
    total_sessions = 0
    total_users = 0
    total_new_users = 0

    return empty_response unless response&.rows.present?

    response.rows.each do |row|
      channel = row.dimension_values.first&.value || 'Unknown'
      sessions = row.metric_values[0]&.value.to_i
      users = row.metric_values[1]&.value.to_i
      new_users = row.metric_values[2]&.value.to_i

      channel_distribution[channel] = {
        sessions: sessions,
        users: users,
        new_users: new_users
      }

      total_sessions += sessions
      total_users += users
      total_new_users += new_users
    end

    top_channel = channel_distribution.max_by { |_, v| v[:sessions] }&.first

    {
      total_sessions: total_sessions,
      total_users: total_users,
      total_new_users: total_new_users,
      channel_distribution: channel_distribution,
      top_channel: top_channel,
      error: nil
    }
  end

  def parse_totals_response(response)
    return empty_totals unless response&.rows.present?

    row = response.rows.first
    {
      sessions: row.metric_values[0]&.value.to_i,
      users: row.metric_values[1]&.value.to_i,
      new_users: row.metric_values[2]&.value.to_i,
      page_views: row.metric_values[3]&.value.to_i,
      error: nil
    }
  end

  def empty_response
    {
      total_sessions: 0,
      total_users: 0,
      total_new_users: 0,
      channel_distribution: {},
      top_channel: nil,
      error: nil
    }
  end

  def empty_totals
    { sessions: 0, users: 0, new_users: 0, page_views: 0, error: nil }
  end
end
