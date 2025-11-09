namespace :profile_pictures do
  desc "Re-cache missing profile pictures for users with cached URLs but missing files"
  task fix_missing: :environment do
    puts "Starting to fix missing profile pictures..."
    puts ""
    
    # Find all buyers and sellers with cached profile picture URLs
    buyers_with_cached = Buyer.where("profile_picture LIKE '/cached_profile_pictures/%'")
    sellers_with_cached = Seller.where("profile_picture LIKE '/cached_profile_pictures/%'")
    
    total_users = buyers_with_cached.count + sellers_with_cached.count
    fixed_count = 0
    failed_count = 0
    
    puts "Found #{buyers_with_cached.count} buyers and #{sellers_with_cached.count} sellers with cached URLs"
    puts ""
    
    # Process buyers
    buyers_with_cached.find_each do |buyer|
      filename = buyer.profile_picture.gsub('/cached_profile_pictures/', '')
      file_path = Rails.root.join('public', 'cached_profile_pictures', filename)
      
      unless File.exist?(file_path)
        puts "Missing file for buyer #{buyer.email}: #{filename}"
        
        # Try to get original Google URL
        google_url = nil
        
        # Check if we can construct it from UID
        if buyer.provider == 'google' && buyer.uid.present?
          google_url = "https://lh3.googleusercontent.com/a/#{buyer.uid}=s400"
        end
        
        # Try to re-cache
        if google_url
          begin
            cache_service = ProfilePictureCacheService.new
            cached_url = cache_service.cache_google_profile_picture(google_url, buyer.id)
            
            if cached_url.present?
              buyer.update_column(:profile_picture, cached_url)
              puts "  ✅ Re-cached: #{cached_url}"
              fixed_count += 1
            else
              puts "  ❌ Failed to re-cache"
              failed_count += 1
            end
          rescue => e
            puts "  ❌ Error: #{e.message}"
            failed_count += 1
          end
        else
          puts "  ⚠️  No Google URL available for re-caching"
          failed_count += 1
        end
      end
    end
    
    # Process sellers
    sellers_with_cached.find_each do |seller|
      filename = seller.profile_picture.gsub('/cached_profile_pictures/', '')
      file_path = Rails.root.join('public', 'cached_profile_pictures', filename)
      
      unless File.exist?(file_path)
        puts "Missing file for seller #{seller.email}: #{filename}"
        
        # Try to get original Google URL
        google_url = nil
        
        # Check if we can construct it from UID
        if seller.provider == 'google' && seller.uid.present?
          google_url = "https://lh3.googleusercontent.com/a/#{seller.uid}=s400"
        end
        
        # Try to re-cache
        if google_url
          begin
            cache_service = ProfilePictureCacheService.new
            cached_url = cache_service.cache_google_profile_picture(google_url, seller.id)
            
            if cached_url.present?
              seller.update_column(:profile_picture, cached_url)
              puts "  ✅ Re-cached: #{cached_url}"
              fixed_count += 1
            else
              puts "  ❌ Failed to re-cache"
              failed_count += 1
            end
          rescue => e
            puts "  ❌ Error: #{e.message}"
            failed_count += 1
          end
        else
          puts "  ⚠️  No Google URL available for re-caching"
          failed_count += 1
        end
      end
    end
    
    puts ""
    puts "=== Summary ==="
    puts "Total users checked: #{total_users}"
    puts "Fixed: #{fixed_count}"
    puts "Failed: #{failed_count}"
    puts ""
    puts "✅ Completed!"
  end
end

