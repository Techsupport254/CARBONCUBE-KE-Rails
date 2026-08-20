# frozen_string_literal: true

namespace :ads do
  desc 'Audit, enrich, and standardize low-quality ad titles, specifications, and descriptions'
  task enrich_quality: :environment do
    puts "=== Starting Ad Quality Enrichment Pipeline ==="
    total_scanned = 0
    total_enriched = 0

    Ad.active.find_each(batch_size: 200) do |ad|
      total_scanned += 1
      if AdQualityEnricherService.enrich!(ad)
        total_enriched += 1
        print "." if (total_enriched % 25).zero?
      end
    end

    puts "\n=== Enrichment Completed ==="
    puts "Total Scanned: #{total_scanned}"
    puts "Total Enriched & Standardized: #{total_enriched}"
  end

  desc 'Enrich a single ad by ID (Usage: rake ads:enrich_single[4835])'
  task :enrich_single, [:ad_id] => :environment do |_, args|
    ad_id = args[:ad_id]
    if ad_id.blank?
      puts "Error: Please provide an ad ID. Example: rake ads:enrich_single[4835]"
      exit 1
    end

    ad = Ad.find_by(id: ad_id)
    if ad.nil?
      puts "Error: Ad with ID ##{ad_id} not found."
      exit 1
    end

    puts "Enriching Ad ##{ad.id}: '#{ad.title}' (Brand: #{ad.brand})..."
    if AdQualityEnricherService.enrich!(ad)
      ad.reload
      puts "✅ Successfully enriched Ad ##{ad.id}!"
      puts "New Title: #{ad.title}"
      puts "New Brand: #{ad.brand}"
      puts "New Manufacturer: #{ad.manufacturer}"
      puts "Specifications: #{ad.specifications}"
    else
      puts "ℹ️ No quality corrections needed or matched for Ad ##{ad.id}."
    end
  end
end
