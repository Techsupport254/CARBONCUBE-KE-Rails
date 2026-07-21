# backend/scratch/import_xml_calls.rb

dry_run = ENV['DRY_RUN'] != 'false'

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

# Build phone number lookup map
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

puts "Dry Run Mode: #{dry_run}"
puts "Parsed #{calls_to_process.size} calls since June 30th for our sellers (excluding Theevan)."

# Run in transaction block
ActiveRecord::Base.transaction do
  new_records_created = 0
  records_updated = 0
  resolved_sellers = []

  calls_to_process.each do |call|
    # Check if a CallRecord exists for this seller within 15 minutes of the started_at time
    window = 15.minutes
    existing_record = CallRecord.where(customer_id: call[:seller].id, customer_type: "Seller")
                                .where(started_at: (call[:started_at] - window)..(call[:started_at] + window))
                                .first
                                 
    feedback = call[:duration_seconds] > 0 ? "legacy" : ""
    
    if existing_record
      # Update the existing record
      existing_record.started_at = call[:started_at]
      existing_record.duration_seconds = call[:duration_seconds]
      existing_record.ended_at = call[:started_at] + call[:duration_seconds].seconds
      existing_record.customer_feedback = feedback
      existing_record.agent_notes = feedback
      
      if existing_record.changed?
        existing_record.save!
        records_updated += 1
      end
    else
      # Create a new record
      call_type = (call[:xml_type] == 2) ? :outbound : :inbound
      status = (call[:duration_seconds] > 0) ? :completed : :missed
      
      CallRecord.create!(
        customer: call[:seller],
        started_at: call[:started_at],
        duration_seconds: call[:duration_seconds],
        ended_at: call[:started_at] + call[:duration_seconds].seconds,
        call_type: call_type,
        status: status,
        customer_feedback: feedback,
        agent_notes: feedback,
        caller_name: call[:seller].fullname,
        caller_phone: call[:seller].phone_number,
        customer_email: call[:seller].email
      )
      new_records_created += 1
    end
    
    resolved_sellers << call[:seller].id
  end

  resolved_sellers.uniq!
  
  # Check pending call queues for these sellers
  pending_queues = CallQueue.where(seller_id: resolved_sellers, status: CallQueue::STATUS_PENDING)
  queues_resolved_count = pending_queues.count
  
  pending_queues.update_all(status: CallQueue::STATUS_RESOLVED, resolved_at: Time.current)

  puts "\n--- PROCESS SUMMARY ---"
  puts "New CallRecords created: #{new_records_created}"
  puts "Existing CallRecords updated: #{records_updated}"
  puts "Pending CallQueues resolved: #{queues_resolved_count}"

  if dry_run
    puts "\n[Dry Run] Rolling back database transaction. No changes have been saved."
    raise ActiveRecord::Rollback
  else
    puts "\n[Production] Changes committed to the database successfully."
  end
end
