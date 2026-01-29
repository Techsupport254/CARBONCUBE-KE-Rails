# frozen_string_literal: true

class GiveAllSellersPremiumUntilJuneEnd < ActiveRecord::Migration[7.1]
  def up
    premium_tier = Tier.find_by(name: 'Premium')

    if premium_tier.nil?
      puts "❌ Premium tier not found. Skipping migration."
      return
    end

    puts "✅ Found premium tier: #{premium_tier.name} (ID: #{premium_tier.id})"

    # Expires at end of June 30 (last date of June)
    expires_at = Time.new(2026, 6, 30, 23, 59, 59)

    current_date = Time.current
    remaining_days = ((expires_at - current_date) / 1.day).ceil
    duration_months = [1, (remaining_days / 30.44).ceil].max

    puts "📅 Setting premium tier expiry to: #{expires_at} (June 30, 2026 end of day, ~#{duration_months} months)"

    # Sellers with no tier or Free tier
    sellers_to_update = Seller.left_joins(:seller_tier)
                              .where('seller_tiers.id IS NULL OR seller_tiers.tier_id = 1')
                              .where(deleted: false)
                              .distinct

    seller_count = sellers_to_update.count
    puts "👥 Found #{seller_count} sellers to give premium until June 30, 2026"

    sellers_to_update.find_each do |seller|
      seller.reload
      if seller.seller_tier.present? && seller.seller_tier.tier_id == 1
        seller.seller_tier.destroy
        puts "🗑️ Removed free tier from seller: #{seller.email}"
      end

      SellerTier.create!(
        seller: seller,
        tier: premium_tier,
        duration_months: duration_months,
        expires_at: expires_at
      )
      puts "✅ Assigned premium (until June 30, 2026) to seller: #{seller.email}"
    end

    puts "🎉 Migration completed! #{seller_count} sellers now have premium until June 30, 2026."
  end

  def down
    premium_tier = Tier.find_by(name: 'Premium')

    if premium_tier.nil?
      puts "❌ Premium tier not found. Skipping rollback."
      return
    end

    expires_at = Time.new(2026, 6, 30, 23, 59, 59)

    seller_tiers_to_remove = SellerTier.where(
      tier: premium_tier,
      expires_at: expires_at
    )

    puts "🗑️ Removing #{seller_tiers_to_remove.count} premium seller tiers (June 30, 2026 expiry)"

    seller_tiers_to_remove.destroy_all

    # Assign Free tier back to sellers who have no tier
    sellers_without_tier = Seller.left_joins(:seller_tier)
                                 .where(seller_tiers: { id: nil })
                                 .where(deleted: false)

    free_tier = Tier.find_by(name: 'Free') || Tier.find_by(id: 1) || Tier.first

    if free_tier
      sellers_without_tier.find_each do |seller|
        SellerTier.create!(
          seller: seller,
          tier: free_tier,
          duration_months: 0
        )
        puts "✅ Assigned free tier to seller: #{seller.email}"
      end
    end

    puts "🎉 Rollback completed!"
  end
end
