# frozen_string_literal: true

# Brand Kenya campaign mailer — asks onboarded brands to complete their
# professional dashboard. The missing-items checklist is computed per brand
# from the same fields the public directory enriches, so each email only
# asks for what that brand is actually missing.
class BrandKenyaMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  SITE = 'https://carboncube-ke.com'

  # Mirrors the directory's enrichment order: partner > seller > brand.
  # A Google OAuth avatar (lh3.googleusercontent.com) counts as missing —
  # it is an account photo, not a chosen business logo.
  def self.missing_items_for(brand)
    seller = brand.seller
    partner = brand.partner

    logo = partner&.logo_url.presence || seller&.profile_picture
    description = partner&.description.presence || seller&.description
    website = partner&.website.presence || brand.website.presence || seller&.website
    social = brand.twitter.presence || seller&.twitter_url

    items = []
    if logo.blank? || logo.include?('googleusercontent.com')
      items << { key: 'logo', label: 'Upload your official business logo' }
    end
    if description.blank? || description.strip.length < 40 || description.strip.casecmp?(seller&.enterprise_name.to_s.strip)
      items << { key: 'description',
                 label: 'Write a proper business description covering what you make and who you serve' }
    end
    items << { key: 'website', label: 'Add your website' } if website.blank?
    items << { key: 'social', label: 'Add your social media links' } if social.blank?
    items
  end

  def complete_profile(brand, to: nil)
    recipient = to.presence || brand.email.presence || brand.seller&.email
    return unless recipient.present?

    @brand = brand
    mail(
      to: recipient,
      bcc: ENV['BREVO_EMAIL'],
      subject: "#{brand.name} is in Brand Kenya. Complete your profile",
      react: react_props
    )
  end

  # First-touch cold email to a directory brand that has not onboarded.
  # Unregistered brands get a claim-your-listing pitch pointing at seller
  # signup; brands with a seller account get a finish-your-profile nudge
  # pointing at the dashboard.
  def cold_outreach(brand, to: nil)
    recipient = to.presence || brand.email.presence || brand.seller&.email
    return unless recipient.present?

    @brand = brand
    subject =
      if brand.seller_id.present?
        "#{brand.name} — your Brand Kenya listing needs a few details"
      else
        "#{brand.name} is listed in Brand Kenya"
      end
    mail(
      to: recipient,
      bcc: ENV['BREVO_EMAIL'],
      subject: subject,
      react: cold_outreach_props
    )
  end

  private

  def react_props
    seller = @brand.seller
    {
      brand_name: @brand.name,
      contact_name: contact_name,
      category: @brand.category,
      missing_items: self.class.missing_items_for(@brand),
      profile_url: "#{SITE}/seller/profile?utm_source=brand_kenya&utm_medium=email&utm_campaign=brand_kenya",
      shop_url: seller&.slug ? "#{SITE}/shop/#{seller.slug}" : nil,
      listing_url: "#{SITE}/brand-kenya"
    }
  end

  def cold_outreach_props
    seller = @brand.seller
    registered = seller.present?
    {
      brand_name: @brand.name,
      contact_name: contact_name,
      category: @brand.category,
      registered: registered,
      missing_items: self.class.missing_items_for(@brand),
      cta_url: registered ? profile_url : signup_url,
      shop_url: seller&.slug ? "#{SITE}/shop/#{seller.slug}" : nil,
      listing_url: "#{SITE}/brand-kenya"
    }
  end

  def profile_url
    "#{SITE}/seller/profile?utm_source=brand_kenya&utm_medium=email&utm_campaign=brand_kenya_cold"
  end

  def signup_url
    "#{SITE}/seller-signup?utm_source=brand_kenya&utm_medium=email&utm_campaign=brand_kenya_cold"
  end

  def contact_name
    seller = @brand.seller
    seller&.fullname.presence || seller&.enterprise_name.presence || @brand.name
  end
end
