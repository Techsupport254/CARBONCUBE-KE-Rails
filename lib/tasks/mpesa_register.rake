namespace :mpesa do
  desc "Register M-Pesa C2B URLs"
  task register_urls: :environment do
    puts "Registering M-Pesa C2B URLs..."
    response = MpesaC2bService.register_urls
    puts response
  end
end
