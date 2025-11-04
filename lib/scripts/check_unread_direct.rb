# Direct check of unread messages in database
# Run with: rails runner lib/scripts/check_unread_direct.rb

puts "=" * 80
puts "Direct Unread Messages Database Check"
puts "=" * 80
puts ""

# Check total messages and unread status
total_messages = Message.count
unread_messages = Message.where(read_at: nil).count
read_messages = Message.where.not(read_at: nil).count

puts "Message Statistics:"
puts "  Total messages: #{total_messages}"
puts "  Unread messages (read_at: nil): #{unread_messages}"
puts "  Read messages (read_at: not nil): #{read_messages}"
puts ""

# Check messages by sender type
puts "Messages by Sender Type:"
Message.group(:sender_type).count.each do |sender_type, count|
  unread = Message.where(sender_type: sender_type, read_at: nil).count
  puts "  #{sender_type}: #{count} total, #{unread} unread"
end
puts ""

# Sample unread messages
puts "Sample Unread Messages (first 10):"
Message.where(read_at: nil).limit(10).each do |msg|
  conversation = msg.conversation
  puts "  Message ID: #{msg.id}"
  puts "    Conversation ID: #{msg.conversation_id}"
  puts "    Sender Type: #{msg.sender_type}"
  puts "    Sender ID: #{msg.sender_id}"
  puts "    Read At: #{msg.read_at || 'nil (unread)'}"
  puts "    Status: #{msg.status || 'nil'}"
  puts "    Created At: #{msg.created_at}"
  puts "    Conversation - Buyer ID: #{conversation.buyer_id}, Seller ID: #{conversation.seller_id}, Admin ID: #{conversation.admin_id}"
  puts ""
end

# Check unread counts by role logic
puts "=" * 80
puts "Unread Counts by Role Logic"
puts "=" * 80
puts ""

# For Buyers
buyers = Buyer.limit(5)
buyers.each do |buyer|
  conversations = Conversation.where(buyer_id: buyer.id).active_participants
  total_unread = 0
  conversations.each do |conv|
    unread = conv.messages.where(sender_type: ['Seller', 'Admin', 'SalesUser']).where(read_at: nil).count
    total_unread += unread
  end
  if conversations.count > 0
    puts "Buyer #{buyer.id} (#{buyer.email || buyer.username}):"
    puts "  Conversations: #{conversations.count}"
    puts "  Total unread: #{total_unread}"
    puts ""
  end
end

# For Sellers
sellers = Seller.limit(5)
sellers.each do |seller|
  conversations = Conversation.where(
    "(seller_id = ? OR inquirer_seller_id = ?)", 
    seller.id, 
    seller.id
  ).active_participants
  
  total_unread = 0
  conversations.each do |conv|
    if conv.seller_id.present? && conv.inquirer_seller_id.present?
      # Seller-to-seller
      unread = conv.messages.where.not(sender_id: seller.id).where(read_at: nil).count
    else
      # Regular
      unread = conv.messages.where(sender_type: ['Buyer', 'Admin', 'SalesUser']).where(read_at: nil).count
    end
    total_unread += unread
  end
  
  if conversations.count > 0
    puts "Seller #{seller.id} (#{seller.email || seller.enterprise_name}):"
    puts "  Conversations: #{conversations.count}"
    puts "  Total unread: #{total_unread}"
    puts ""
  end
end

# For Admins
admins = Admin.limit(5)
admins.each do |admin|
  conversations = Conversation.where(admin_id: admin.id).active_participants
  total_unread = 0
  conversations.each do |conv|
    unread = conv.messages.where(sender_type: ['Seller', 'Buyer', 'Purchaser']).where(read_at: nil).count
    total_unread += unread
  end
  if conversations.count > 0
    puts "Admin #{admin.id} (#{admin.email}):"
    puts "  Conversations: #{conversations.count}"
    puts "  Total unread: #{total_unread}"
    puts ""
  end
end

# For Sales Users
sales_users = SalesUser.limit(5)
sales_users.each do |sales_user|
  conversations = Conversation.where(admin_id: sales_user.id).active_participants
  total_unread = 0
  conversations.each do |conv|
    unread = conv.messages.where(sender_type: ['Seller', 'Buyer', 'Purchaser']).where(read_at: nil).count
    total_unread += unread
  end
  if conversations.count > 0
    puts "Sales User #{sales_user.id} (#{sales_user.email}):"
    puts "  Conversations: #{conversations.count}"
    puts "  Total unread: #{total_unread}"
    puts ""
  end
end

puts "=" * 80
puts "Done"
puts "=" * 80

