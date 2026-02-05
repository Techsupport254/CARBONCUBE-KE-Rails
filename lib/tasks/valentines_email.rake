# lib/tasks/valentines_email.rake
namespace :valentines do
  desc "Generate Valentine's email CSV for all active sellers with real data"
  task generate_csv: :environment do
    require 'csv'
    
    puts "🔍 Fetching ALL sellers (including flagged/blocked) from database..."
    
    # Get all sellers that are not deleted (including flagged, blocked, and 0 ads)
    sellers = Seller.where(deleted: false)
                    .includes(:ads, :reviews, :seller_tier)
                    .order(created_at: :desc)
    
    total_sellers = sellers.count
    puts "✅ Found #{total_sellers} total sellers"
    
    if total_sellers == 0
      puts "❌ No active sellers found. Check your database."
      exit
    end
    
    # Generate filename with timestamp
    filename = "valentines_sellers_#{Date.today.strftime('%Y%m%d')}.csv"
    filepath = Rails.root.join('tmp', filename)
    
    puts "📝 Generating CSV: #{filepath}"
    
    CSV.open(filepath, "w") do |csv|
      # Headers - must match Mailjet merge variables
      csv << [
        'fullname',
        'email',
        'enterprise_name',
        'ads_count',
        'total_clicks',
        'days_since_last_ad',
        'tier_name',
        'gender',
        'profile_picture'
      ]
      
      processed = 0
      errors = 0
      
      sellers.find_each do |seller|
        begin
          # Get analytics data for this seller's ads
          ad_ids = seller.ads.where(deleted: false).pluck(:id)
          
          # Total clicks from ClickEvents (excluding internal users)
          total_clicks = if ad_ids.any?
            ClickEvent.excluding_internal_users
                      .where(ad_id: ad_ids)
                      .count
          else
            0
          end
          
          # Total views - use Analytics table or default to estimated based on clicks
          # Views are typically 3-5x higher than clicks
          total_views = if ad_ids.any? && defined?(Analytic)
            # Try to get view events from Analytics table
            Analytic.where("data->>'ad_id' IN (?)", ad_ids.map(&:to_s))
                    .where(type: ['AdView', 'PageView', 'page_view', 'ad_view'])
                    .count
          else
            # Estimate: views are typically 3-4x clicks
            (total_clicks * 3.5).to_i
          end
          
          # If no views data available, use a conservative estimate
          total_views = (total_clicks * 3).to_i if total_views == 0 && total_clicks > 0
          
          # Days since last ad upload
          last_ad = seller.ads.where(deleted: false)
                             .order(created_at: :desc)
                             .first
          
          days_since_last = if last_ad
            ((Time.current - last_ad.created_at) / 1.day).to_i
          else
            999 # Very old or no ads
          end
          
          # Get tier name
          tier_name = if seller.seller_tier&.tier
            seller.seller_tier.tier.name
          else
            'Free'
          end
          
          # Format last_active_at
          last_active = if seller.last_active_at
            seller.last_active_at.strftime('%B %d, %Y')
          else
            'Recently'
          end
          
          # Format created_at
          member_since = seller.created_at.strftime('%B %Y')
          
          # Average rating
          avg_rating = seller.average_rating.round(1)
          
          # Total reviews
          total_reviews = seller.reviews.count
          
          # Generate username if missing
          username = seller.username.presence || 
                    seller.enterprise_name.parameterize || 
                    "seller-#{seller.id}"
          
          # Write row to CSV
          csv << [
            seller.fullname,
            seller.email,
            seller.enterprise_name,
            seller.ads_count,
            total_clicks,
            days_since_last,
            tier_name,
            seller.gender,
            seller.profile_picture.presence || "https://carboncube-ke.com/default-avatar.png"
          ]
          
          processed += 1
          
          # Progress indicator
          if processed % 100 == 0
            puts "  ⏳ Processed #{processed}/#{total_sellers} sellers..."
          end
          
        rescue => e
          errors += 1
          puts "  ⚠️  Error processing seller #{seller.id}: #{e.message}"
        end
      end
      
      puts "\n✅ CSV Generation Complete!"
      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      puts "📊 Summary:"
      puts "  Total sellers: #{total_sellers}"
      puts "  Successfully processed: #{processed}"
      puts "  Errors: #{errors}"
      puts "  Output file: #{filepath}"
      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      puts "\n📤 Next steps:"
      puts "  1. Download: #{filepath}"
      puts "  2. Upload to Mailjet: https://app.mailjet.com"
      puts "  3. Create campaign with merge variables"
      puts "  4. Test with victorquaint@gmail.com first!"
      puts "\n💡 Tip: Review the CSV to ensure data looks correct before sending."
    end
    
    # Display sample data (first 3 rows)
    puts "\n📋 Sample Data (first 3 sellers):"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    sample_data = CSV.read(filepath, headers: true).first(3)
    sample_data.each_with_index do |row, i|
      puts "\n#{i + 1}. #{row['fullname']} (#{row['email']})"
      puts "   Shop: #{row['enterprise_name']}"
      puts "   Ads: #{row['ads_count']} | Clicks: #{row['total_clicks']} | Views: #{row['total_views']}"
      puts "   Tier: #{row['tier_name']} | Rating: #{row['avg_rating']}⭐ (#{row['total_reviews']} reviews)"
      puts "   Last ad: #{row['days_since_last_ad']} days ago | Member since: #{row['created_at']}"
    end
    
    puts "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "🚀 Ready to launch Valentine's campaign!"
  end
  
  desc "Test Valentine's email CSV generation with just Victor Quaint"
  task test_csv: :environment do
    require 'csv'
    
    puts "🔍 Fetching Victor Quaint seller..."
    
    seller = Seller.find_by(email: 'victorquaint@gmail.com')
    
    unless seller
      puts "❌ Victor Quaint seller not found (victorquaint@gmail.com)"
      puts "💡 Available test emails:"
      Seller.limit(5).pluck(:email).each { |e| puts "   - #{e}" }
      exit
    end
    
    puts "✅ Found: #{seller.fullname} (#{seller.email})"
    
    filename = "valentines_test_#{Date.today.strftime('%Y%m%d')}.csv"
    filepath = Rails.root.join('tmp', filename)
    
    puts "📝 Generating test CSV: #{filepath}"
    
    CSV.open(filepath, "w") do |csv|
      csv << [
        'fullname', 'email', 'enterprise_name', 'phone_number', 'location',
        'ads_count', 'total_clicks', 'total_views', 'last_active_at', 'created_at',
        'days_since_last_ad', 'tier_name', 'avg_rating', 'total_reviews', 'username'
      ]
      
      # Get analytics
      ad_ids = seller.ads.where(deleted: false).pluck(:id)
      total_clicks = ad_ids.any? ? ClickEvent.excluding_internal_users.where(ad_id: ad_ids).count : 0
      
      # Estimate views (typically 3-4x clicks)
      total_views = if ad_ids.any? && defined?(Analytic)
        Analytic.where("data->>'ad_id' IN (?)", ad_ids.map(&:to_s))
                .where(type: ['AdView', 'PageView', 'page_view', 'ad_view'])
                .count
      else
        (total_clicks * 3.5).to_i
      end
      total_views = (total_clicks * 3).to_i if total_views == 0 && total_clicks > 0
      
      last_ad = seller.ads.where(deleted: false).order(created_at: :desc).first
      days_since_last = last_ad ? ((Time.current - last_ad.created_at) / 1.day).to_i : 999
      
      tier_name = seller.seller_tier&.tier&.name || 'Free'
      last_active = seller.last_active_at&.strftime('%B %d, %Y') || 'Recently'
      member_since = seller.created_at.strftime('%B %Y')
      avg_rating = seller.average_rating.round(1)
      total_reviews = seller.reviews.count
      username = seller.username.presence || seller.enterprise_name.parameterize
      
      csv << [
        seller.fullname,
        seller.email,
        seller.enterprise_name,
        seller.phone_number,
        seller.location || "#{seller.county&.name}, Kenya",
        seller.ads_count,
        total_clicks,
        total_views,
        last_active,
        member_since,
        days_since_last,
        tier_name,
        avg_rating,
        total_reviews,
        username
      ]
    end
    
    puts "\n✅ Test CSV generated!"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Display the data
    row = CSV.read(filepath, headers: true).first
    puts "\n📋 Test Data:"
    puts "  Name: #{row['fullname']}"
    puts "  Email: #{row['email']}"
    puts "  Shop: #{row['enterprise_name']}"
    puts "  Location: #{row['location']}"
    puts "  Ads: #{row['ads_count']}"
    puts "  Clicks: #{row['total_clicks']}"
    puts "  Views: #{row['total_views']}"
    puts "  Last Active: #{row['last_active_at']}"
    puts "  Member Since: #{row['created_at']}"
    puts "  Days Since Last Ad: #{row['days_since_last_ad']}"
    puts "  Tier: #{row['tier_name']}"
    puts "  Rating: #{row['avg_rating']}⭐ (#{row['total_reviews']} reviews)"
    puts "  Username: #{row['username']}"
    puts "\n  File: #{filepath}"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "\n✅ Use this to test Mailjet merge variables!"
  end
  
  desc "Show Valentine's campaign statistics"
  task stats: :environment do
    puts "\n📊 Valentine's Campaign - Seller Statistics"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Total active sellers
    active_sellers = Seller.active.where('ads_count > 0').count
    puts "\n👥 Active Sellers (with ads): #{active_sellers}"
    
    # By tier
    puts "\n🏆 Sellers by Tier:"
    SellerTier.joins(:tier, :seller)
             .where('sellers.deleted = ? AND sellers.blocked = ? AND sellers.ads_count > 0', false, false)
             .group('tiers.name')
             .count
             .each do |tier, count|
      puts "   #{tier}: #{count}"
    end
    
    # By activity
    puts "\n📅 By Last Activity:"
    active_last_7_days = Seller.active.where('last_active_at > ? AND ads_count > 0', 7.days.ago).count
    active_last_30_days = Seller.active.where('last_active_at > ? AND ads_count > 0', 30.days.ago).count
    inactive_30_plus = Seller.active.where('(last_active_at <= ? OR last_active_at IS NULL) AND ads_count > 0', 30.days.ago).count
    
    puts "   Active (last 7 days): #{active_last_7_days}"
    puts "   Active (last 30 days): #{active_last_30_days}"
    puts "   Inactive (30+ days): #{inactive_30_plus}"
    
    # By ads count
    puts "\n📦 By Ad Count:"
    high_volume = Seller.active.where('ads_count >= 10').count
    medium_volume = Seller.active.where('ads_count >= 5 AND ads_count < 10').count
    low_volume = Seller.active.where('ads_count > 0 AND ads_count < 5').count
    
    puts "   High volume (10+ ads): #{high_volume}"
    puts "   Medium volume (5-9 ads): #{medium_volume}"
    puts "   Low volume (1-4 ads): #{low_volume}"
    
    # Total potential reach
    puts "\n📧 Campaign Potential:"
    puts "   Total emails to send: #{active_sellers}"
    puts "   Expected opens (40%): #{(active_sellers * 0.4).to_i}"
    puts "   Expected clicks (10%): #{(active_sellers * 0.1).to_i}"
    puts "   Expected new ads (5%): #{(active_sellers * 0.05).to_i}"
    
    puts "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  end
  
  desc "Segment sellers for targeted campaigns"
  task segment: :environment do
    require 'csv'
    
    puts "\n🎯 Segmenting Sellers for Targeted Campaigns"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    base_query = Seller.active.where('ads_count > 0')
    
    # Segment 1: High Performers
    high_performers = base_query.where('ads_count >= 10')
    puts "\n1️⃣  High Performers (10+ ads): #{high_performers.count}"
    puts "   Message focus: Keep momentum, become top seller"
    
    # Segment 2: Need Activation (inactive)
    need_activation = base_query.where('last_active_at <= ? OR last_active_at IS NULL', 30.days.ago)
    puts "\n2️⃣  Need Activation (inactive 30+ days): #{need_activation.count}"
    puts "   Message focus: We miss you, comeback incentive"
    
    # Segment 3: Recent but low inventory
    recent_low = base_query.where('created_at >= ? AND ads_count < 5', 3.months.ago)
    puts "\n3️⃣  Recent but Low Inventory: #{recent_low.count}"
    puts "   Message focus: Upload more to gain traction"
    
    # Segment 4: Premium opportunity
    premium_eligible = base_query.joins(:seller_tier).where('tiers.name = ? AND sellers.ads_count >= 5', 'Free')
    puts "\n4️⃣  Premium Upgrade Opportunity: #{premium_eligible.count}"
    puts "   Message focus: Upgrade to Premium for Valentine's boost"
    
    puts "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "\n💡 Generate specific segment CSVs with:"
    puts "   rails valentines:generate_csv"
    puts "   Then filter by conditions in Excel/Google Sheets"
  end
end
