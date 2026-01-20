namespace :search_analytics do
  desc "Sync search analytics from Redis to PostgreSQL"
  task sync: :environment do
    puts "Starting search analytics sync..."
    SyncSearchAnalyticsJob.perform_now
    puts "Search analytics sync completed."
  end

  desc "Show current Redis search analytics"
  task redis_stats: :environment do
    analytics = SearchRedisService.analytics
    puts "Current Redis Search Analytics:"
    puts "================================"
    puts "Total searches today: #{analytics[:total_searches_today]}"
    puts "Unique search terms today: #{analytics[:unique_search_terms_today]}"
    puts "Total search records: #{analytics[:total_search_records]}"
    puts ""
    puts "Popular searches (all time):"
    popular = SearchRedisService.popular_searches(10, :all)
    popular.each_with_index do |term, index|
      puts "#{index + 1}. #{term}"
    end
  end

  desc "Show PostgreSQL search analytics for today"
  task db_stats: :environment do
    analytic = SearchAnalytic.latest
    if analytic
      puts "Latest PostgreSQL Search Analytics (#{analytic.date}):"
      puts "=================================================="
      puts "Total searches today: #{analytic.total_searches_today}"
      puts "Unique search terms today: #{analytic.unique_search_terms_today}"
      puts "Total search records: #{analytic.total_search_records}"
      puts ""
      puts "Popular searches (all time): #{analytic.popular_searches_all_time&.first(5)&.join(', ')}"
    else
      puts "No analytics data found in database."
    end
  end

  desc "Clean up expired Redis search data (maintenance)"
  task cleanup: :environment do
    puts "Running Redis search data cleanup..."
    SearchRedisService.cleanup_expired_data
    puts "Cleanup completed."
  end
end