xml_path = "/Users/user/Desktop/work/calls-20260713154225.xml"
unless File.exist?(xml_path)
  puts "XML file not found at: #{xml_path}"
  exit 1
end

xml_content = File.read(xml_path)
numbers_with_names = {}
cutoff_epoch = Time.utc(2026, 6, 30, 0, 0, 0).to_i * 1000 # June 30, 2026 start in milliseconds

# Parse all <call ... /> tags
xml_content.scan(/<call\s+([^>]+)>/) do |match|
  attributes_str = match[0]
  # Extract date, number, contact_name
  date_match = attributes_str.match(/date="(\d+)"/)
  number_match = attributes_str.match(/number="([^"]+)"/)
  contact_match = attributes_str.match(/contact_name="([^"]+)"/)
  
  if date_match && date_match[1].to_i >= cutoff_epoch && number_match
    num = number_match[1].strip
    name = contact_match ? contact_match[1].strip : "(Unknown)"
    
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
    
    if normalized_num && normalized_num =~ /\A\d{10}\z/
      numbers_with_names[normalized_num] ||= []
      numbers_with_names[normalized_num] << name unless numbers_with_names[normalized_num].include?(name)
    end
  end
end

puts "Found #{numbers_with_names.size} unique normalized phone numbers in call logs since June 30th, 2026."

matched_sellers = []

numbers_with_names.keys.each_slice(100) do |slice|
  sellers = Seller.where(phone_number: slice).or(Seller.where(secondary_phone_number: slice))
  sellers.each do |seller|
    # Find contact name(s) from XML for this seller's phone numbers
    xml_names = []
    if numbers_with_names[seller.phone_number]
      xml_names += numbers_with_names[seller.phone_number]
    end
    if numbers_with_names[seller.secondary_phone_number]
      xml_names += numbers_with_names[seller.secondary_phone_number]
    end
    xml_names = xml_names.uniq.reject { |n| n == "(Unknown)" || n.blank? }
    xml_name_str = xml_names.empty? ? "(Unknown)" : xml_names.join(", ")

    matched_sellers << {
      id: seller.id,
      fullname: seller.fullname,
      username: seller.username,
      enterprise_name: seller.enterprise_name,
      phone_number: seller.phone_number,
      secondary_phone_number: seller.secondary_phone_number,
      xml_contact_name: xml_name_str,
      location: seller.location
    }
  end
end

puts "\n--- MATCHED SELLERS (SINCE JUNE 30) ON PLATFORM (#{matched_sellers.size}) ---"
matched_sellers.each_with_index do |s, idx|
  puts "#{idx + 1}. #{s[:fullname]} (@#{s[:username]})"
  puts "   Business: #{s[:enterprise_name]}"
  puts "   Phone: #{s[:phone_number]} | Sec Phone: #{s[:secondary_phone_number]}"
  puts "   XML Contact Name: #{s[:xml_contact_name]}"
  puts "   Location: #{s[:location]}"
  puts "   ID: #{s[:id]}"
  puts "-" * 40
end

# Save results to a file for reference
out_path = "/Users/user/Desktop/work/matched_sellers_since_june30.json"
require 'json'
File.write(out_path, JSON.pretty_generate(matched_sellers))
puts "\nResults written to #{out_path}"
