namespace :backfill do
  desc "Backfill missing click events for July 23-24, 2026 due to bot blocking anomaly"
  task click_events: :environment do
    puts "Starting click event backfill for July 23-24, 2026..."

    # Configuration
    target_dates = [Date.parse('2026-07-23')]  # Only backfill July 23, not today
    target_events_per_day = 164
    event_distribution = { 'Ad-Click' => 0.94, 'Reveal-Seller-Details' => 0.06 }

    # Get sample data for realistic generation
    sample_ads = Ad.limit(100).pluck(:id)
    sample_user_agents = [
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36',
      'Mozilla/5.0 (Linux; Android 14; 24048RN6CG Build/UP1A.231005.007; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/142.0.7444.102 Mobile Safari/537.36',
      'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    ]

    # Track results
    total_created = 0
    errors = []

    target_dates.each do |date|
      puts "\nProcessing date: #{date}"

      # Calculate counts for each event type
      ad_click_count = (target_events_per_day * event_distribution['Ad-Click']).round
      reveal_count = target_events_per_day - ad_click_count

      puts "  Target: #{target_events_per_day} events (#{ad_click_count} Ad-Click, #{reveal_count} Reveal-Seller-Details)"

      # Generate Ad-Click events
      (1..ad_click_count).each do |i|
        begin
          # Distribute timestamps evenly across the day
          seconds_into_day = (i.to_f / ad_click_count * 86400).to_i
          timestamp = date.beginning_of_day + seconds_into_day.seconds

          click_event = ClickEvent.create!(
            event_type: 'Ad-Click',
            ad_id: sample_ads.sample,
            buyer_id: nil, # Guest users
            metadata: {
              backfilled: true,
              backfill_reason: 'bot_blocking_anomaly',
              backfill_date: Date.current.to_s,
              device_hash: SecureRandom.uuid,
              user_agent: sample_user_agents.sample,
              was_authenticated: false,
              is_guest: true,
              device_fingerprint: {
                screen_width: [360, 412, 390, 414].sample,
                screen_height: [732, 915, 844, 896].sample,
                platform: ['Linux armv8l', 'Linux armv7l', 'MacIntel'].sample,
                language: 'en-US',
                timezone: 'Africa/Nairobi'
              }
            },
            created_at: timestamp,
            updated_at: timestamp
          )
          total_created += 1
        rescue => e
          errors << "Ad-Click #{i} on #{date}: #{e.message}"
        end
      end

      # Generate Reveal-Seller-Details events
      (1..reveal_count).each do |i|
        begin
          # Distribute timestamps evenly across the day
          seconds_into_day = (i.to_f / reveal_count * 86400).to_i
          timestamp = date.beginning_of_day + seconds_into_day.seconds

          click_event = ClickEvent.create!(
            event_type: 'Reveal-Seller-Details',
            ad_id: sample_ads.sample,
            buyer_id: nil, # Guest users
            metadata: {
              backfilled: true,
              backfill_reason: 'bot_blocking_anomaly',
              backfill_date: Date.current.to_s,
              device_hash: SecureRandom.uuid,
              user_agent: sample_user_agents.sample,
              was_authenticated: false,
              is_guest: true,
              device_fingerprint: {
                screen_width: [360, 412, 390, 414].sample,
                screen_height: [732, 915, 844, 896].sample,
                platform: ['Linux armv8l', 'Linux armv7l', 'MacIntel'].sample,
                language: 'en-US',
                timezone: 'Africa/Nairobi'
              }
            },
            created_at: timestamp,
            updated_at: timestamp
          )
          total_created += 1
        rescue => e
          errors << "Reveal-Seller-Details #{i} on #{date}: #{e.message}"
        end
      end

      puts "  Created: #{ad_click_count + reveal_count} events for #{date}"
    end

    # Summary
    puts "\n" + "=" * 60
    puts "BACKFILL SUMMARY"
    puts "=" * 60
    puts "Total events created: #{total_created}"
    puts "Errors encountered: #{errors.count}"

    if errors.any?
      puts "\nErrors:"
      errors.each { |error| puts "  - #{error}" }
    end

    # Verification
    puts "\nVerification:"
    target_dates.each do |date|
      count = ClickEvent.where('DATE(created_at) = ?', date).count
      backfilled = ClickEvent.where('DATE(created_at) = ? AND metadata->>\'backfilled\' = \'true\'', date).count
      reveal_count = ClickEvent.where('DATE(created_at) = ? AND event_type = ?', date, 'Reveal-Seller-Details').count
      puts "  #{date}: #{count} total events (#{backfilled} backfilled, #{reveal_count} Reveal-Seller-Details)"
    end

    puts "\nBackfill complete!"
  end
end
