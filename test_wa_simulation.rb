# test_wa_simulation.rb
require_relative 'config/environment'

payload = {
  'object' => 'whatsapp_business_account',
  'entry' => [{
    'changes' => [{
      'field' => 'messages',
      'value' => {
        'metadata' => { 'display_phone_number' => '254716404137', 'phone_number_id' => '123' },
        'messages' => [{
          'from' => '254716404137',
          'id' => "wamid.sim_#{Time.now.to_i}",
          'timestamp' => Time.now.to_i.to_s,
          'text' => { 'body' => 'Simulated message for WA flag' },
          'type' => 'text'
        }]
      }
    }]
  }]
}

begin
  puts "Running simulation..."
  WhatsAppCloudService.handle_webhook_payload(payload)
  puts "Success!"
  
  last_msg = Message.last
  puts "Last Message: #{last_msg.content}"
  puts "Conversation is_whatsapp: #{last_msg.conversation.is_whatsapp}"
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(10).join("\n")
end
