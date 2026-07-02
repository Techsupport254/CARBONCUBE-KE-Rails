class SendBulkBuyingSafetyCampaignJob < ApplicationJob
  queue_as :default

  def perform(dry_run = true)
    Rails.logger.info "=== [SendBulkBuyingSafetyCampaignJob] STARTING CAMPAIGN ==="
    Rails.logger.info "Dry Run Mode: #{dry_run}"

    # 1. Fetch Active Sellers
    active_sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
    total_sellers = active_sellers.count
    Rails.logger.info "[SendBulkBuyingSafetyCampaignJob] Found #{total_sellers} active sellers."

    # 2. Fetch Active Buyers
    active_buyers = Buyer.where(deleted: [false, nil], blocked: [false, nil])
    total_buyers = active_buyers.count
    Rails.logger.info "[SendBulkBuyingSafetyCampaignJob] Found #{total_buyers} active buyers."

    # Process Sellers in batches
    seller_jobs_count = 0
    active_sellers.find_in_batches(batch_size: 100) do |batch|
      batch.each do |seller|
        if dry_run
          Rails.logger.info "[SendBulkBuyingSafetyCampaignJob] [DRY RUN] Would enqueue safety campaign job for Seller ID: #{seller.id} (#{seller.email})"
        else
          SendUserBuyingSafetyCampaignJob.perform_later(seller.id, 'seller', false)
        end
        seller_jobs_count += 1
      end
    end

    # Process Buyers in batches
    buyer_jobs_count = 0
    active_buyers.find_in_batches(batch_size: 100) do |batch|
      batch.each do |buyer|
        if dry_run
          Rails.logger.info "[SendBulkBuyingSafetyCampaignJob] [DRY RUN] Would enqueue safety campaign job for Buyer ID: #{buyer.id} (#{buyer.email})"
        else
          SendUserBuyingSafetyCampaignJob.perform_later(buyer.id, 'buyer', false)
        end
        buyer_jobs_count += 1
      end
    end

    Rails.logger.info "=== [SendBulkBuyingSafetyCampaignJob] COMPLETED ==="
    Rails.logger.info "Total Sellers processed/queued: #{seller_jobs_count}"
    Rails.logger.info "Total Buyers processed/queued: #{buyer_jobs_count}"

    {
      status: 'completed',
      dry_run: dry_run,
      sellers_processed: seller_jobs_count,
      buyers_processed: buyer_jobs_count
    }
  end
end
