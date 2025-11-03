# Script to check unread messages data structures for all user types
# Run with: rails runner lib/scripts/check_unread_messages.rb

puts "=" * 80
puts "Unread Messages Data Structure Analysis"
puts "=" * 80
puts ""

# Check for each user type
user_types = [
  { type: 'Buyer', model: Buyer, id_field: 'buyer_id' },
  { type: 'Seller', model: Seller, id_field: 'seller_id' },
  { type: 'Admin', model: Admin, id_field: 'admin_id' },
  { type: 'SalesUser', model: SalesUser, id_field: 'admin_id' } # Sales uses admin_id
]

user_types.each do |user_type_info|
  user_type = user_type_info[:type]
  model = user_type_info[:model]
  id_field = user_type_info[:id_field]
  
  puts "\n" + "=" * 80
  puts "#{user_type} Analysis"
  puts "=" * 80
  
  # Get a sample user of this type
  sample_user = model.first
  unless sample_user
    puts "  ⚠️  No #{user_type} users found in database"
    next
  end
  
  puts "\nSample User:"
  puts "  ID: #{sample_user.id}"
  puts "  Name/Email: #{sample_user.respond_to?(:name) ? sample_user.name : sample_user.respond_to?(:email) ? sample_user.email : 'N/A'}"
  
  # Get conversations for this user
  conversation_conditions = {}
  if id_field == 'buyer_id'
    conversation_conditions[:buyer_id] = sample_user.id
  elsif id_field == 'seller_id'
    # Sellers can be in seller_id OR inquirer_seller_id
    conversations = Conversation.where(
      "(seller_id = ? OR inquirer_seller_id = ?)",
      sample_user.id,
      sample_user.id
    )
  elsif id_field == 'admin_id'
    conversation_conditions[:admin_id] = sample_user.id
  end
  
  conversations = if id_field == 'seller_id'
    Conversation.where(
      "(seller_id = ? OR inquirer_seller_id = ?)",
      sample_user.id,
      sample_user.id
    )
  else
    Conversation.where(conversation_conditions)
  end
  
  puts "\nConversations:"
  puts "  Total conversations: #{conversations.count}"
  
  if conversations.count == 0
    puts "  ⚠️  No conversations found for this user"
    next
  end
  
  # Analyze each conversation
  unread_counts = []
  total_unread_messages = 0
  
  conversations.each do |conversation|
    # Determine sender types to count based on user type
    sender_types = case user_type
    when 'Buyer'
      ['Seller', 'Admin', 'SalesUser']
    when 'Seller'
      if conversation.seller_id.present? && conversation.inquirer_seller_id.present?
        # Seller-to-seller: count messages not from current user
        unread_count = conversation.messages
                                  .where.not(sender_id: sample_user.id)
                                  .where(read_at: nil)
                                  .count
      else
        # Regular: count from buyers, admins, sales
        unread_count = conversation.messages
                                  .where(sender_type: ['Buyer', 'Admin', 'SalesUser'])
                                  .where(read_at: nil)
                                  .count
      end
      unread_counts << { conversation_id: conversation.id, unread_count: unread_count }
      total_unread_messages += unread_count
      next
    when 'Admin'
      ['Seller', 'Buyer']
    when 'SalesUser'
      ['Seller', 'Buyer']
    else
      []
    end
    
    # For non-seller types
    if sender_types.any?
      unread_count = conversation.messages
                                .where(sender_type: sender_types)
                                .where(read_at: nil)
                                .count
      unread_counts << { conversation_id: conversation.id, unread_count: unread_count }
      total_unread_messages += unread_count
    end
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
  puts "\n  1. /#{user_type.downcase}/conversations/unread_counts (plural):"
  puts "     {"
  puts "       unread_counts: #{unread_counts.inspect},"
  puts "       conversations_with_unread: #{conversations_with_unread}"
  puts "     }"
  
  puts "\n  2. /#{user_type.downcase}/conversations/unread_count (singular):"
  puts "     {"
  puts "       count: #{total_unread_messages}"
  puts "     }"
  
  # Check what /conversations/unread_counts would return (if it exists)
  puts "\n  3. /conversations/unread_counts (general endpoint):"
  puts "     Note: This endpoint may route to role-specific handler or may not exist"
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
  puts "\n  Actual unread messages in database for this user:"
  conversations.each do |conv|
    case user_type
    when 'Buyer'
      unread = conv.messages
                   .where(sender_type: ['Seller', 'Admin', 'SalesUser'])
                   .where(read_at: nil)
    when 'Seller'
      if conv.seller_id.present? && conv.inquirer_seller_id.present?
        unread = conv.messages.where.not(sender_id: sample_user.id).where(read_at: nil)
      else
        unread = conv.messages.where(sender_type: ['Buyer', 'Admin', 'SalesUser']).where(read_at: nil)
      end
    when 'Admin', 'SalesUser'
      unread = conv.messages.where(sender_type: ['Seller', 'Buyer']).where(read_at: nil)
    end
    
    count = unread.count
    if count > 0
      puts "    Conversation #{conv.id}: #{count} unread messages"
      puts "      Sample message IDs: #{unread.limit(3).pluck(:id).join(', ')}"
    end
  end
end

puts "\n" + "=" * 80
puts "Summary"
puts "=" * 80
puts ""
puts "Key Findings:"
puts "  1. 'conversations_with_unread' = number of conversations that have at least 1 unread message"
puts "  2. Total unread count = sum of all unread messages across all conversations"
puts "  3. For navbar, we likely want the TOTAL unread count (sum), not conversations_with_unread"
puts "  4. Messages are unread when read_at is nil"
puts ""
puts "Recommendation:"
puts "  - Use /conversations/unread_counts endpoint and sum all unread_count values"
puts "  - OR use role-specific /unread_count endpoint which returns total count"
puts ""
puts "=" * 80

