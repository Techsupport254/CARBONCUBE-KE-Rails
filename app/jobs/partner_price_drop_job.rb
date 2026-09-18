# frozen_string_literal: true

# Turns a partner ad's price decrease into a `pricing` PartnerUpdate, which
# PartnerUpdateFanoutJob then pushes to subscribed distributors.
#
# Guards against noise: skips if the price has since changed again, and
# de-dupes against the most recent pricing update for the same ad.
# Prices arrive as strings so they compare exactly as decimals.
class PartnerPriceDropJob < ApplicationJob
  queue_as :low

  def perform(ad_id, old_price, new_price)
    ad = Ad.find_by(id: ad_id)
    return unless ad
    return if ad.deleted? || ad.flagged?

    partner = ad.seller&.partner
    return unless partner&.active?

    new_decimal = BigDecimal(new_price.to_s)
    old_decimal = BigDecimal(old_price.to_s)
    return unless ad.price == new_decimal

    latest = partner.updates.where(kind: 'pricing', ad_id: ad.id).first
    return if latest && BigDecimal(latest.metadata['new_price'].to_s) == new_decimal

    drop_pct = old_decimal.positive? ? (((old_decimal - new_decimal) / old_decimal) * 100).round : nil
    title = "Price drop: #{ad.title}"
    body = "#{ad.title} is now #{format_price(new_decimal)} (was #{format_price(old_decimal)})"
    body += " — #{drop_pct}% off" if drop_pct&.positive?

    partner.updates.create!(
      kind: 'pricing',
      title: title,
      body: body,
      ad: ad,
      metadata: {
        'ad_id' => ad.id,
        'old_price' => old_decimal.to_s,
        'new_price' => new_decimal.to_s,
        'drop_pct' => drop_pct
      }
    )
  end

  private

  def format_price(amount)
    "KSh #{format('%.2f', amount)}"
  end
end
