namespace :profile_pictures do
  desc "Fix missing profile pictures: set DB to Google URL for users with cached URLs but missing files (no file cache)"
  task fix_missing: :environment do
    puts "Starting to fix missing profile pictures (write Google URL to DB only)..."
    puts ""

    buyers_with_cached = Buyer.where("profile_picture LIKE '/cached_profile_pictures/%'")
    sellers_with_cached = Seller.where("profile_picture LIKE '/cached_profile_pictures/%'")

    total_users = buyers_with_cached.count + sellers_with_cached.count
    fixed_count = 0
    skipped_count = 0

    puts "Found #{buyers_with_cached.count} buyers and #{sellers_with_cached.count} sellers with cached URLs"
    puts ""

    buyers_with_cached.find_each do |buyer|
      filename = buyer.profile_picture.gsub('/cached_profile_pictures/', '')
      file_path = Rails.root.join('public', 'cached_profile_pictures', filename)

      unless File.exist?(file_path)
        puts "Missing file for buyer #{buyer.email}: #{filename}"

        google_url = (buyer.provider.to_s =~ /\Agoogle/ && buyer.uid.present?) ? "https://lh3.googleusercontent.com/a/#{buyer.uid}=s400" : nil

        if google_url.present?
          buyer.update_column(:profile_picture, google_url)
          puts "  ✅ Set profile_picture to Google URL in DB"
          fixed_count += 1
        else
          puts "  ⚠️  No Google UID available, clearing cached URL"
          buyer.update_column(:profile_picture, nil)
          skipped_count += 1
        end
      end
    end

    sellers_with_cached.find_each do |seller|
      filename = seller.profile_picture.gsub('/cached_profile_pictures/', '')
      file_path = Rails.root.join('public', 'cached_profile_pictures', filename)

      unless File.exist?(file_path)
        puts "Missing file for seller #{seller.email}: #{filename}"

        google_url = (seller.provider.to_s =~ /\Agoogle/ && seller.uid.present?) ? "https://lh3.googleusercontent.com/a/#{seller.uid}=s400" : nil

        if google_url.present?
          seller.update_column(:profile_picture, google_url)
          puts "  ✅ Set profile_picture to Google URL in DB"
          fixed_count += 1
        else
          puts "  ⚠️  No Google UID available, clearing cached URL"
          seller.update_column(:profile_picture, nil)
          skipped_count += 1
        end
      end
    end

    puts ""
    puts "=== Summary ==="
    puts "Total users with cached URLs: #{total_users}"
    puts "Fixed (Google URL written to DB): #{fixed_count}"
    puts "Cleared (no UID): #{skipped_count}"
    puts ""
    puts "✅ Completed!"
  end
end

