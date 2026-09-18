# frozen_string_literal: true

require 'net/http'

# Public Brand Kenya directory — onboarded homegrown brands only.
# Logo/description come from the linked Partner record when one exists;
# the seller link exposes the brand's storefront slug.
# Logos are served through /brand_kenya/:id/logo which proxies the remote
# image (e.g. Google profile photos break when hotlinked) and caches the
# bytes in Redis so upstream hosts are not hit on every page load.
class BrandKenyaController < ApplicationController
  LOGO_CACHE_TTL = 7.days
  LOGO_FAILURE_TTL = 5.minutes
  MAX_LOGO_REDIRECTS = 3

  def index
    brands = SalesBrand.where(status: :onboarded)
                       .includes(:partner, :seller)
                       .order(:name)

    render json: {
      brands: brands.map { |b| serialize_brand(b) },
      count: brands.size
    }
  end

  def logo
    brand = SalesBrand.where(status: :onboarded).find_by(id: params[:id])
    remote = brand && remote_logo_url(brand)
    return head :not_found if remote.blank?

    cached = Rails.cache.read(logo_cache_key(brand, remote))
    unless cached
      cached = fetch_remote_logo(remote)
      Rails.cache.write(logo_cache_key(brand, remote), cached,
                        expires_in: cached[:ok] ? LOGO_CACHE_TTL : LOGO_FAILURE_TTL)
    end

    return head :not_found unless cached[:ok]

    expires_in LOGO_CACHE_TTL, public: true
    send_data cached[:body], type: cached[:type], disposition: 'inline'
  end

  private

  def serialize_brand(brand)
    partner = brand.partner
    seller = brand.seller
    remote = remote_logo_url(brand)
    {
      id: brand.id,
      name: brand.name,
      category: brand.category,
      subcategories: brand.subcategories,
      scope: brand.scope,
      location: brand.location.presence || seller&.location,
      website: partner&.website.presence || brand.website.presence || seller&.website,
      phone: brand.phone.presence || seller&.phone_number,
      email: brand.email.presence || seller&.email,
      twitter: brand.twitter.presence || seller&.twitter_url,
      logo_url: remote.present? ? brand_kenya_logo_url(brand.id) : nil,
      description: partner&.description.presence || seller&.description,
      shop_slug: seller&.slug
    }
  end

  def remote_logo_url(brand)
    brand.partner&.logo_url.presence ||
      brand.seller&.profile_picture.presence ||
      discovered_logo_url(brand)
  end

  # Brands without a stored logo but with a website get their site's
  # hi-res logo/favicon scraped (JSON-LD logo > apple-touch-icon >
  # largest rel=icon > /favicon.ico). The discovered URL is cached so
  # we don't re-scrape the site on every directory request.
  def discovered_logo_url(brand)
    site = brand.partner&.website.presence || brand.website.presence || brand.seller&.website
    return if site.blank?

    site = "https://#{site}" unless site.match?(%r{\Ahttps?://}i)
    key = "brand_kenya:favicon:#{Digest::MD5.hexdigest(site)}"
    cached = Rails.cache.read(key)
    unless cached
      cached = discover_site_logo(site).presence || 'none'
      Rails.cache.write(key, cached,
                        expires_in: cached == 'none' ? LOGO_FAILURE_TTL : LOGO_CACHE_TTL)
    end
    cached == 'none' ? nil : cached
  end

  def discover_site_logo(site)
    body, base_uri = http_get(site, limit: 512.kilobytes)
    return if body.blank?

    doc = Nokogiri::HTML(body)
    candidates = []

    json_logo = jsonld_logo(doc, base_uri)
    candidates << [2000, json_logo] if json_logo

    doc.css('link[rel][href]').each do |link|
      rel = link['rel'].to_s.downcase
      url = absolutize(link['href'], base_uri)
      next unless url

      score =
        if rel.include?('apple-touch-icon') then 1000 + icon_size(link['sizes'])
        elsif rel.include?('mask-icon') then 800
        elsif rel.split(/\s+/).include?('icon') then icon_size(link['sizes'])
        else 0
        end
      candidates << [score, url] if score.positive?
    end

    candidates.sort_by { |score, _| -score }.each do |_, url|
      return url if remote_image_ok?(url)
    end

    favicon = absolutize('/favicon.ico', base_uri)
    favicon if favicon && remote_image_ok?(favicon)
  end

  def jsonld_logo(doc, base_uri)
    doc.css('script[type="application/ld+json"]').each do |node|
      url = dig_logo_url(JSON.parse(node.text))
      resolved = url && absolutize(url, base_uri)
      return resolved if resolved
    rescue JSON::ParserError
      next
    end
    nil
  end

  def dig_logo_url(obj, depth = 0)
    return if depth > 5

    case obj
    when Hash
      logo = obj['logo']
      url = logo.is_a?(Hash) ? (logo['url'] || logo['contentUrl']) : logo
      return url if url.is_a?(String) && url.present?

      obj.each_value do |v|
        found = dig_logo_url(v, depth + 1)
        return found if found
      end
    when Array
      obj.each do |v|
        found = dig_logo_url(v, depth + 1)
        return found if found
      end
    end
    nil
  end

  def icon_size(sizes)
    return 256 if sizes.to_s.downcase.split(/\s+/).include?('any')

    sizes.to_s.scan(/(\d+)x\d+/i).flatten.map(&:to_i).max || 16
  end

  def absolutize(href, base)
    value = href.to_s.strip
    return if value.blank? || value.match?(/\A(?:data|javascript|mailto):/i)

    URI.join(base.to_s, value).to_s
  rescue StandardError
    nil
  end

  def remote_image_ok?(url)
    _body, _uri, type = http_get(url)
    type.to_s.start_with?('image/')
  end

  def logo_cache_key(brand, remote)
    "brand_kenya:logo:#{brand.id}:#{Digest::MD5.hexdigest(remote)}"
  end

  def fetch_remote_logo(url)
    body, _uri, type = http_get(url)
    if body.present? && type.to_s.start_with?('image/')
      { ok: true, body: body, type: type }
    else
      { ok: false }
    end
  end

  def http_get(url, limit: nil)
    uri = URI.parse(url)
    MAX_LOGO_REDIRECTS.times do
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                 open_timeout: 3, read_timeout: 5) do |http|
        http.get(uri.request_uri.presence || '/')
      end

      if response.is_a?(Net::HTTPRedirection) && response['location'].present?
        uri = URI.join(uri.to_s, response['location'])
        next
      end

      return unless response.is_a?(Net::HTTPSuccess)

      body = response.body
      body = body.byteslice(0, limit) if limit && body
      return [body, uri, response.content_type.to_s]
    end
    nil
  rescue StandardError
    nil
  end
end
