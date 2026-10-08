# frozen_string_literal: true

require 'net/http'

# Google Indexing API — officially scoped to JobPosting and livestream pages;
# product URLs are outside the supported types. The endpoint still accepts
# URL_UPDATED/URL_DELETED notifications and may trigger a faster crawl —
# worst case Google ignores them. Reuses GOOGLE_SERVICE_ACCOUNT_JSON, which
# must be added as an owner of the Search Console property.
class GoogleIndexingService
  ENDPOINT = 'https://indexing.googleapis.com/v3/urlNotifications:publish'
  SCOPE = 'https://www.googleapis.com/auth/indexing'

  def self.notify(url, deleted: false)
    json = ENV['GOOGLE_SERVICE_ACCOUNT_JSON'].presence
    return if json.blank?

    credentials = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(json),
      scope: SCOPE
    )
    credentials.fetch_access_token!

    uri = URI(ENDPOINT)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.post(
        uri.request_uri,
        { url: url, type: deleted ? 'URL_DELETED' : 'URL_UPDATED' }.to_json,
        'Content-Type' => 'application/json; charset=utf-8',
        'Authorization' => "Bearer #{credentials.access_token}"
      )
    end

    # 200 = acknowledged. 403 usually means the service account is not an
    # owner of the Search Console property; 429 = quota exceeded.
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn "[GoogleIndexingService] notify failed: HTTP #{response.code} #{response.body.to_s.truncate(200)}"
    end
  rescue StandardError => e
    Rails.logger.warn "[GoogleIndexingService] notify error: #{e.message}"
  end
end
