namespace :db do
  desc "Fix PostgreSQL sequence sync issues for buyers and sellers tables"
  task fix_sequences: :environment do
    puts "🔧 Fixing PostgreSQL sequence sync issues..."
    
    begin
      # Fix buyers sequence (purchasers_id_seq)
      puts "\n📊 Fixing buyers table sequence (purchasers_id_seq)..."
      max_buyer_id = ActiveRecord::Base.connection.execute(
        "SELECT COALESCE(MAX(id), 0) as max_id FROM buyers;"
      ).first['max_id'].to_i
      
      ActiveRecord::Base.connection.execute(
        "SELECT setval('purchasers_id_seq', #{max_buyer_id + 1}, false);"
      )
      
      current_seq_value = ActiveRecord::Base.connection.execute(
        "SELECT last_value FROM purchasers_id_seq;"
      ).first['last_value'].to_i
      
      puts "  ✅ Buyers sequence fixed: max_id=#{max_buyer_id}, sequence=#{current_seq_value}"
      
      # Fix sellers sequence (vendors_id_seq)
      puts "\n📊 Fixing sellers table sequence (vendors_id_seq)..."
      max_seller_id = ActiveRecord::Base.connection.execute(
        "SELECT COALESCE(MAX(id), 0) as max_id FROM sellers;"
      ).first['max_id'].to_i
      
      ActiveRecord::Base.connection.execute(
        "SELECT setval('vendors_id_seq', #{max_seller_id + 1}, false);"
      )
      
      current_seq_value = ActiveRecord::Base.connection.execute(
        "SELECT last_value FROM vendors_id_seq;"
      ).first['last_value'].to_i
      
      puts "  ✅ Sellers sequence fixed: max_id=#{max_seller_id}, sequence=#{current_seq_value}"
      
      # Fix seller_tiers sequence if it exists
      begin
        puts "\n📊 Fixing seller_tiers table sequence..."
        max_seller_tier_id = ActiveRecord::Base.connection.execute(
          "SELECT COALESCE(MAX(id), 0) as max_id FROM seller_tiers;"
        ).first['max_id'].to_i
        
        ActiveRecord::Base.connection.execute(
          "SELECT setval('seller_tiers_id_seq', #{max_seller_tier_id + 1}, false);"
        )
        
        current_seq_value = ActiveRecord::Base.connection.execute(
          "SELECT last_value FROM seller_tiers_id_seq;"
        ).first['last_value'].to_i
        
        puts "  ✅ Seller tiers sequence fixed: max_id=#{max_seller_tier_id}, sequence=#{current_seq_value}"
      rescue => e
        puts "  ⚠️  Seller tiers sequence fix skipped: #{e.message}"
      end
      
      puts "\n✅ All sequence fixes completed successfully!"
      
    rescue => e
      puts "\n❌ Error fixing sequences: #{e.message}"
      puts e.backtrace.join("\n")
      raise
    end
  end
end

