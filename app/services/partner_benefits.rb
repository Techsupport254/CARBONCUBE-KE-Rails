# frozen_string_literal: true

# Per-partner-type benefit lists for invite emails and WhatsApp messages.
# The list varies by who is being invited:
#   - Partner invitees get benefits for their partner_type
#   - PartnerDistributor invitees get "what the network gets you" benefits
#   - PartnerContact invitees get a "stay connected" list
#
# Email templates render the markdown variant (<Markdown> component is
# already used across our emails); WhatsApp copy uses plain bullet lines.
module PartnerBenefits
  LISTS = {
    brand_manufacturer: [
      'Verified Partner badge — on your storefront and every product you list',
      'A free storefront — upload and manage your full product catalog',
      'Catalog management — stock tracking, restock tools and printable catalogs',
      'A QR code for your catalog — buyers scan to open your storefront',
      'Reach thousands of buyers — across Kenya',
      'Distributor network — they receive your pricing and updates instantly',
      'Priority support — a dedicated account manager when you need help'
    ].freeze,
    distributor: [
      'Verified Partner badge on your storefront and listings',
      'Upload and manage your catalog — sell to buyers nationwide',
      'List your own reseller network for pricing and stock updates',
      'Priority support and a dedicated account manager'
    ].freeze,
    wholesaler: [
      'Verified Partner badge on your storefront and listings',
      'Bulk pricing tools — reach resellers and retailers directly',
      'List your buyer network for pricing and restock alerts',
      'Priority support and a dedicated account manager'
    ].freeze,
    retailer: [
      'Verified Partner badge on your storefront and listings',
      'Upload products and reach buyers beyond your location',
      'Business updates, promotions, and pricing alerts',
      'Priority support from the Carbon team'
    ].freeze,
    financier: [
      'A direct partnership channel with Carbon Cube Kenya',
      'Reach pre-qualified sellers and buyers for your financing products',
      'Co-branded campaigns and promotions',
      'A dedicated account manager and regular business updates'
    ].freeze,
    logistics: [
      'Get matched to delivery and fulfilment work from our sellers',
      'Preferred logistics-partner listing in our partner network',
      'Business updates and volume forecasts',
      'A dedicated account manager'
    ].freeze,
    service: [
      'Official service-partner listing in our partner network',
      'Referrals from our seller and buyer base',
      'Co-marketing opportunities',
      'A dedicated account manager'
    ].freeze,
    other: [
      'Official Carbon Cube Kenya partner status',
      'Partnership updates and announcements',
      'A dedicated account manager'
    ].freeze,
    # Invitees who are not the partner themselves
    network_distributor: [
      'Partner pricing on their products',
      'Instant alerts when prices drop',
      'Product announcements, promotions, and restock notices',
      'A direct line to the brand through Carbon Cube'
    ].freeze,
    contact: [
      'Partnership updates and announcements',
      'Campaign and performance highlights',
      'A direct line to the Carbon Cube team'
    ].freeze
  }.freeze

  module_function

  # Ordered benefit strings for whoever the invite is addressed to.
  def for_invitee(invitee)
    case invitee
    when PartnerDistributor then LISTS[:network_distributor]
    when PartnerContact     then LISTS[:contact]
    when Partner            then LISTS.fetch(invitee.partner_type.to_sym, LISTS[:other])
    else LISTS[:other]
    end
  end

  # "What you get…" heading for the email benefits card.
  def heading(invitee)
    case invitee
    when PartnerDistributor
      "What you get in #{invitee.partner&.name || 'their'}'s network"
    when PartnerContact
      "What you'll hear from us"
    else
      'What you get as a partner'
    end
  end

  # Markdown bullet list — rendered by the <Markdown> email component.
  def markdown(invitee)
    for_invitee(invitee).map { |b| "- #{b}" }.join("\n")
  end

  # Plain bullets for WhatsApp — capped so the message stays scannable.
  def whatsapp_lines(invitee, limit: 4)
    for_invitee(invitee).first(limit).map { |b| "• #{b}" }.join("\n")
  end
end
