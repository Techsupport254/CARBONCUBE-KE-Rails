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
                      .includes(:seller)
                      .where.not(logo_url: [nil, ''])
                      .order(:name)

    render json: {
      partners: partners.filter_map { |partner| present(partner) }
    }
  end

  private

  def present(partner)
    seller = partner.seller
    return nil if seller.nil? || seller.deleted? || seller.blocked?

    {
      name: partner.name,
      logo_url: partner.logo_url,
      shop_path: "/shop/#{seller.url_slug}"
    }
  end
end
