namespace :seller_category_placement do
  desc "Backfill each seller's subcategory placement based on where they have the most active ads"
  task backfill: :environment do
    sellers = Seller.where(id: Ad.where(deleted: false).select(:seller_id))
                     .or(Seller.where(id: CategoriesSeller.select(:seller_id)))
                     .distinct
    total = sellers.count
    puts "🔍 Found #{total} sellers with ads or an existing category assignment."

    updated = 0
    failed = 0

    sellers.find_each.with_index do |seller, index|
      begin
        placements = SellerCategoryPlacementService.call(seller)
        updated += 1
        placements.each do |membership|
          puts "[#{index + 1}/#{total}] #{seller.enterprise_name || seller.email}: category=#{membership.category_id} subcategory=#{membership.subcategory_id || 'none'}"
        end
      rescue => e
        failed += 1
        puts "[#{index + 1}/#{total}] ❌ Failed for seller #{seller.id}: #{e.message}"
      end
    end

    puts "\n🏁 Backfill complete! #{updated} sellers processed, #{failed} failed, #{total} total."
  end
end
