# frozen_string_literal: true

# Benchmark script to test Content Moderation Engine against 100 ads
# (80 Real Production Ads + 10 Tricky Benign Edge Cases + 10 Malicious / Harmful Ads)

require_relative '../config/environment'

puts "\n======================================================="
puts "🚀 RUNNING ENTERPRISE CONTENT MODERATION 100-AD BENCHMARK"
puts "=======================================================\n"

# Synthetic Edge-Cases for Rigorous Boundary Testing
TRICKY_BENIGN_ADS = [
  {
    type: :tricky_benign,
    expected_safe: true,
    title: "Gunmetal Grey HP EliteBook 840 G6, Core i7, 16GB RAM, 512GB SSD",
    description: "Sleek gunmetal finish ultrabook in pristine condition. Battery health 95%, original charger included.",
    category: "Laptops & Computers",
    price: 38_000
  },
  {
    type: :tricky_benign,
    expected_safe: true,
    title: "Booster Pro Deep Tissue Massage Gun with 6 Attachments",
    description: "High torque percussion massage gun for athletic recovery and muscle tension relief. 4 speed levels.",
    category: "Health & Beauty",
    price: 4_500
  },
  {
    type: :tricky_benign,
    expected_safe: true,
    title: "Professional Japanese Damascus Steel Chef Knife & Cleaver Set",
    description: "Ultra-sharp 8-inch chef knife and meat cleaver made of 67-layer Damascus steel. Ergonomic wooden handle.",
    category: "Kitchen & Dining",
    price: 7_200
  },
  {
    type: :tricky_benign,
    expected_safe: true,
    title: "Elegant Burgundy Cocktail Dress with Side Slit for Weddings",
    description: "Stunning evening cocktail dress, size M. Breathable silk fabric, perfect for banquets and gala events.",
    category: "Fashion & Clothing",
    price: 3_500
  },
  {
    type: :tricky_benign,
    expected_safe: true,
    title: "Summer 2-Piece Sexy Bikini Set for Beach & Pool",
    description: "High waist floral print bikini swimsuit, high elasticity and quick drying fabric.",
    category: "Fashion & Clothing",
    price: 1_800
  },
  {
    type: :tricky_benign,
    expected_safe: true,
    title: "Heavy Duty Pneumatic Air Nail Gun for Carpentry & Roofing",
    description: "Industrial grade nail gun, holds up to 100 framing nails. Comes with carrying case and safety goggles.",
    category: "Tools & Hardware",
    price: 12_000
  },
  {
    type: :tricky_benign,
    expected_safe: true,
    title: "Toyota Land Cruiser Prado 2022 Rental with Driver or Self-Drive",
    description: "Luxury SUV hire in Nairobi. KES 15,000 per day. Standard refundable security deposit required on pickup.",
    category: "Vehicles & Car Hire",
    price: 15_000
  },
  {
    type: :tricky_benign,
    expected_safe: true,
    title: "Brand New High Power Hot Melt Glue Gun with 20 Glue Sticks",
    description: "60W craft glue gun with anti-drip nozzle. Ideal for DIY projects, wood, plastic and leather repairs.",
    category: "Office & Stationery",
    price: 950
  },
  {
    type: :tricky_benign,
    expected_safe: true,
    title: "iPhone 13 128GB Blue - Clean Ex-UK Unit",
    description: "Luku safi sana! Battery 88%, Face ID inawork poa. Bei ya kuongea kidogo. Kamata offer leo along Moi Avenue.",
    category: "Smartphones & Tablets",
    price: 52_000
  },
  {
    type: :tricky_benign,
    expected_safe: true,
    title: "Set of 6 Crystal Shot Glasses with Heavy Solid Base",
    description: "Premium clear shot glasses 50ml capacity for whiskey, tequila, and espresso shots. Dishwasher safe.",
    category: "Kitchen & Dining",
    price: 1_600
  }
].freeze

