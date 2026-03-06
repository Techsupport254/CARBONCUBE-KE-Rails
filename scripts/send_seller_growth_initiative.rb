# scripts/send_seller_growth_initiative.rb
# Purpose: Send the refined seller growth initiative MJML email to all sellers in batches.

BATCH_SIZE = 50
DELAY_BETWEEN_BATCHES = 30 # seconds

def send_emails
  sellers = Seller.all
  total_count = sellers.count
  sent_count = 0
  error_count = 0
  batch_count = 0

  puts "Found #{total_count} sellers. Starting batch delivery..."

  sellers.find_in_batches(batch_size: BATCH_SIZE) do |batch|
    batch_count += 1
    puts "--- Processing Batch ##{batch_count} (#{batch.size} sellers) ---"

    batch.each do |seller|
      begin
        # Ensure we skip invalid/missing emails
        next if seller.email.blank? || !seller.email.include?('@')

        # Send the email
        SellerCommunicationsMailer.with(seller: seller).seller_growth_initiative.deliver_now

        sent_count += 1
        print "." # Progress indicator
      rescue => e
        error_count += 1
        puts "\n[!] Error sending to #{seller.email}: #{e.message}"
      end
    end

    puts "\nBatch ##{batch_count} complete. Total sent so far: #{sent_count}/#{total_count}"

    # Only delay if there are more batches likely to come
    if sent_count < total_count
      puts "Waiting #{DELAY_BETWEEN_BATCHES} seconds to prevent SMTP rate-limiting..."
      sleep(DELAY_BETWEEN_BATCHES)
    end
  end

  puts "----------------------------------------------------"
  puts "Delivery finished!"
  puts "Successfully sent: #{sent_count}"
  puts "Errors encountered: #{error_count}"
  puts "Total sellers found: #{total_count}"
  puts "----------------------------------------------------"
end

# Execute the sender
send_emails
