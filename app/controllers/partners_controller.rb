# frozen_string_literal: true

# Public partner directory — powers the "Our Partners" strip in the site
# footer. Only active partners who actually sell on the platform and have a
# logo + live storefront are listed (a logo strip needs logos; the link needs
# a shop to point at).
class PartnersController < ApplicationController
  # GET /partners
  def index
    partners = Partner.where(status: 'active')
                      .selling
                      .left_joins(:seller)
                      .includes(:seller)
                      .where("partners.logo_url IS NOT NULL AND partners.logo_url != '' OR sellers.profile_picture IS NOT NULL AND sellers.profile_picture != ''")
                      .order(:name)

    render json: {
      partners: partners.filter_map { |partner| present(partner) }
    }
  end

  private

  def present(partner)
    seller = partner.seller
    return nil if seller.nil? || seller.deleted? || seller.blocked?

    logo = partner.logo_url.presence || seller.profile_picture.presence
    return nil if logo.blank?

    {
      name: partner.name,
      logo_url: logo,
      shop_path: "/shop/#{seller.url_slug}"
    }
  end
end

