# Script to check buyer phone numbers
puts "=== BUYER PHONE NUMBER ANALYSIS ==="
puts ""

total_buyers = Buyer.count
buyers_with_phone = Buyer.where.not(phone_number: [nil, '']).count
buyers_without_phone = Buyer.where(phone_number: [nil, '']).count

puts "Total Buyers: #{total_buyers}"
puts "Buyers WITH phone numbers: #{buyers_with_phone} (#{(buyers_with_phone.to_f / total_buyers * 100).round(2)}%)"
puts "Buyers WITHOUT phone numbers: #{buyers_without_phone} (#{(buyers_without_phone.to_f / total_buyers * 100).round(2)}%)"
puts ""

if buyers_with_phone > 0
  puts "Sample buyers with phone numbers (first 10):"
  Buyer.where.not(phone_number: [nil, '']).limit(10).each do |b|
    puts "  - #{b.fullname} (#{b.email}): #{b.phone_number}"
  end
  puts ""
end

if buyers_without_phone > 0
  puts "Sample buyers without phone numbers (first 10):"
  Buyer.where(phone_number: [nil, '']).limit(10).each do |b|
    puts "  - #{b.fullname} (#{b.email}): No phone"
  end
  puts ""
end

puts "=== SELLER PHONE NUMBER ANALYSIS ==="
puts ""

total_sellers = Seller.count
sellers_with_phone = Seller.where.not(phone_number: [nil, '']).count
sellers_without_phone = Seller.where(phone_number: [nil, '']).count

puts "Total Sellers: #{total_sellers}"
puts "Sellers WITH phone numbers: #{sellers_with_phone} (#{(sellers_with_phone.to_f / total_sellers * 100).round(2)}%)"
puts "Sellers WITHOUT phone numbers: #{sellers_without_phone} (#{(sellers_without_phone.to_f / total_sellers * 100).round(2)}%)"
puts ""

if sellers_with_phone > 0
  puts "Sample sellers with phone numbers (first 10):"
  Seller.where.not(phone_number: [nil, '']).limit(10).each do |s|
    puts "  - #{s.fullname} (#{s.email}): #{s.phone_number}"
  end
  puts ""
end

if sellers_without_phone > 0
  puts "Sample sellers without phone numbers (first 10):"
  Seller.where(phone_number: [nil, '']).limit(10).each do |s|
    puts "  - #{s.fullname} (#{s.email}): No phone"
  end
end

