# Script to check conversations that might appear but have no messages
# Run with: rails runner lib/scripts/check_conversation_messages.rb

puts "=" * 80
puts "Conversation Messages Analysis"
puts "=" * 80
puts ""

# Find conversations with no messages
conversations_without_messages = Conversation.left_joins(:messages)
                                            .where(messages: { id: nil })
                                            .includes(:buyer, :seller, :admin)

puts "\nConversations WITHOUT any messages:"
puts "  Total: #{conversations_without_messages.count}"

if conversations_without_messages.count > 0
  puts "\n  Sample conversations without messages:"
  conversations_without_messages.limit(10).each do |conv|
    participant_info = []
    participant_info << "Buyer: #{conv.buyer&.fullname || conv.buyer&.email || conv.buyer_id}" if conv.buyer_id
    participant_info << "Seller: #{conv.seller&.fullname || conv.seller&.enterprise_name || conv.seller_id}" if conv.seller_id
    participant_info << "Admin: #{conv.admin_id}" if conv.admin_id
    
    puts "    Conversation ##{conv.id}:"
    puts "      Participants: #{participant_info.join(', ')}"
    puts "      Created: #{conv.created_at}"
    puts "      Updated: #{conv.updated_at}"
    puts "      Ad ID: #{conv.ad_id || 'none'}"
  end
end

# Find conversations grouped by participant (like the frontend does)
puts "\n" + "=" * 80
puts "Conversations Grouped by Participant (Sales User)"
puts "=" * 80

sales_user = SalesUser.first
if sales_user
  puts "\nChecking for Sales User: #{sales_user.email} (ID: #{sales_user.id})"
  
  conversations = Conversation.where(admin_id: sales_user.id)
                              .includes(:buyer, :seller, :admin, :messages)
                              .order(updated_at: :desc)
  
  puts "\n  Total conversations: #{conversations.count}"
  
  # Group by seller
  grouped_by_seller = conversations.group_by(&:seller_id)
  puts "\n  Grouped by seller:"
  
  grouped_by_seller.each do |seller_id, convs|
    seller = convs.first.seller
    seller_name = seller ? (seller.fullname || seller.enterprise_name || seller.email) : "Seller ID: #{seller_id}"
    
    # Get all messages from all conversations with this seller
    all_messages = convs.flat_map(&:messages).sort_by(&:created_at)
    last_message = all_messages.last
    
    puts "\n    #{seller_name}:"
    puts "      Conversations: #{convs.count}"
    puts "      Total messages: #{all_messages.count}"
    puts "      Last message: #{last_message ? "'#{last_message.content[0..50]}...' at #{last_message.created_at}" : 'NONE'}"
    
    # Show conversations without messages
    convs_without_messages = convs.select { |c| c.messages.empty? }
    if convs_without_messages.any?
      puts "      ⚠️  Conversations WITHOUT messages: #{convs_without_messages.map(&:id).join(', ')}"
    end
  end
  
  # Group by buyer
  grouped_by_buyer = conversations.group_by(&:buyer_id)
  puts "\n  Grouped by buyer:"
  
  grouped_by_buyer.each do |buyer_id, convs|
    buyer = convs.first.buyer
    buyer_name = buyer ? (buyer.fullname || buyer.username || buyer.email) : "Buyer ID: #{buyer_id}"
    
    # Get all messages from all conversations with this buyer
    all_messages = convs.flat_map(&:messages).sort_by(&:created_at)
    last_message = all_messages.last
    
    puts "\n    #{buyer_name}:"
    puts "      Conversations: #{convs.count}"
    puts "      Total messages: #{all_messages.count}"
    puts "      Last message: #{last_message ? "'#{last_message.content[0..50]}...' at #{last_message.created_at}" : 'NONE'}"
    
    # Show conversations without messages
    convs_without_messages = convs.select { |c| c.messages.empty? }
    if convs_without_messages.any?
      puts "      ⚠️  Conversations WITHOUT messages: #{convs_without_messages.map(&:id).join(', ')}"
    end
  end
end

# Check for "Denis" specifically
puts "\n" + "=" * 80
puts "Searching for 'Denis'"
puts "=" * 80

# Search in buyers
buyers_named_denis = Buyer.where("fullname ILIKE ? OR username ILIKE ? OR email ILIKE ?", 
                                  "%denis%", "%denis%", "%denis%")
if buyers_named_denis.any?
  buyers_named_denis.each do |buyer|
    puts "\n  Found Buyer: #{buyer.fullname || buyer.username || buyer.email} (ID: #{buyer.id})"
    
    # Find conversations with this buyer
    buyer_conversations = Conversation.where(buyer_id: buyer.id)
                                     .includes(:messages)
    
    puts "    Conversations: #{buyer_conversations.count}"
    
    buyer_conversations.each do |conv|
      message_count = conv.messages.count
      puts "      Conversation ##{conv.id}: #{message_count} messages"
      
      if message_count == 0
        puts "        ⚠️  NO MESSAGES in this conversation!"
        puts "        Created: #{conv.created_at}"
        puts "        Updated: #{conv.updated_at}"
      else
        last_msg = conv.messages.order(created_at: :desc).first
        puts "        Last message: '#{last_msg.content[0..50]}...' at #{last_msg.created_at}"
      end
    end
  end
end

# Search in sellers
sellers_named_denis = Seller.where("fullname ILIKE ? OR enterprise_name ILIKE ? OR email ILIKE ?",
                                   "%denis%", "%denis%", "%denis%")
if sellers_named_denis.any?
  sellers_named_denis.each do |seller|
    puts "\n  Found Seller: #{seller.fullname || seller.enterprise_name || seller.email} (ID: #{seller.id})"
    
    # Find conversations with this seller
    seller_conversations = Conversation.where("seller_id = ? OR inquirer_seller_id = ?",
                                              seller.id, seller.id)
                                      .includes(:messages)
    
    puts "    Conversations: #{seller_conversations.count}"
    
    seller_conversations.each do |conv|
      message_count = conv.messages.count
      puts "      Conversation ##{conv.id}: #{message_count} messages"
      
      if message_count == 0
        puts "        ⚠️  NO MESSAGES in this conversation!"
        puts "        Created: #{conv.created_at}"
        puts "        Updated: #{conv.updated_at}"
      else
        last_msg = conv.messages.order(created_at: :desc).first
        puts "        Last message: '#{last_msg.content[0..50]}...' at #{last_msg.created_at}"
      end
    end
  end
end

puts "\n" + "=" * 80
puts "Summary"
puts "=" * 80
puts ""
puts "Possible reasons for empty conversations:"
puts "  1. Conversation was created but no messages were sent yet"
puts "  2. Messages were deleted but conversation remains"
puts "  3. API is grouping conversations incorrectly"
puts "  4. The backend is returning conversations with empty last_message"
puts ""
puts "Recommendation:"
puts "  - Filter out conversations with no messages in the frontend"
puts "  - OR ensure backend only returns conversations with at least one message"
puts ""
puts "=" * 80

