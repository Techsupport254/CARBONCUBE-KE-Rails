# frozen_string_literal: true

require 'benchmark'

# Prevent synchronous 20-second DB unread badge scans during bulk runner process
class UpdateUnreadCountsJob
  def self.perform_now(*args)
    # no-op during runner broadcast to prevent 20-second DB locks per seller
  end
end

def with_db_retry(max_retries = 3)
  retries = 0
  begin
    yield
  rescue ActiveRecord::ConnectionNotEstablished, PG::ConnectionBad, PG::UnableToSend => e
    retries += 1
    if retries <= max_retries
      puts "⚠️ DB connection error (#{e.class.name}), reconnecting (attempt #{retries}/#{max_retries})..."
      sleep 2
      ActiveRecord::Base.connection_handler.clear_all_connections!
      ActiveRecord::Base.establish_connection
      retry
    else
      raise e
    end
  end
end

excluded_phones = [
  '0712768007', # Jamaceke / JarnaceKe
  '0700805582', # MimmisTech Communication
  '0725059500', # Yang Merchant
  '0790293118', # Suzietech Communication
  '0703794034'  # Mary Phones and accessories
]

puts "============================================================"
puts "  RESUMING GENERAL BROADCAST: WHY VERIFY YOUR BUSINESS"
puts "============================================================"
puts "Excluding 5 apology recipients: #{excluded_phones.join(', ')}"

admin = Admin.find_by(email: 'info@carboncube-ke.com') || Admin.first
unless admin
  puts "❌ ERROR: Admin user not found!"
  exit 1
end
puts "Using Admin: #{admin.username} (#{admin.email})"

sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
                .where.not(phone_number: excluded_phones)

total_count = sellers.count
puts "Total eligible sellers in database: #{total_count}"
puts "Channels: WhatsApp, Email, In-App"
puts "============================================================"

stats = {
  processed: 0,
  whatsapp_sent: 0,
  whatsapp_skipped: 0,
  whatsapp_failed: 0,
  email_sent: 0,
  email_skipped: 0,
  email_failed: 0,
  in_app_sent: 0,
  in_app_skipped: 0,
  in_app_failed: 0
}

start_time = Time.current

sellers.find_each(batch_size: 50) do |seller|
  stats[:processed] += 1
  recipient_name = seller.fullname.presence || seller.enterprise_name

  with_db_retry do
    # -----------------------------------------------------------
    # 1. WHATSAPP (seller_why_verify_business)
    # -----------------------------------------------------------
    already_sent_wa = WhatsappMessageLog.already_sent?(seller, 'seller_why_verify_business')

    if already_sent_wa
      stats[:whatsapp_skipped] += 1
    elsif seller.phone_number.present? && seller.whatsapp_notifications
      begin
        wa_result = WhatsAppCloudService.send_template(
          seller.phone_number,
          'seller_why_verify_business',
          'en',
          []
        )

        if wa_result[:success]
          stats[:whatsapp_sent] += 1
          WhatsappMessageLog.mark_as_sent(seller, 'seller_why_verify_business', seller.phone_number, wa_result[:message_id])
        else
          stats[:whatsapp_failed] += 1
          puts "❌ WA failed for #{seller.phone_number}: #{wa_result[:error]}"
        end
      rescue StandardError => e
        stats[:whatsapp_failed] += 1
        puts "❌ WA exception for #{seller.phone_number}: #{e.message}"
      end
    else
      stats[:whatsapp_skipped] += 1
    end

    # -----------------------------------------------------------
    # 2. EMAIL (why_verify_business)
    # -----------------------------------------------------------
    # If WA was already sent in previous run, email was already sent too; skip to prevent duplicates
    if already_sent_wa
      stats[:email_skipped] += 1
    elsif seller.email.present? && seller.email.include?('@')
      begin
        mail = SellerCommunicationsMailer.with(
          user: seller,
          to_email: seller.email,
          subject: "Why verify your business on Carbon Cube Kenya?"
        ).why_verify_business

        mail.deliver_now
        stats[:email_sent] += 1
      rescue StandardError => e
        stats[:email_failed] += 1
        puts "❌ Email exception for #{seller.email}: #{e.message}"
      end
    end

    # -----------------------------------------------------------
    # 3. IN-APP MESSAGE
    # -----------------------------------------------------------
    begin
      conv = Conversation.find_or_create_by!(
        admin_id: admin.id,
        seller_id: seller.id,
        ad_id: nil,
        buyer_id: nil,
        inquirer_seller_id: nil
      )

      # Check in-app message decrypted (since content is encrypted at rest)
      already_messaged = conv.messages.where(sender: admin).where('created_at > ?', 1.day.ago).any? do |m|
        m.content.to_s.include?("Why verify your business on Carbon Cube Kenya?")
      end

      if already_messaged
        stats[:in_app_skipped] += 1
      else
        in_app_text = <<~MARKDOWN
          **Why verify your business on Carbon Cube Kenya?**

          Hello **#{recipient_name}** 👋

          Why verify your business on Carbon Cube Kenya?

          A verification badge helps build trust, makes your business stand out, and gives potential buyers more confidence when dealing with you.

          **Your products matter, but trust matters too!**

          Reply to this message or contact our team to have one of our agents help you verify your business.

          • WhatsApp: [+254 727 854 903](https://wa.me/254727854903)
          • Support: [carboncube-ke.com/contact-us](https://carboncube-ke.com/contact-us)

          Best regards,  
          **Carbon Cube Kenya Team**
        MARKDOWN

        conv.messages.create!(
          content: in_app_text,
          sender: admin
        )

        stats[:in_app_sent] += 1
      end
    rescue StandardError => e
      stats[:in_app_failed] += 1
      puts "❌ In-App exception for #{seller.enterprise_name}: #{e.message}"
    end
  end

  # Log progress every 20 sellers
  if stats[:processed] % 20 == 0 || stats[:processed] == total_count
    elapsed = (Time.current - start_time).round(1)
    rate = (stats[:processed] / [elapsed, 1].max).round(1)
    puts "[Progress #{stats[:processed]}/#{total_count}] (#{elapsed}s, #{rate}/s) - WA: #{stats[:whatsapp_sent]} sent, #{stats[:whatsapp_skipped]} skipped | Email: #{stats[:email_sent]} sent, #{stats[:email_skipped]} skipped | In-App: #{stats[:in_app_sent]} sent, #{stats[:in_app_skipped]} skipped"
  end

  # Polite sleep
  sleep 0.05
end

total_elapsed = (Time.current - start_time).round(1)

puts "\n============================================================"
puts "               BROADCAST COMPLETE IN #{total_elapsed}s"
puts "============================================================"
puts "Total sellers evaluated: #{stats[:processed]}"
puts "WhatsApp: #{stats[:whatsapp_sent]} sent, #{stats[:whatsapp_skipped]} skipped, #{stats[:whatsapp_failed]} failed"
puts "Email:    #{stats[:email_sent]} sent, #{stats[:email_skipped]} skipped, #{stats[:email_failed]} failed"
puts "In-App:   #{stats[:in_app_sent]} sent, #{stats[:in_app_skipped]} skipped, #{stats[:in_app_failed]} failed"
puts "============================================================"
