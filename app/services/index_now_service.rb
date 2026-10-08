# frozen_string_literal: true

require 'net/http'

# IndexNow — pushes URL changes to Bing/Yandex so new ads get crawled within
# minutes instead of waiting on the sitemap crawl cycle. Google's Indexing
# API only accepts JobPosting/livestream, so this is the search-side fast
# lane available to product pages.
# Requires INDEXNOW_KEY matching the <key>.txt file served from the site root.
class IndexNowService
  ENDPOINT = 'https://api.indexnow.org/indexnow'
  HOST = 'carboncube-ke.com'

  def self.ping(urls)
    key = ENV['INDEXNOW_KEY'].presence
    return if key.blank?

    list = Array(urls).compact_blank.uniq
    return if list.empty?

    uri = URI(ENDPOINT)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.post(
        uri.request_uri,
        {
          host: HOST,
          key: key,
          keyLocation: "https://#{HOST}/#{key}.txt",
          urlList: list
        }.to_json,
        'Content-Type' => 'application/json; charset=utf-8'
      )
    end

    unless response.is_a?(Net::HTTPSuccess) || response.code == '202'
      Rails.logger.warn "[IndexNowService] ping failed: HTTP #{response.code} #{response.body.to_s.truncate(200)}"
    end
  rescue StandardError => e
    Rails.logger.warn "[IndexNowService] ping error: #{e.message}"
  end
end
