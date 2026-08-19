# app/jobs/sync_seller_category_placement_job.rb
class SyncSellerCategoryPlacementJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  discard_on ActiveRecord::RecordNotFound do |job, error|
    Rails.logger.error "SyncSellerCategoryPlacementJob discarded: #{error.message}"
  end

  def perform(seller_id)
    seller = Seller.find(seller_id)
    SellerCategoryPlacementService.call(seller)
  end
end
