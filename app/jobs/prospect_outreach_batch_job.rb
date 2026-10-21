# frozen_string_literal: true

# Daily cron (see config/schedule.yml) that drains the pending
# OutreachProspect queue at a fixed daily volume and spreads the sends
# across a window instead of bursting. Rate limiting is two layers deep:
#
#   1. DAILY_LIMIT caps how many prospects are touched per day
#      (override via PROSPECT_DAILY_LIMIT env).
#   2. Each email job is scheduled with an individual delay so the day's
#      sends spread evenly over SEND_WINDOW_MINUTES plus jitter — keeps
#      Brevo happy and protects sender reputation on a cold list.
#
# Only runs in production; manual batches go through
# `rake prospect_outreach:send_batch[n]`.
class ProspectOutreachBatchJob < ApplicationJob
  queue_as :low

  DAILY_LIMIT = 50
  SEND_WINDOW_MINUTES = 120

  def perform
    return unless Rails.env.production?

    limit = ENV['PROSPECT_DAILY_LIMIT'].presence&.to_i || DAILY_LIMIT
    prospects = OutreachProspect.emailable.order(:id).limit(limit).pluck(:id)
    return if prospects.empty?

    spacing = (SEND_WINDOW_MINUTES * 60) / [prospects.size, 1].max

    prospects.each_with_index do |id, i|
      delay = (i * spacing) + rand(0..45) # jitter so sends never land on a metronome
      SendProspectEmailJob.set(wait: delay.seconds).perform_later(id)
    end

    Rails.logger.info "[ProspectOutreachBatchJob] scheduled #{prospects.size} emails over ~#{SEND_WINDOW_MINUTES}min"
  end
end
