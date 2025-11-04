# Test what the API endpoints actually return
# Run with: rails runner lib/scripts/test_unread_api.rb

puts "=" * 80
puts "Testing Unread API Endpoints"
puts "=" * 80
puts ""

# Find a seller with unread messages
seller = Seller.find_by(id: '472d70e2-3c8c-4ae5-827f-d7ebe92df433')
unless seller
  puts "Seller not found"
  exit
end

puts "Testing for Seller: #{seller.id} (#{seller.email || seller.enterprise_name})"
puts ""

# Simulate what fetch_seller_unread_counts does
conversations = Conversation.where(
  "(seller_id = ? OR inquirer_seller_id = ?)", 
  seller.id, 
  seller.id
).active_participants

puts "Conversations found: #{conversations.count}"
puts ""

unread_counts = conversations.map do |conversation|
  # For seller-to-seller conversations, count messages not sent by current user
  # For regular conversations, count messages from buyers, admins, and sales users
  if conversation.seller_id.present? && conversation.inquirer_seller_id.present?
    # Seller-to-seller conversation: count messages not sent by current user
    unread_count = conversation.messages
                              .where.not(sender_id: seller.id)
                              .where(read_at: nil)
                              .count
  else
    # Regular conversation: count messages from buyers, admins, and sales users
    unread_count = conversation.messages
                              .where(sender_type: ['Buyer', 'Admin', 'SalesUser'])
                              .where(read_at: nil)
                              .count
  end
  
  {
    conversation_id: conversation.id,
    unread_count: unread_count
  }
end

# Count conversations with unread messages
conversations_with_unread = unread_counts.count { |item| item[:unread_count] > 0 }

puts "API Response Structure:"
puts "{"
puts "  unread_counts: #{unread_counts.inspect},"
puts "  conversations_with_unread: #{conversations_with_unread}"
puts "}"
puts ""

# Calculate total (what frontend does)
total_count = unread_counts.reduce(0) { |sum, item| sum + (item[:unread_count] || 0) }
puts "Total unread count (sum of all): #{total_count}"
puts ""

# Show detailed breakdown
puts "Detailed Breakdown:"
unread_counts.each do |item|
  if item[:unread_count] > 0
    conv = Conversation.find(item[:conversation_id])
    puts "  Conversation #{item[:conversation_id]}:"
    puts "    Buyer ID: #{conv.buyer_id}"
    puts "    Seller ID: #{conv.seller_id}"
    puts "    Inquirer Seller ID: #{conv.inquirer_seller_id}"
    puts "    Unread Count: #{item[:unread_count]}"
    
    # Show the actual messages
    if conv.seller_id.present? && conv.inquirer_seller_id.present?
      unread_msgs = conv.messages.where.not(sender_id: seller.id).where(read_at: nil)
    else
      unread_msgs = conv.messages.where(sender_type: ['Buyer', 'Admin', 'SalesUser']).where(read_at: nil)
    end
    
    unread_msgs.each do |msg|
      puts "      - Message #{msg.id}: #{msg.sender_type} #{msg.sender_id}, read_at: #{msg.read_at || 'nil'}"
    end
    puts ""
  end
end

puts "=" * 80
puts "Done"
puts "=" * 80

