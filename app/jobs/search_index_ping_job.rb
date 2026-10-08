# frozen_string_literal: true

# Enqueues search-engine indexing pings off the request path — a Bing or
# Google outage must never slow down or fail an ad save. IndexNow covers
# Bing/Yandex; GoogleIndexingService submits URL notifications to Google.
class SearchIndexPingJob < ApplicationJob
  queue_as :low

  def perform(url, deleted: false)
    IndexNowService.ping(url)
    GoogleIndexingService.notify(url, deleted: deleted)
  end
end
