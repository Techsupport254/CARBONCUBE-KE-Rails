# app/jobs/google_merchant_sync_job.rb
class GoogleMerchantSyncJob < ApplicationJob
  queue_as :default
  
  # Retry configuration
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  # Discard job if ad is not found
  discard_on ActiveRecord::RecordNotFound do |job, error|
    Rails.logger.error "GoogleMerchantSyncJob discarded: Ad not found - #{error.message}"
  end
  
  def perform(ad_id, action = 'sync')
    ad = Ad.find(ad_id)
    
    case action
    when 'sync'
      sync_ad_to_google_merchant(ad)
    when 'delete'
      delete_ad_from_google_merchant(ad)
    else
      Rails.logger.error "Unknown action for GoogleMerchantSyncJob: #{action}"
    end
  end
  
  private
  
  def sync_ad_to_google_merchant(ad)
    Rails.logger.info "Starting Google Merchant sync for ad #{ad.id}"
    
    # Check if ad is valid for sync
    unless ad.valid_for_google_merchant?
      Rails.logger.warn "Ad #{ad.id} is not valid for Google Merchant sync - skipping"
      return
    end
    
    # Perform the sync
    success = GoogleMerchantService.sync_ad(ad)
    
    if success
      Rails.logger.info "Successfully synced ad #{ad.id} to Google Merchant Center"
    else
      Rails.logger.error "Failed to sync ad #{ad.id} to Google Merchant Center"
      raise "Failed to sync ad #{ad.id} to Google Merchant Center"
    end
  end
  
  def delete_ad_from_google_merchant(ad)
    Rails.logger.info "Deleting ad #{ad.id} from Google Merchant Center"
    
    success = GoogleMerchantService.delete_product(ad)
    
    if success
      Rails.logger.info "Successfully deleted ad #{ad.id} from Google Merchant Center"
    else
      Rails.logger.error "Failed to delete ad #{ad.id} from Google Merchant Center"
      raise "Failed to delete ad #{ad.id} from Google Merchant Center"
    end
  end
end