HARMFUL_MALICIOUS_ADS = [
  {
    type: :harmful_scam,
    expected_safe: false,
    title: "Brand New iPhone 15 Pro Max 1TB for 12k Only",
    description: "Selling urgent due to travel. Lipa deposit ya KES 3,000 kwanza ndio tulete mzigo mpaka kwako.",
    category: "Smartphones & Tablets",
    price: 12_000
  },
  {
    type: :harmful_prohibited,
    expected_safe: false,
    title: "Glock 19 Gen 5 9mm Pistol with Live Ammunition for Sale",
    description: "Unregistered black pistol with 2 magazines and 50 rounds of live ammo. Fast discreet cash deals in Nairobi.",
    category: "Sports & Outdoors",
    price: 85_000
  },
  {
    type: :harmful_scam,
    expected_safe: false,
    title: "Clean Black Dollars and Chemical Wash Wash Liquid Available",
    description: "Original SSD solution and activation powder to clean black notes. Double your money within 1 hour.",
    category: "Commercial Services",
    price: 50_000
  },
  {
    type: :harmful_prohibited,
    expected_safe: false,
    title: "Original Cytotec 200mcg Misoprostol Pills for Quick Termination",
    description: "Safe and fast abortion pills for sale. Discreet home delivery anywhere in Kenya, 100% effective.",
    category: "Health & Beauty",
    price: 3_500
  },
  {
    type: :harmful_adult,
    expected_safe: false,
    title: "VIP Escort and Erotic Massage with Happy Ending in Westlands",
    description: "Gorgeous college girls available 24/7 for incall and outcall escort services, full body erotic massage.",
    category: "Health & Beauty",
    price: 5_000
  },
  {
    type: :harmful_prohibited,
    expected_safe: false,
    title: "Pure High Grade Cocaine and Crystal Meth Available",
    description: "Discreet packaging and drop off in Kilimani, Westlands, and CBD. Contact for grams.",
    category: "Health & Beauty",
    price: 8_000
  },
  {
    type: :harmful_fraud,
    expected_safe: false,
    title: "Fake Kenyan National ID, KCSE Certificate and Driving License",
    description: "We print replica National IDs, original blank KCSE certs with any grade, and verified NTSA driving license.",
    category: "Services",
    price: 10_000
  },
  {
    type: :harmful_scam,
    expected_safe: false,
    title: "Executive 2 Bedroom Furnished Apartment in Kilimani",
    description: "High demand unit. You must pay commitment fee of KES 2,500 before viewing or scheduling inspection.",
    category: "Real Estate",
    price: 45_000
  },
  {
    type: :harmful_scam,
    expected_safe: false,
    title: "Earn 50k Daily Working 1 Hour From Home Online",
    description: "Guaranteed crypto doubling scheme! Join our VIP Telegram channel right now: t.me/fastmoney_kenya",
    category: "Jobs & Services",
    price: 1_000
  },
  {
    type: :harmful_scam,
    expected_safe: false,
    title: "Sony PlayStation 5 Disc Edition + 2 Controllers",
    description: "PS5 brand new in box. Tuma fare ya KES 1,500 kwa M-Pesa kwanza ndio rider atoke dukani kuleta.",
    category: "Gaming & Consoles",
    price: 42_000
  }
].freeze

# 1. Fetch 80 Real Existing Active Ads from DB
sample_db_ads = Ad.includes(:category, :seller).where(deleted: false, flagged: false).order('RANDOM()').limit(80).to_a
puts "Loaded #{sample_db_ads.size} real production ads from database."

benchmark_items = []

# Add Real DB Ads
sample_db_ads.each_with_index do |ad, idx|
  benchmark_items << {
    id: "DB_AD_#{idx + 1}",
    source: :real_database,
    expected_safe: true,
    ad_object: ad,
    title: ad.title.to_s,
    description: ad.description.to_s,
    category: ad.category&.name,
    price: ad.price,
    seller: ad.seller
  }
end

# Add Tricky Benign Ads
TRICKY_BENIGN_ADS.each_with_index do |item, idx|
  benchmark_items << item.merge(id: "BENIGN_EDGE_#{idx + 1}", source: :tricky_benign)
end

# Add Harmful Malicious Ads
HARMFUL_MALICIOUS_ADS.each_with_index do |item, idx|
  benchmark_items << item.merge(id: "HARMFUL_SCAM_#{idx + 1}", source: :harmful_malicious)
end

puts "Total test dataset size: #{benchmark_items.size} items\n"
puts "Running multi-signal moderation pipeline on all 100 ads...\n"

results = []
false_positives = []
false_negatives = []
latencies = []

