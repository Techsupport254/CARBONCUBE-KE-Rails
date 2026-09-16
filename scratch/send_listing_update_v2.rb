# Sends the 'seller_listing_update_v2' WhatsApp template ("fresh ads / boost
# visibility" marketing message) to all active sellers with a phone number.
# Every attempt is logged to whatsapp_message_logs (same pattern as
# SendListingUpdateOptimizedJob).
#
# Usage:
#   DATABASE_URL=<prod_url> bundle exec rails runner scratch/send_listing_update_v2.rb            # dry run: counts only
#   DATABASE_URL=<prod_url> bundle exec rails runner scratch/send_listing_update_v2.rb send       # real send
#   DATABASE_URL=<prod_url> bundle exec rails runner scratch/send_listing_update_v2.rb send test@email.com  # single seller

TEMPLATE_NAME = 'seller_listing_update_v2'
LANGUAGE_CODE = 'en'

mode = ARGV[0] || 'dry_run'
target_email = ARGV[1]

scope = Seller.where(deleted: [false, nil], blocked: [false, nil])
              .where.not(phone_number: [nil, ''])

scope = scope.where(email: target_email) if target_email.present?

already_sent_ids = WhatsappMessageLog.for_template(TEMPLATE_NAME).sent_successfully.pluck(:seller_id)
sellers_to_process = scope.where.not(id: already_sent_ids)

puts "Template: #{TEMPLATE_NAME} (#{LANGUAGE_CODE})"
puts "Active sellers with phone: #{scope.count}"
puts "Already sent (skipped): #{already_sent_ids.size}"
puts "To process: #{sellers_to_process.count}"
puts "Mode: #{mode}"

if mode != 'send'
  puts "DRY RUN — no messages sent. Re-run with 'send' to execute."
  exit 0
end

success_count = 0
failure_count = 0

sellers_to_process.find_each do |seller|
  begin
    next if WhatsappMessageLog.already_sent?(seller, TEMPLATE_NAME)

    result = WhatsAppCloudService.send_template(seller.phone_number, TEMPLATE_NAME, LANGUAGE_CODE)

    if result.is_a?(Hash) && result[:success]
      WhatsappMessageLog.mark_as_sent(seller, TEMPLATE_NAME, seller.phone_number, result[:message_id])
      success_count += 1
    else
      error_msg = result.is_a?(Hash) ? result[:error] : 'Unknown error'
      WhatsappMessageLog.create(
        seller: seller,
        phone_number: seller.phone_number,
        template_name: TEMPLATE_NAME,
        sent_successfully: false,
        error_message: error_msg
      )
      failure_count += 1
      puts "FAILED seller #{seller.id} (#{seller.email}): #{error_msg}"
    end

    puts "Progress: #{success_count + failure_count}/#{sellers_to_process.count}" if (success_count + failure_count) % 50 == 0
    sleep(0.1)
  rescue => e
    failure_count += 1
    puts "ERROR seller #{seller.id} (#{seller.email}): #{e.message}"
    WhatsappMessageLog.create(
      seller: seller,
      phone_number: seller.phone_number.to_s,
      template_name: TEMPLATE_NAME,
      sent_successfully: false,
      error_message: e.message
    ) rescue nil
  end
end

puts "Done. Sent: #{success_count}, Failed: #{failure_count}"
