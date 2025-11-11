# Script to analyze what qualifies as "direct" traffic
# Run with: rails runner lib/scripts/analyze_direct_traffic.rb

puts "=" * 80
puts "Analyzing Direct Traffic"
puts "=" * 80
puts ""

# Get all direct traffic records
direct_records = Analytic.where(source: 'direct')

total_direct = direct_records.count
puts "Total Direct Traffic Records: #{total_direct}"
puts ""

# Categorize direct traffic by characteristics
puts "Breakdown of Direct Traffic:"
puts ""

# 1. No UTM source, no referrer (true direct - typed URL or bookmark)
no_utm_no_referrer = direct_records.where(utm_source: [nil, ''])
                                   .where(referrer: [nil, ''])
                                   .count
puts "1. True Direct (no UTM, no referrer): #{no_utm_no_referrer}"
puts "   - User typed URL directly"
puts "   - Bookmark"
puts "   - No referrer header"
puts ""

# 2. No UTM source, referrer from own domain (internal navigation)
no_utm_own_referrer = direct_records.where(utm_source: [nil, ''])
                                    .where("referrer LIKE ? OR referrer LIKE ?", 
                                           '%carboncube-ke.com%', 
                                           '%carboncube.com%')
                                    .count
puts "2. Internal Navigation (no UTM, own domain referrer): #{no_utm_own_referrer}"
puts "   - User navigated within the site"
puts "   - Referrer is from carboncube-ke.com or carboncube.com"
puts ""

# 3. No UTM source, referrer from localhost/development
no_utm_dev_referrer = direct_records.where(utm_source: [nil, ''])
                                    .where("referrer LIKE ? OR referrer LIKE ? OR referrer LIKE ?",
                                           '%localhost%',
                                           '%127.0.0.1%',
                                           '%0.0.0.0%')
                                    .count
puts "3. Development/Testing (no UTM, localhost referrer): #{no_utm_dev_referrer}"
puts "   - Local development traffic"
puts "   - Testing environments"
puts ""

# 4. No UTM source, unknown referrer (not recognized as a source)
no_utm_unknown_referrer = direct_records.where(utm_source: [nil, ''])
                                        .where.not(referrer: [nil, ''])
                                        .where("referrer NOT LIKE ? AND referrer NOT LIKE ? AND referrer NOT LIKE ? AND referrer NOT LIKE ? AND referrer NOT LIKE ?",
                                               '%carboncube-ke.com%',
                                               '%carboncube.com%',
                                               '%localhost%',
                                               '%127.0.0.1%',
                                               '%0.0.0.0%')
                                        .count
puts "4. Unknown Referrer (no UTM, unrecognized referrer): #{no_utm_unknown_referrer}"
puts "   - Referrer exists but not recognized as a known source"
puts "   - Could be from unknown domains or apps"
puts ""

# 5. Has UTM source but still marked as direct (shouldn't happen, but check)
has_utm_still_direct = direct_records.where.not(utm_source: [nil, '']).count
if has_utm_still_direct > 0
  puts "5. ⚠️  Data Issue (has UTM source but marked direct): #{has_utm_still_direct}"
  puts "   - These records should NOT be marked as direct"
  puts "   - This indicates a data inconsistency"
  puts ""
end

# Summary
puts "=" * 80
puts "Summary:"
puts "=" * 80
puts "Total Direct: #{total_direct}"
puts "  - True Direct: #{no_utm_no_referrer}"
puts "  - Internal Navigation: #{no_utm_own_referrer}"
puts "  - Development/Testing: #{no_utm_dev_referrer}"
puts "  - Unknown Referrer: #{no_utm_unknown_referrer}"
if has_utm_still_direct > 0
  puts "  - ⚠️  Data Issues: #{has_utm_still_direct}"
end
puts ""

# Show sample records from each category
puts "=" * 80
puts "Sample Records:"
puts "=" * 80

puts ""
puts "Sample True Direct (no UTM, no referrer):"
direct_records.where(utm_source: [nil, ''])
              .where(referrer: [nil, ''])
              .limit(5)
              .each do |record|
  puts "  ID: #{record.id}, Created: #{record.created_at&.iso8601}, URL: #{record.data&.dig('full_url') || 'N/A'}"
end

puts ""
puts "Sample Internal Navigation (own domain referrer):"
direct_records.where(utm_source: [nil, ''])
              .where("referrer LIKE ? OR referrer LIKE ?", 
                     '%carboncube-ke.com%', 
                     '%carboncube.com%')
              .limit(5)
              .each do |record|
  puts "  ID: #{record.id}, Referrer: #{record.referrer}, Created: #{record.created_at&.iso8601}"
end

puts ""
puts "Sample Unknown Referrer:"
direct_records.where(utm_source: [nil, ''])
              .where.not(referrer: [nil, ''])
              .where("referrer NOT LIKE ? AND referrer NOT LIKE ? AND referrer NOT LIKE ? AND referrer NOT LIKE ? AND referrer NOT LIKE ?",
                     '%carboncube-ke.com%',
                     '%carboncube.com%',
                     '%localhost%',
                     '%127.0.0.1%',
                     '%0.0.0.0%')
              .limit(5)
              .each do |record|
  puts "  ID: #{record.id}, Referrer: #{record.referrer}, Created: #{record.created_at&.iso8601}"
end

puts ""
puts "=" * 80
puts "Direct Traffic Qualification Rules:"
puts "=" * 80
puts ""
puts "A visit is marked as 'direct' when ALL of the following are true:"
puts "  1. No UTM source parameter (utm_source is nil or empty)"
puts "  2. No platform click IDs (no gclid, fbclid, or msclkid)"
puts "  3. Either:"
puts "     a) No referrer header (true direct - typed URL/bookmark)"
puts "     b) Referrer is from own domain (internal navigation)"
puts "     c) Referrer is from localhost/development (testing)"
puts "     d) Referrer is not recognized as a known source (unknown domain)"
puts ""
puts "Direct traffic does NOT include:"
puts "  - Visits with UTM parameters (even if incomplete)"
puts "  - Visits with platform click IDs (gclid, fbclid, msclkid)"
puts "  - Visits from recognized external sources (google, facebook, etc.)"
puts "=" * 80

