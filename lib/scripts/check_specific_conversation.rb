# Check specific conversation for unread messages
# Run with: rails runner lib/scripts/check_specific_conversation.rb

puts "=" * 80
puts "Specific Conversation Unread Check"
puts "=" * 80
puts ""

# Find conversation 244
conversation = Conversation.find_by(id: 244)
unless conversation
  puts "Conversation 244 not found"
  exit
end

puts "Conversation #{conversation.id}:"
puts "  Buyer ID: #{conversation.buyer_id}"
puts "  Seller ID: #{conversation.seller_id}"
puts "  Admin ID: #{conversation.admin_id || 'nil'}"
puts "  Inquirer Seller ID: #{conversation.inquirer_seller_id || 'nil'}"
puts ""

# Get all messages
all_messages = conversation.messages.order(:created_at)
puts "All Messages (#{all_messages.count}):"
all_messages.each do |msg|
  puts "  Message ID: #{msg.id}"
  puts "    Sender Type: #{msg.sender_type}"
  puts "    Sender ID: #{msg.sender_id}"
  puts "    Read At: #{msg.read_at || 'nil (unread)'}"
  puts "    Status: #{msg.status || 'nil'}"
  puts "    Content: #{msg.content[0..50]}..." if msg.content
  puts ""
end

# Check unread for Buyer
if conversation.buyer_id
  buyer = Buyer.find_by(id: conversation.buyer_id)
  if buyer
    puts "=" * 80
    puts "Buyer Perspective (#{buyer.id}):"
    puts "=" * 80
    
    # Count unread messages from Seller, Admin, SalesUser
    unread_from_others = conversation.messages
      .where(sender_type: ['Seller', 'Admin', 'SalesUser'])
      .where(read_at: nil)
      .count
    
    puts "Unread messages from Sellers/Admins/SalesUsers: #{unread_from_others}"
    
    # Show details
    unread_messages = conversation.messages
      .where(sender_type: ['Seller', 'Admin', 'SalesUser'])
      .where(read_at: nil)
    
    if unread_messages.any?
      puts "Unread message details:"
      unread_messages.each do |msg|
        puts "  Message #{msg.id}: from #{msg.sender_type} #{msg.sender_id}"
      end
    else
      puts "No unread messages for this buyer"
    end
    puts ""
  end
end

# Check unread for Seller
if conversation.seller_id
  seller = Seller.find_by(id: conversation.seller_id)
  if seller
    puts "=" * 80
    puts "Seller Perspective (#{seller.id}):"
    puts "=" * 80
    
    # Check if seller-to-seller conversation
    if conversation.seller_id.present? && conversation.inquirer_seller_id.present?
      # Seller-to-seller: count messages not from current seller
      unread_from_others = conversation.messages
        .where.not(sender_id: seller.id)
        .where(read_at: nil)
        .count
      puts "Seller-to-seller conversation"
    else
      # Regular: count from Buyer, Admin, SalesUser
      unread_from_others = conversation.messages
        .where(sender_type: ['Buyer', 'Admin', 'SalesUser'])
        .where(read_at: nil)
        .count
      puts "Regular conversation"
    end
    
    puts "Unread messages: #{unread_from_others}"
    
    # Show details
    if conversation.seller_id.present? && conversation.inquirer_seller_id.present?
      unread_messages = conversation.messages
        .where.not(sender_id: seller.id)
        .where(read_at: nil)
    else
      unread_messages = conversation.messages
        .where(sender_type: ['Buyer', 'Admin', 'SalesUser'])
        .where(read_at: nil)
    end
    
    if unread_messages.any?
      puts "Unread message details:"
      unread_messages.each do |msg|
        puts "  Message #{msg.id}: from #{msg.sender_type} #{msg.sender_id}"
      end
    else
      puts "No unread messages for this seller"
    end
    puts ""
  end
end

# Check unread for Admin (if any)
if conversation.admin_id
  admin = Admin.find_by(id: conversation.admin_id) || SalesUser.find_by(id: conversation.admin_id)
  if admin
    puts "=" * 80
    puts "#{admin.class.name} Perspective (#{admin.id}):"
    puts "=" * 80
    
    unread_from_others = conversation.messages
      .where(sender_type: ['Seller', 'Buyer', 'Purchaser'])
      .where(read_at: nil)
      .count
    
    puts "Unread messages from Sellers/Buyers/Purchasers: #{unread_from_others}"
    
    unread_messages = conversation.messages
      .where(sender_type: ['Seller', 'Buyer', 'Purchaser'])
      .where(read_at: nil)
    
    if unread_messages.any?
      puts "Unread message details:"
      unread_messages.each do |msg|
        puts "  Message #{msg.id}: from #{msg.sender_type} #{msg.sender_id}"
      end
    else
      puts "No unread messages for this #{admin.class.name}"
    end
    puts ""
  end
end

puts "=" * 80
puts "Done"
puts "=" * 80

