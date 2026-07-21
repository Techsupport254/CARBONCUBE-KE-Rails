xml_path = "/Users/user/Desktop/work/calls-20260713154225.xml"
unless File.exist?(xml_path)
  puts "XML file not found at: #{xml_path}"
  exit 1
end

xml_content = File.read(xml_path)
cutoff_epoch = Time.utc(2026, 6, 30, 0, 0, 0).to_i * 1000 # June 30, 2026 start in ms

# Get all unique phone numbers for matched sellers first, excluding Theevan
theevan_seller = Seller.find_by("LOWER(username) = ?", "theevan")
theevan_id = theevan_seller&.id

# We want to match numbers to seller records
seller_by_number = {}
Seller.all.each do |s|
  next if s.id == theevan_id
  seller_by_number[s.phone_number] = s if s.phone_number.present?
  seller_by_number[s.secondary_phone_number] = s if s.secondary_phone_number.present?
end

# Parse all <call ... /> tags
calls_to_process = []
xml_content.scan(/<call\s+([^>]+)>/) do |match|
  attributes_str = match[0]
  date_match = attributes_str.match(/date="(\d+)"/)
  number_match = attributes_str.match(/number="([^"]+)"/)
  duration_match = attributes_str.match(/duration="(\d+)"/)
  type_match = attributes_str.match(/type="(\d+)"/)
  contact_match = attributes_str.match(/contact_name="([^"]+)"/)
  
  if date_match && date_match[1].to_i >= cutoff_epoch && number_match
    epoch_ms = date_match[1].to_i
    num = number_match[1].strip
    duration = duration_match ? duration_match[1].to_i : 0
    xml_type = type_match ? type_match[1].to_i : 2
    contact_name = contact_match ? contact_match[1].strip : "(Unknown)"
    
    # Normalize number
    normalized_num = nil
    if num.start_with?("+254") && num.length == 13
      normalized_num = "0" + num[4..]
    elsif num.start_with?("254") && num.length == 12
      normalized_num = "0" + num[3..]
    elsif num.start_with?("0") && num.length == 10
      normalized_num = num
    elsif num.length == 9 && !num.start_with?("0")
      normalized_num = "0" + num
    end
    
    if normalized_num && seller_by_number[normalized_num]
      seller = seller_by_number[normalized_num]
      calls_to_process << {
        seller: seller,
        started_at: Time.at(epoch_ms / 1000.0).utc,
        duration_seconds: duration,
        xml_type: xml_type,
        raw_number: num,
        normalized_number: normalized_num,
        contact_name: contact_name
      }
    end
  end
end

puts "Parsed #{calls_to_process.size} calls since June 30th for our sellers (excluding Theevan)."

existing_calls_count = 0
new_calls_count = 0
existing_matches = []

calls_to_process.each do |call|
  # Check if a CallRecord exists for this seller within 15 minutes of the started_at time
  window = 15.minutes
  existing = CallRecord.where(customer_id: call[:seller].id, customer_type: "Seller")
                       .where(started_at: (call[:started_at] - window)..(call[:started_at] + window))
                       .first
                       
  if existing
    existing_calls_count += 1
    existing_matches << { xml: call, db: existing }
  else
    new_calls_count += 1
  end
end

pending_queues_count = CallQueue.where(seller_id: calls_to_process.map{|c| c[:seller].id}.uniq, status: "pending").count

puts "\n--- COMPARISON RESULTS ---"
puts "Already exists in DB (within 15m window): #{existing_calls_count}"
puts "Need to be added: #{new_calls_count}"
puts "Pending Call Queues to resolve: #{pending_queues_count}"

if existing_matches.any?
  puts "\nSample Matches:"
  existing_matches.first(5).each do |m|
    puts "Seller: #{m[:xml][:seller].fullname}"
    puts "  XML: #{m[:xml][:started_at]} | Dur: #{m[:xml][:duration_seconds]}s"
    puts "  DB:  #{m[:db].started_at} | Dur: #{m[:db].duration_seconds}s"
    puts "-" * 30
  end
end
