# frozen_string_literal: true

# Triggered hourly by sidekiq-cron (config/schedule.yml).
# Sweeps Brand Kenya directory brands that reached onboarded status and
# emails them the complete-profile nudge. Production-only — marketing email
# must never fire from a dev/staging Sidekiq worker.
class BrandKenyaOnboardedNotifyJob < ApplicationJob
  queue_as :low

  def perform
    return unless Rails.env.production?

    BrandKenyaOutreach.new(out: Rails.logger).notify_onboarded
  end
end
