# frozen_string_literal: true

namespace :google_place_reviews do
  desc 'Purge unverified Google Maps API reviews and place IDs from sellers without an active Google Business Profile connection'
  task purge_unverified: :environment do
    connected_seller_ids = GoogleBusinessProfileConnection
      .where(status: 'connected')
      .where.not(google_location_id: nil)
      .pluck(:seller_id)

    unverified_sellers = Seller.where(
      'jsonb_array_length(google_place_reviews) > 0 OR google_place_id IS NOT NULL'
    )
    unverified_sellers = unverified_sellers.where.not(id: connected_seller_ids) if connected_seller_ids.any?

    total = unverified_sellers.count
    puts "Found #{total} sellers with unverified Google Maps reviews or place IDs..."

    cleared = 0
    unverified_sellers.find_each do |seller|
      seller.update_columns(
        google_place_reviews: [],
        google_place_id: nil,
        google_reviews_fetched_at: nil,
        google_place_id_fetched_at: nil,
        updated_at: Time.current
      )
      cleared += 1
      puts "CLEARED unverified reviews: #{seller.enterprise_name} (#{seller.id})"
    end

    puts "Done. Cleared unverified Google reviews from #{cleared} sellers."
  end

  desc 'Alias for purge_unverified: clear unverified Google Maps reviews'
  task cleanup: :purge_unverified

  desc 'Sync Google reviews for all sellers with an active Google Business Profile connection'
  task sync_connected: :environment do
    connections = GoogleBusinessProfileConnection
      .where(status: 'connected')
      .where.not(google_location_id: nil)

    puts "Syncing #{connections.count} connected Google Business Profile accounts..."
    connections.find_each do |conn|
      begin
        GoogleBusinessProfileService.new(conn).sync_reviews!
        puts "SYNCED: Seller #{conn.seller_id} (#{conn.location_name}) — #{conn.review_count} reviews"
      rescue StandardError => e
        puts "FAILED: Seller #{conn.seller_id}: #{e.message}"
      end
    end
  end
end
