class EvaluateOrganicFeaturedAdsJob < ApplicationJob
  queue_as :low

  # Triggered by sidekiq-cron (config/schedule.yml) every 6 hours.
  # Elects merit-based featured listings per category, staggered for 7 days
  # with a 14-day anti-monopoly cooldown.
  def perform(slots_per_category = 3)
    OrganicFeaturedService.elect_featured_ads!(slots_per_category: slots_per_category)
  end
end
