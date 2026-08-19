# frozen_string_literal: true

namespace :qr do
  desc "Test generate a merchant QR Standee image without sending email"
  task :test_generate, [:seller_id] => :environment do |_t, args|
    seller = if args[:seller_id].present?
      Seller.find_by(id: args[:seller_id]) || Seller.find_by(email: args[:seller_id])
    else
      Seller.first
    end

    if seller.nil?
      puts "❌ No seller found."
      exit 1
    end

    puts "🎨 Generating Standee for #{seller.enterprise_name || seller.fullname} (ID: #{seller.id})..."
    image_path = SellerQrStandeeGeneratorService.generate(seller)

    if image_path && File.exist?(image_path)
      size_kb = (File.size(image_path) / 1024.0).round(1)
      puts "✅ QR Standee image successfully generated at:"
      puts "   📁 #{image_path} (#{size_kb} KB)"
    else
      puts "❌ Failed to generate QR Standee image."
    end
  end

  desc "Send QR Standee welcome email with attached image to a specific seller"
  task :send_seller, [:seller_id_or_email, :override_email] => :environment do |_t, args|
    target = args[:seller_id_or_email]
    override_email = args[:override_email]

    if target.blank?
      puts "❌ Usage: rake qr:send_seller[seller_id_or_email,optional_override_email]"
      exit 1
    end

    seller = Seller.find_by(id: target) || Seller.find_by(email: target) || Seller.find_by(username: target)

    if seller.nil?
      puts "❌ Seller '#{target}' not found."
      exit 1
    end

    recipient = override_email.presence || seller.email
    puts "📧 Generating and sending welcome email with QR Standee to #{recipient} (#{seller.enterprise_name})..."

    begin
      WelcomeMailer.welcome_email(seller, override_email).deliver_now
      puts "✅ Welcome email successfully delivered to #{recipient} with attached Standee PNG!"
    rescue => e
      puts "❌ Delivery failed: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  desc "Send QR Standee cards to all active sellers"
  task :send_all, [:limit] => :environment do |_t, args|
    limit = (args[:limit] || 50).to_i
    sellers = Seller.where.not(email: [nil, '']).order(id: :desc).limit(limit)

    puts "🚀 Processing QR Standee dispatch for #{sellers.count} sellers (limit: #{limit})..."
    success_count = 0
    fail_count = 0

    sellers.each_with_index do |seller, idx|
      print "[#{idx + 1}/#{sellers.count}] #{seller.enterprise_name} (#{seller.email})... "
      begin
        SendSellerQrJob.perform_later(seller.id)
        puts "Enqueued ✅"
        success_count += 1
      rescue => e
        puts "Failed ❌ (#{e.message})"
        fail_count += 1
      end
    end

    puts "\n🎉 Complete! Enqueued: #{success_count}, Failed: #{fail_count}"
  end
end
