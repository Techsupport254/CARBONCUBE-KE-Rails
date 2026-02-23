require_relative 'config/environment'

puts "--- FCM Debugging ---"
puts "FIREBASE_PROJECT_ID: #{ENV['FIREBASE_PROJECT_ID'].inspect}"
puts "FIREBASE_SERVICE_ACCOUNT_PATH: #{ENV['FIREBASE_SERVICE_ACCOUNT_PATH'].inspect}"
puts "FIREBASE_SERVICE_ACCOUNT_JSON raw length: #{ENV['FIREBASE_SERVICE_ACCOUNT_JSON'].to_s.length}"
puts "FIREBASE_SERVICE_ACCOUNT_JSON start: #{ENV['FIREBASE_SERVICE_ACCOUNT_JSON'].to_s[0, 50].inspect}"

bundle = PushNotificationService.send(:firebase_credentials_bundle)
puts "Credential Source: #{bundle[:source]}"
puts "Credentials present?: #{bundle[:credentials].present?}"

if bundle[:credentials].is_a?(Hash)
  puts "Project ID from Credentials: #{bundle[:credentials]['project_id'].inspect}"
else
  puts "Credentials is not a Hash: #{bundle[:credentials].class}"
end

project_id = PushNotificationService.get_project_id
puts "Final Project ID: #{project_id.inspect}"

puts "Running send_notification_with_details test..."
payload = { title: "Test", body: "Test body" }
# Using a bogus token just to test the validation part
result = PushNotificationService.send_notification_with_details(["bogus_token"], payload)
puts "Result Success: #{result[:success]}"
puts "Result Error: #{result[:error].inspect}"
puts "Result Message: #{result[:message].inspect}"
puts "Result Project ID: #{result[:project_id].inspect}"

