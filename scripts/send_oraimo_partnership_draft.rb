# frozen_string_literal: true

# Script to send approved Oraimo Marketplace Partnership Draft Email
# NOTE: Restricted STRICTLY to kiruivictor097@gmail.com.
# Usage: /Users/user/.local/bin/mise exec -- bundle exec rails runner scripts/send_oraimo_partnership_draft.rb

target_email = "kiruivictor097@gmail.com"

subject = "Marketplace Partnership — Oraimo Kenya × Carbon Cube Kenya"

message = <<~MARKDOWN
Dear Oraimo Kenya Team,

I hope this email finds you well.

We are reaching out on behalf of [Carbon Cube Kenya](https://carboncube-ke.com), Kenya's trusted online marketplace connecting verified sellers and businesses with buyers across the country.

A significant number of sellers across our marketplace already actively list and sell Oraimo products—including your popular FreePods series, AniFast™ power banks, fast chargers, smartwatches, and personal care accessories—driven by steady, daily buyer search demand on our platform.

Because your brand already enjoys strong organic interest among our buyers, we would like to explore onboarding Oraimo Kenya directly as an official seller. This will provide your brand with an official, verified channel on the marketplace to showcase your full genuine catalog, set authoritative pricing, and engage directly with ready-to-buy consumers.

Our marketplace model is straightforward:
* **Carbon Cube Kenya** provides the discovery platform, search visibility, and buyer traffic.
* **Oraimo** retains full control over its inventory, pricing, order processing, fulfillment, and delivery.

We believe an official presence will help capture existing platform demand while reinforcing trust, genuine product origin, and Carlcare warranty backing for consumers.

We would appreciate the opportunity to have a brief introductory conversation with your e-commerce or business development team to explore getting your official catalog listed.

Thank you for your time and consideration. We look forward to hearing from you.

Kind regards,

**Carbon Cube Kenya**  
[carboncube-ke.com](https://carboncube-ke.com)  
[info@carboncube-ke.com](mailto:info@carboncube-ke.com)
MARKDOWN

puts "=================================================="
puts "Preparing Oraimo Clean Marketplace Draft Email..."
puts "Target Recipient: #{target_email} (RESTRICTED TEST)"
puts "Subject: #{subject}"
puts "=================================================="

# Safety check: Prevent sending to any domain other than the approved test recipient
unless target_email == "kiruivictor097@gmail.com"
  raise "SECURITY ABORT: Email recipient must strictly be kiruivictor097@gmail.com"
end

mock_user = OpenStruct.new(
  email: target_email,
  fullname: "Team",
  enterprise_name: "Carbon Cube Kenya"
)

begin
  mail_message = SellerCommunicationsMailer.with(
    user: mock_user,
    user_type: "seller",
    to_email: target_email,
    subject: subject,
    message: message
  ).custom_communication

  # Deliver the email synchronously
  mail_message.deliver_now

  puts "✅ SUCCESS: Clean draft email successfully delivered to #{target_email}!"
  puts "Message-ID: #{mail_message.message_id}"
rescue => e
  puts "❌ ERROR: Delivery failed: #{e.message}"
  puts e.backtrace.first(8)
end
