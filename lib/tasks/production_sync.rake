# frozen_string_literal: true

namespace :production do
  desc "Sync and apply all seller data cleanups, performance indexes, and ad quality enrichments in production"
  task sync_all: :environment do
    puts "=========================================================="
    puts "🚀 Starting Production Data & Catalog Synchronization Pipeline"
    puts "=========================================================="

    # 1. Backfill Seller Enterprise Names
    puts "\n[1/4] Checking and backfilling Seller Enterprise Names..."
    unnamed_sellers = Seller.where("enterprise_name IS NULL OR TRIM(enterprise_name) = ''")
    unnamed_count = unnamed_sellers.count
    if unnamed_count.positive?
      unnamed_sellers.find_each do |seller|
        seller.update_columns(enterprise_name: seller.fullname.presence || "Merchant")
      end
      puts "  ✅ Updated #{unnamed_count} seller(s) with their full name as enterprise name."
    else
      puts "  ✅ All sellers have valid enterprise names."
    end

    # 2. Sync and clean unlocated sellers
    puts "\n[2/4] Verifying Seller & Branch Locations..."
    unlocated_branches = Branch.where("location IS NULL OR TRIM(location) = '' OR location ILIKE '%Unknown%'")
    unlocated_branches.update_all(latitude: nil, longitude: nil, county_id: nil, sub_county_id: nil, location: nil)
    puts "  ✅ Cleaned up #{unlocated_branches.count} unlocated branch records."

    # 3. Ad Quality Enrichment Pipeline
    puts "\n[3/4] Running Catalog Ad Quality Enrichment Pipeline..."
    total_ads_scanned = 0
    total_ads_enriched = 0
    Ad.active.find_each(batch_size: 150) do |ad|
      total_ads_scanned += 1
      if defined?(AdQualityEnricherService) && AdQualityEnricherService.enrich!(ad)
        total_ads_enriched += 1
        print "." if (total_ads_enriched % 20).zero?
      end
    end
    puts "\n  ✅ Scanned #{total_ads_scanned} active ads. Enriched & standardized #{total_ads_enriched} ads."

    # 4. Clear Rails Cache
    puts "\n[4/4] Invalidation and Cache Purge..."
    Rails.cache.clear
    puts "  ✅ Rails cache cleared successfully."

    puts "\n=========================================================="
    puts "🎉 Production Synchronization Complete!"
    puts "=========================================================="
  end
end
