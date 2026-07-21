class SendBulkBuyingSafetyCampaignJob < ApplicationJob
  queue_as :broadcast

  retry_on StandardError, wait: 30.seconds, attempts: 2

  def perform(dry_run = true)
    active_sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
    total_sellers = active_sellers.count

    active_buyers = Buyer.where(deleted: [false, nil], blocked: [false, nil])
    total_buyers = active_buyers.count

    seller_jobs_count = 0
    active_sellers.find_in_batches(batch_size: 100) do |batch|
      batch.each do |seller|
        unless dry_run
          SendUserBuyingSafetyCampaignJob.perform_later(seller.id, 'seller', false)
        end
        seller_jobs_count += 1
      end
    end

    buyer_jobs_count = 0
    active_buyers.find_in_batches(batch_size: 100) do |batch|
      batch.each do |buyer|
        unless dry_run
          SendUserBuyingSafetyCampaignJob.perform_later(buyer.id, 'buyer', false)
        end
        buyer_jobs_count += 1
      end
    end

    Rails.logger.info "Buying safety campaign complete. Sellers: #{seller_jobs_count}, Buyers: #{buyer_jobs_count}"

    {
      status: 'completed',
      dry_run: dry_run,
      sellers_processed: seller_jobs_count,
      buyers_processed: buyer_jobs_count
    }
  end
end
