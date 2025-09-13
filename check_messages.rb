puts '=== CONVERSATIONS ==='
Conversation.all.each do |c|
  buyer_name = c.buyer&.fullname rescue 'NIL'
  seller_name = c.seller&.enterprise_name rescue 'NIL'
  puts "ID: #{c.id}, Buyer: #{c.buyer_id} (#{buyer_name}), Seller: #{c.seller_id} (#{seller_name}), Ad: #{c.ad_id}"
end

puts "\n=== MESSAGES ==="
Message.all.each do |m|
  content_preview = m.content.length > 50 ? m.content[0..50] + '...' : m.content
  puts "ID: #{m.id}, Conversation: #{m.conversation_id}, Sender: #{m.sender_type} #{m.sender_id}, Content: #{content_preview}"
end