benchmark_items.each_with_index do |item, index|
  print "Evaluating [#{index + 1}/#{benchmark_items.size}] #{item[:id]}... "

  eval_result = if item[:ad_object]
                  ContentModeration::CompositeRiskEngine.evaluate_ad(item[:ad_object])
                else
                  ContentModeration::CompositeRiskEngine.evaluate_content(
                    title: item[:title],
                    description: item[:description],
                    category_name: item[:category],
                    price: item[:price],
                    seller: item[:seller]
                  )
                end

  score = eval_result[:composite_score]
  verdict = eval_result[:verdict]
  category = eval_result[:primary_category]
  reason = eval_result[:primary_reason]
  latency = eval_result[:latency_ms]
  latencies << latency

  is_classified_safe = [:auto_approved, :soft_flagged].include?(verdict)
  expected_safe = item[:expected_safe]

  # Check accuracy
  is_false_positive = expected_safe && !is_classified_safe
  is_false_negative = !expected_safe && is_classified_safe

  false_positives << item.merge(eval_result) if is_false_positive
  false_negatives << item.merge(eval_result) if is_false_negative

  status_icon = if is_false_positive
                  "❌ FALSE POSITIVE (Valid ad wrongly held/rejected!)"
                elsif is_false_negative
                  "❌ FALSE NEGATIVE (Harmful ad missed!)"
                elsif is_classified_safe
                  "✅ SAFE (#{verdict}, Score: #{score})"
                else
                  "🛡️ BLOCKED (#{verdict}, Score: #{score}, Category: #{category})"
                end

  puts "#{status_icon} [#{latency}ms]"

  results << {
    item_id: item[:id],
    source: item[:source],
    title: item[:title],
    expected_safe: expected_safe,
    score: score,
    verdict: verdict,
    category: category,
    reason: reason,
    latency_ms: latency,
    correct: !is_false_positive && !is_false_negative
  }
end

# Calculate Metrics
total_count = results.size
correct_count = results.count { |r| r[:correct] }
accuracy = ((correct_count.to_f / total_count) * 100).round(2)

safe_items_count = benchmark_items.count { |i| i[:expected_safe] }
harmful_items_count = benchmark_items.count { |i| !i[:expected_safe] }

fp_rate = ((false_positives.size.to_f / safe_items_count) * 100).round(2)
fn_rate = ((false_negatives.size.to_f / harmful_items_count) * 100).round(2)
avg_latency = (latencies.sum / latencies.size).round(2)

# Verdict distribution
verdict_counts = results.group_by { |r| r[:verdict] }.transform_values(&:count)

puts "\n======================================================="
puts "📊 100-AD BENCHMARK RESULTS & METRICS"
puts "======================================================="
puts "Total Ads Tested:       #{total_count}"
puts "Overall Accuracy:       #{accuracy}%"
puts "False Positive Rate:    #{fp_rate}% (#{false_positives.size}/#{safe_items_count} valid ads wrongly flagged)"
puts "False Negative Rate:    #{fn_rate}% (#{false_negatives.size}/#{harmful_items_count} harmful ads missed)"
puts "Average Evaluation Lat: #{avg_latency} ms per ad"
puts "\nVerdict Distribution:"
verdict_counts.each do |verdict, count|
  pct = ((count.to_f / total_count) * 100).round(1)
  puts "  - #{verdict.to_s.upcase.ljust(15)}: #{count.to_s.rjust(3)} ads (#{pct}%)"
end

if false_positives.any?
  puts "\n⚠️ FALSE POSITIVES DETAILS:"
  false_positives.each do |fp|
    puts "  - ID: #{fp[:id]} | Title: #{fp[:title]} | Score: #{fp[:composite_score]} | Reason: #{fp[:primary_reason]}"
  end
end

if false_negatives.any?
  puts "\n⚠️ FALSE NEGATIVES DETAILS:"
  false_negatives.each do |fn|
    puts "  - ID: #{fn[:id]} | Title: #{fn[:title]} | Score: #{fn[:composite_score]} | Reason: #{fn[:primary_reason]}"
  end
end

puts "\n======================================================="
puts "✅ BENCHMARK COMPLETE"
puts "=======================================================\n"

# Export report to JSON for audit records
audit_file = Rails.root.join("log", "moderation_100_ads_benchmark_report.json")
File.write(audit_file, JSON.pretty_generate({
  timestamp: Time.current.iso8601,
  total_evaluated: total_count,
  accuracy_pct: accuracy,
  false_positive_rate_pct: fp_rate,
  false_negative_rate_pct: fn_rate,
  average_latency_ms: avg_latency,
  verdict_distribution: verdict_counts,
  false_positives: false_positives.map { |f| { id: f[:id], title: f[:title], score: f[:composite_score], reason: f[:primary_reason] } },
  false_negatives: false_negatives.map { |f| { id: f[:id], title: f[:title], score: f[:composite_score], reason: f[:primary_reason] } },
  all_results: results
}))
puts "Detailed JSON audit report saved to #{audit_file}"
