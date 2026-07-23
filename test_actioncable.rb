require './config/environment'

puts "Testing ActionCable Real-time Delivery..."

# 1. Capture Broadcasts
class MockServer
  attr_reader :broadcasts

  def initialize
    @broadcasts = []
  end

  def broadcast(channel, payload)
    @broadcasts << { channel: channel, payload: payload }
  end
end

mock_server = MockServer.new
ActionCable.server = mock_server

# 2. Setup Test Data
puts "Setting up test data..."
buyer = Buyer.find_by(email: "kiruivictor097@gmail.com") || Buyer.find_by(email: "optisoftkenya@gmail.com") || Buyer.first
seller = Seller.find_by(email: "optisoftkenya@gmail.com") || Seller.find_by(email: "kiruivictor097@gmail.com") || Seller.first

if buyer.nil? || seller.nil?
  puts "ERROR: Could not find buyers/sellers with those emails!"
  exit
end

ad = seller.ads.first || Ad.first
conversation = Conversation.find_or_create_by!(buyer: buyer, seller: seller, ad_id: ad&.id)

# 3. Test Message Creation (should trigger broadcast_new_message)
puts "Creating a new message..."
msg = conversation.messages.create!(
  sender: buyer,
  content: "Hello from ActionCable test #{Time.current.to_i}"
)

# 4. Verify Broadcasts
puts "\nResults:"
puts "Number of broadcasts: #{mock_server.broadcasts.size}"

mock_server.broadcasts.each_with_index do |b, i|
  puts "\nBroadcast #{i + 1}:"
  puts "Channel: #{b[:channel]}"
  puts "Payload Type: #{b[:payload][:type]}"
  puts "Message Content: #{b[:payload][:message][:content] || b[:payload][:message]['content']}"
end

if mock_server.broadcasts.size == 2
  puts "\nSUCCESS: Exactly 2 broadcasts found (1 for buyer, 1 for seller). No duplicates!"
elsif mock_server.broadcasts.size > 2
  puts "\nFAILURE: Too many broadcasts. Possible duplicate broadcast logic."
else
  puts "\nFAILURE: Missing broadcasts."
end

# 5. Clean up
msg.destroy
