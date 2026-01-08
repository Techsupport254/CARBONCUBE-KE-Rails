class GiveAllSellers2026PremiumTier < ActiveRecord::Migration[7.1]
  def up
    # Find the premium tier
    premium_tier = Tier.find_by(name: 'Premium')

    if premium_tier.nil?
      puts "❌ Premium tier not found. Skipping migration."
      return
    end

    puts "✅ Found premium tier: #{premium_tier.name} (ID: #{premium_tier.id})"

    # Calculate expiry date (end of 2026) - expires at midnight on January 1, 2027
    expires_at = Time.new(2027, 1, 1, 0, 0, 0)

    # Calculate duration months from now until end of 2026
    current_date = Time.current
    end_of_2026 = Time.new(2026, 12, 31, 23, 59, 59)
    remaining_days = ((end_of_2026 - current_date) / 1.day).ceil
    duration_months = (remaining_days / 30.44).ceil # Average days per month

    puts "📅 Setting premium tier expiry to: #{expires_at} (#{remaining_days} days, ~#{duration_months} months)"

    # Get all sellers who either don't have a seller_tier or have a free tier (tier_id = 1)
    sellers_to_update = Seller.left_joins(:seller_tier)
                               .where('seller_tiers.id IS NULL OR seller_tiers.tier_id = 1')
                               .where(deleted: false)

    seller_count = sellers_to_update.count
    puts "👥 Found #{seller_count} sellers to give premium tier"

    sellers_to_update.each do |seller|
      # Remove existing free tier if present
      if seller.seller_tier.present? && seller.seller_tier.tier_id == 1
        seller.seller_tier.destroy
        puts "🗑️ Removed free tier from seller: #{seller.email}"
      end

      # Create premium tier
      seller_tier = SellerTier.create!(
        seller: seller,
        tier: premium_tier,
        duration_months: duration_months,
        expires_at: expires_at
      )

      puts "✅ Assigned premium tier to seller: #{seller.email} (SellerTier ID: #{seller_tier.id})"
    end

    puts "🎉 Migration completed! #{seller_count} sellers now have premium tier for 2026."
  end

  def down
    # Find the premium tier
    premium_tier = Tier.find_by(name: 'Premium')

    if premium_tier.nil?
      puts "❌ Premium tier not found. Skipping rollback."
      return
    end

    # Remove all seller_tiers with premium tier that expire on Jan 1, 2027 (our migration date)
    expires_at_2027 = Time.new(2027, 1, 1, 0, 0, 0)

    seller_tiers_to_remove = SellerTier.where(
      tier: premium_tier,
      expires_at: expires_at_2027
    )

    puts "🗑️ Removing #{seller_tiers_to_remove.count} premium seller tiers created by this migration"

    seller_tiers_removed = seller_tiers_to_remove.destroy_all

    puts "✅ Removed #{seller_tiers_removed.count} premium seller tiers"

    # For sellers who no longer have a tier, assign them back to free tier
    sellers_without_tier = Seller.left_joins(:seller_tier)
                                 .where(seller_tiers: { id: nil })
                                 .where(deleted: false)

    free_tier = Tier.find_by(name: 'Free') || Tier.first

    if free_tier
      puts "🔄 Assigning free tier back to #{sellers_without_tier.count} sellers"

      sellers_without_tier.each do |seller|
        SellerTier.create!(
          seller: seller,
          tier: free_tier,
          duration_months: 0 # Free tier never expires
        )
        puts "✅ Assigned free tier to seller: #{seller.email}"
      end
    end

    puts "🎉 Rollback completed!"
  end
end
