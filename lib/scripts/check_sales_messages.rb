# Script to check unread messages for Sales users
# Run with: rails runner lib/scripts/check_sales_messages.rb

puts "=" * 80
puts "Sales Users Messages Analysis"
puts "=" * 80
puts ""

# Check for SalesUser type
sample_user = SalesUser.first

unless sample_user
  puts "  ⚠️  No SalesUser users found in database"
  exit
end

puts "\nSample Sales User:"
puts "  ID: #{sample_user.id}"
puts "  Email: #{sample_user.email || 'N/A'}"

# Sales users use admin_id in conversations (based on backend code)
conversations = Conversation.where(admin_id: sample_user.id)

puts "\nConversations:"
puts "  Total conversations: #{conversations.count}"

if conversations.count == 0
  puts "  ⚠️  No conversations found for this sales user"
  exit
end

# Analyze each conversation
unread_counts = []
total_unread_messages = 0

conversations.each do |conversation|
  # Sales users count messages from sellers and buyers that are unread
  unread_count = conversation.messages
                            .where(sender_type: ['Seller', 'Buyer'])
                            .where(read_at: nil)
                            .count
  
  unread_counts << { conversation_id: conversation.id, unread_count: unread_count }
  total_unread_messages += unread_count
end

# Calculate conversations_with_unread
conversations_with_unread = unread_counts.count { |item| item[:unread_count] > 0 }

puts "\nUnread Message Counts:"
puts "  Total unread messages: #{total_unread_messages}"
puts "  Conversations with unread: #{conversations_with_unread}"

# Show breakdown by conversation
if unread_counts.any?
  puts "\n  Breakdown by conversation:"
  unread_counts.each do |item|
    if item[:unread_count] > 0
      puts "    Conversation #{item[:conversation_id]}: #{item[:unread_count]} unread"
    end
  end
end

# Simulate endpoint responses
puts "\nSimulated API Response Structures:"
puts "\n  1. /sales/conversations/unread_counts (plural):"
puts "     {"
puts "       unread_counts: #{unread_counts.inspect},"
puts "       conversations_with_unread: #{conversations_with_unread}"
puts "     }"

puts "\n  2. /sales/conversations/unread_count (singular):"
puts "     {"
puts "       count: #{total_unread_messages}"
puts "     }"

puts "\n  3. /conversations/unread_counts (general endpoint):"
puts "     Note: This endpoint should route to sales handler if authenticated as sales"
puts "     Expected format: { unread_counts: [...], conversations_with_unread: #{conversations_with_unread} }"

# Database query check
puts "\nDatabase Query Verification:"
puts "  Messages table structure:"
sample_message = Message.first
if sample_message
  puts "    - conversation_id: #{sample_message.conversation_id}"
  puts "    - sender_type: #{sample_message.sender_type}"
  puts "    - sender_id: #{sample_message.sender_id}"
  puts "    - read_at: #{sample_message.read_at || 'nil (unread)'}"
  puts "    - status: #{sample_message.status || 'nil'}"
end

# Check actual unread messages in DB
puts "\n  Actual unread messages in database for this sales user:"
conversations.each do |conv|
  unread = conv.messages
               .where(sender_type: ['Seller', 'Buyer'])
               .where(read_at: nil)
  
  count = unread.count
  if count > 0
    puts "    Conversation #{conv.id}: #{count} unread messages"
    puts "      Sample message IDs: #{unread.limit(3).pluck(:id).join(', ')}"
    puts "      Sender types: #{unread.pluck(:sender_type).uniq.join(', ')}"
  end
end

# Check all sales users
puts "\n" + "=" * 80
puts "All Sales Users Summary"
puts "=" * 80

SalesUser.all.each do |sales_user|
  user_conversations = Conversation.where(admin_id: sales_user.id)
  user_unread_total = 0
  
  user_conversations.each do |conv|
    user_unread_total += conv.messages
                          .where(sender_type: ['Seller', 'Buyer'])
                          .where(read_at: nil)
                          .count
  end
  
  puts "\n  Sales User ##{sales_user.id} (#{sales_user.email}):"
  puts "    Conversations: #{user_conversations.count}"
  puts "    Total unread: #{user_unread_total}"
end

puts "\n" + "=" * 80
puts "Summary"
puts "=" * 80
puts ""
puts "Key Findings:"
puts "  1. Sales users' conversations are stored with admin_id = sales_user.id"
puts "  2. Unread messages are from 'Seller' or 'Buyer' sender types"
puts "  3. Messages are unread when read_at is nil"
puts "  4. The /conversations/unread_counts endpoint should work for sales users"
puts ""
puts "Recommendation:"
puts "  - Verify that /conversations/unread_counts routes correctly for sales users"
puts "  - The frontend should use this endpoint and sum all unread_count values"
puts ""
puts "=" * 80

