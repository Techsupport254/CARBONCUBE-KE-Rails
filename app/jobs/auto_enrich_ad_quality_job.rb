# frozen_string_literal: true

class AutoEnrichAdQualityJob < ApplicationJob
  queue_as :default

  def perform(ad_id)
    ad = Ad.find_by(id: ad_id)
    return unless ad && !ad.deleted?

    AdQualityEnricherService.enrich!(ad)
  rescue StandardError => e
    Rails.logger.error "AutoEnrichAdQualityJob failed for Ad ##{ad_id}: #{e.message}"
  end
end
