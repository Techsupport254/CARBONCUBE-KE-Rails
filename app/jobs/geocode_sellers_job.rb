class GeocodeSellersJob < ApplicationJob
  queue_as :default

  NOMINATIM_API_URL = "https://nominatim.openstreetmap.org/search"
  RATE_LIMIT_DELAY = 1 # seconds between requests (OSM requires max 1 request per second)

  def perform(seller_id = nil)
    # Find sellers without coordinates in their branches
    sellers_without_coords = Seller
      .joins(:branches)
      .where(branches: { latitude: nil })
      .where.not(sellers: { location: nil })
    sellers_without_coords = sellers_without_coords.where(id: seller_id) if seller_id.present?
    sellers_without_coords = sellers_without_coords.distinct.limit(700) # Process all sellers in one batch (rate limited at 1 req/s)

    Rails.logger.info "Starting geocoding for #{sellers_without_coords.count} sellers"

    sellers_without_coords.each_with_index do |seller, index|
      begin
        # Geocode the seller's location
        coordinates = geocode_location(seller)

        if coordinates
          # Update the seller's branch with coordinates
          seller.branches.each do |branch|
            branch.update(
              latitude: coordinates[:lat],
              longitude: coordinates[:lon]
            )
          end
          
          Rails.logger.info "Successfully geocoded seller: #{seller.enterprise_name} (#{seller.location})"
        else
          Rails.logger.warn "Failed to geocode seller: #{seller.enterprise_name} (#{seller.location})"
        end
      rescue => e
        Rails.logger.error "Error geocoding seller #{seller.id}: #{e.message}"
      end
    end

    Rails.logger.info "Geocoding job completed"
  end

  private

  def geocode_location(seller, sync: false)
    loc = seller.location.to_s.strip.squeeze(' ')
    city = seller.city.to_s.strip
    sub_county = seller.sub_county&.name
    county = seller.county&.name

    queries = []

    if loc.present?
      parts = [loc]
      has_context = loc.downcase.include?(sub_county.to_s.downcase) || loc.downcase.include?(county.to_s.downcase)

      if !has_context && city.present? && !loc.downcase.include?(city.downcase)
        parts << city
      end

      if sub_county.present? && !loc.downcase.include?(sub_county.downcase)
        parts << sub_county
      end

      if county.present? && !loc.downcase.include?(county.downcase)
        parts << county
      end

      parts << 'Kenya' unless loc.split(',').last.to_s.strip.downcase == 'kenya'
      queries << parts.uniq.join(', ')
    end

    queries << "#{sub_county}, #{county}, Kenya" if sub_county.present? && county.present? && (city.blank? || city == county)
    queries << "#{city}, #{county}, Kenya" if city.present? && county.present? && city != county
    queries << "#{sub_county}, #{county}, Kenya" if sub_county.present? && county.present? && city.present? && city != county
    queries << "#{county}, Kenya" if county.present?
    queries << 'Kenya' if queries.empty?

    queries.uniq!

    queries.each do |query|
      sleep(sync ? 0 : RATE_LIMIT_DELAY)

      result = nominatim_search(query, county, sync)
      return result if result
    end

    nil
  end

  def nominatim_search(query, seller_county_name, sync = false)
    uri = URI(NOMINATIM_API_URL)
    params = {
      q: query,
      format: 'json',
      limit: 1,
      addressdetails: 1,
      countrycodes: 'ke'
    }
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = sync ? 5 : 10
    request = Net::HTTP::Get.new(uri.request_uri)
    request['User-Agent'] = 'CarbonCube-Kenya/1.0 (contact: info@carboncube-ke.com)'
    request['Accept'] = 'application/json'

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)

      if data.any?
        first = data.first
        address = first['address'] || {}
        matched_state = address['state'] || address['county']
        county_name = seller_county_name.to_s.downcase

        valid = if county_name.present? && matched_state.present?
                  matched_state.to_s.downcase.include?(county_name) || county_name.include?(matched_state.to_s.downcase)
                else
                  true
                end

        if valid
          return {
            lat: first['lat'].to_f,
            lon: first['lon'].to_f,
            display_name: first['display_name'],
            query: query
          }
        end
      end
    end

    nil
  end
end
