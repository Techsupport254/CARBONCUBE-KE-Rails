class UpgradeAllSellersToPremium < ActiveRecord::Migration[7.1]
  def up
    premium_tier = Tier.find_by(name: 'Premium')
    unless premium_tier
      puts "❌ Premium tier not found. Skipping data update."
      return
    end

    total_sellers = Seller.count
    processed = 0
    created = 0
    updated = 0

    puts "🚀 Upgrading #{total_sellers} sellers to Premium..."

    Seller.find_each do |seller|
      seller_tier = SellerTier.find_or_initialize_by(seller_id: seller.id)
      
      # If it's already premium, we might still want to refresh the expiry
      # but the user said "upgrade all", implying they all should be premium.
      
      seller_tier.tier_id = premium_tier.id
      seller_tier.expires_at = Time.zone.local(2026, 12, 31, 23, 59, 59)
      seller_tier.duration_months = 12 unless seller_tier.duration_months.present?
      
      if seller_tier.new_record?
        created += 1
      else
        updated += 1
      end

      seller_tier.save!
      processed += 1
      
      if processed % 50 == 0
        puts "  ⏳ Processed #{processed}/#{total_sellers} sellers..."
      end
    end

    puts "✅ Done! Created #{created} and updated #{updated} seller tiers to Premium."
  end

  def down
    # This is a bit destructive to undo, so we'll leave it as a no-op or 
    # we could potentially revert to 'Free' if we really wanted to.
    # But usually, data migrations like this are one-way.
    raise ActiveRecord::IrreversibleMigration
  end
end
