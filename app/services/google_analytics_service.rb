require 'google/apis/analyticsdata_v1beta'
require 'googleauth'

class GoogleAnalyticsService
  PROPERTY_ID = ENV['GA4_PROPERTY_ID']

  def initialize
    @service = Google::Apis::AnalyticsdataV1beta::AnalyticsDataService.new
    @service.authorization = authorize
  end

  def sources_report(start_date: '2024-10-07', end_date: 'today')
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

  def sources_by_source_report(start_date: '2024-10-07', end_date: 'today')
    return empty_source_breakdown unless PROPERTY_ID.present?

    property = "properties/#{PROPERTY_ID}"

    request = Google::Apis::AnalyticsdataV1beta::RunReportRequest.new(
      date_ranges: [
        Google::Apis::AnalyticsdataV1beta::DateRange.new(
          start_date: start_date,
          end_date: end_date
        )
      ],
      dimensions: [
        Google::Apis::AnalyticsdataV1beta::Dimension.new(name: 'sessionSource')
      ],
      metrics: [
        Google::Apis::AnalyticsdataV1beta::Metric.new(name: 'sessions'),
        Google::Apis::AnalyticsdataV1beta::Metric.new(name: 'totalUsers'),
        Google::Apis::AnalyticsdataV1beta::Metric.new(name: 'newUsers')
      ],
      order_bys: [
        Google::Apis::AnalyticsdataV1beta::OrderBy.new(
          metric: Google::Apis::AnalyticsdataV1beta::MetricOrderBy.new(metric_name: 'sessions'),
          desc: true
        )
      ],
      limit: 20
    )

    response = @service.run_property_report(property, request)
    parse_source_breakdown_response(response)
  rescue Google::Apis::Error => e
    Rails.logger.error("GA4 API error (source breakdown): #{e.message}")
    empty_source_breakdown.merge(error: e.message)
  rescue StandardError => e
    Rails.logger.error("GA4 service error (source breakdown): #{e.message}")
    empty_source_breakdown.merge(error: e.message)
  end

  def totals_report(start_date: '2024-10-07', end_date: 'today')
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
    json_str = ENV['GOOGLE_SERVICE_ACCOUNT_JSON']
    raise "No GA4 credentials found. Add config/ga4_credentials.json or set GOOGLE_SERVICE_ACCOUNT_JSON in .env" unless json_str.present?

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

  SOURCE_NORMALIZATION = {
    # Facebook variants
    'facebook'       => 'Facebook',
    'facebook.com'   => 'Facebook',
    'm.facebook.com' => 'Facebook',
    'l.facebook.com' => 'Facebook',
    'lm.facebook.com'=> 'Facebook',
    'fb'             => 'Facebook',
    'fb.com'         => 'Facebook',
    # Instagram variants
    'instagram'      => 'Instagram',
    'instagram.com'  => 'Instagram',
    'l.instagram.com'=> 'Instagram',
    'ig'             => 'Instagram',
    # Google variants
    'google'         => 'Google',
    'google.com'     => 'Google',
    'accounts.google.com' => 'Google',
    'cpc'            => 'Google',
    # WhatsApp variants
    'whatsapp'       => 'WhatsApp',
    'whatsapp.com'   => 'WhatsApp',
    'wa.me'          => 'WhatsApp',
    # LinkedIn variants
    'linkedin'       => 'LinkedIn',
    'linkedin.com'   => 'LinkedIn',
    'lnkd.in'        => 'LinkedIn',
    # TikTok variants
    'tiktok'         => 'TikTok',
    'tiktok.com'     => 'TikTok',
    't.co'           => 'Twitter/X',
    'twitter.com'    => 'Twitter/X',
    'x.com'          => 'Twitter/X',
    # Email
    'email'          => 'Email',
    'mail'           => 'Email',
    # Direct / unknown
    '(direct)'       => 'Direct',
    '(not set)'      => 'Other',
    '(data not available)' => 'Other',
  }.freeze

  def normalize_source(raw)
    SOURCE_NORMALIZATION[raw.downcase.strip] || raw.split('.').first&.capitalize || raw
  end

  def parse_source_breakdown_response(response)
    return empty_source_breakdown unless response&.rows.present?

    # Aggregate after normalizing source names
    aggregated = Hash.new { |h, k| h[k] = { sessions: 0, users: 0, new_users: 0 } }

    response.rows.each do |row|
      raw    = row.dimension_values.first&.value || 'unknown'
      name   = normalize_source(raw)
      aggregated[name][:sessions]  += row.metric_values[0]&.value.to_i
      aggregated[name][:users]     += row.metric_values[1]&.value.to_i
      aggregated[name][:new_users] += row.metric_values[2]&.value.to_i
    end

    sources = aggregated
      .map { |name, data| { source: name }.merge(data) }
      .sort_by { |s| -s[:sessions] }

    total = sources.sum { |s| s[:sessions] }

    {
      sources: sources,
      total_sessions: total,
      top_source: sources.first&.dig(:source),
      error: nil
    }
  end

  def empty_source_breakdown
    { sources: [], total_sessions: 0, top_source: nil, error: nil }
  end
end
