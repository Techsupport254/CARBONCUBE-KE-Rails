# app/controllers/feeds_controller.rb
class FeedsController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  # GET /feeds/google_merchant.xml
  # GET /api/v1/feeds/google_merchant.xml
  def google_merchant
    # Check cache first (cache for 1 hour, bypass if refresh=true)
    force_refresh = params[:refresh].present? && ['true', '1'].include?(params[:refresh])
    cached_xml = Rails.cache.read('google_merchant_xml_feed') unless force_refresh

    if cached_xml.present?
      render xml: cached_xml, content_type: 'application/xml; charset=utf-8'
      return
    end

    xml = generate_google_merchant_xml
    Rails.cache.write('google_merchant_xml_feed', xml, expires_in: 1.hour)

    render xml: xml, content_type: 'application/xml; charset=utf-8'
  rescue => e
    Rails.logger.error "Error generating Google Merchant XML feed: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    render xml: "<error>#{CGI.escapeHTML(e.message)}</error>", status: :internal_server_error, content_type: 'application/xml'
  end

  private

  def generate_google_merchant_xml
    base_site_url = 'https://carboncube-ke.com'

    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.rss(version: '2.0', 'xmlns:g' => 'http://base.google.com/ns/1.0') do
        xml.channel do
          xml.title 'Carbon Cube Kenya Products'
          xml.link base_site_url
          xml.description 'Quality Products from Verified Sellers on Carbon Cube Kenya Marketplace'

          Ad.active
            .where.not(media: [nil, [], ''])
            .includes(:category, :subcategory, seller: { seller_tier: :tier })
            .find_each(batch_size: 500) do |ad|
            next unless ad.valid_for_google_merchant?

            xml.item do
              xml['g'].id "carbon_cube_#{ad.id}"
              xml['g'].title GoogleMerchantTextSanitizer.clean_title(ad.title)
              xml['g'].description GoogleMerchantTextSanitizer.clean_description(ad.description).truncate(5000)
              xml['g'].link ad.product_url
              xml['g'].image_link ad.first_valid_media_url

              # Secondary images (up to 10 allowed by Google)
              additional_images = ad.valid_media_urls[1..10] || []
              additional_images.each do |img|
                xml['g'].additional_image_link img if img.present?
              end

              xml['g'].condition ad.google_condition.downcase
              xml['g'].availability ad.in_stock? ? 'in_stock' : 'out_of_stock'
              xml['g'].price "#{format('%.2f', ad.effective_price)} KES"

              cleaned_brand = ad.brand.to_s.strip
              if cleaned_brand.present? && !%w[Unknown Generic None N/A Other].include?(cleaned_brand)
                xml['g'].brand cleaned_brand
              end

              # Marketplace products without GTINs must explicitly declare identifier_exists = no
              xml['g'].identifier_exists 'no'

              if ad.category.present?
                category_path = [ad.category.name, ad.subcategory&.name].compact.join(' > ')
                xml['g'].product_type category_path
              end
            end
          end
        end
      end
    end

    builder.to_xml
  end
end
