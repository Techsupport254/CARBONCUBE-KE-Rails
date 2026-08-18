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

  def sanitize_location(loc)
    return "" if loc.blank?

    cleaned = loc.to_s.dup
    # Remove PO Box details
    cleaned.gsub!(/P\.?\s*O\.?\s*BOX\s*\d+[a-z]?/i, '')
    # Remove phone number patterns (e.g. 0712345678, +254...)
    cleaned.gsub!(/(?:\+?254|0)\s*\d{3}\s*\d{3}\s*\d{3}/, '')
    cleaned.gsub!(/tel:\s*[\d\s\-]+/i, '')
    # Remove extra punctuation and space
    cleaned.tr!(';', ',')
    cleaned.squeeze!(' ')
    cleaned.strip!
    cleaned.sub(/\A,+,?\s*/, '').sub(/\s*,+,\z/, '').strip
  end

  def geocode_location(seller, sync: false)
    raw_loc = seller.location.to_s.strip
    loc = sanitize_location(raw_loc)
    city = seller.city.to_s.strip
    sub_county = seller.sub_county&.name.to_s.strip
    county = seller.county&.name.to_s.strip

    queries = []

    if loc.present?
      # Candidate 1: full location + city + sub_county + county
      c1 = [loc]
      c1 << city if city.present? && !loc.downcase.include?(city.downcase)
      c1 << sub_county if sub_county.present? && !loc.downcase.include?(sub_county.downcase)
      c1 << county if county.present? && !loc.downcase.include?(county.downcase)
      c1 << 'Kenya'
      queries << c1.uniq.join(', ')

      # Candidate 2: location + sub_county + county
      c2 = [loc]
      c2 << sub_county if sub_county.present? && !loc.downcase.include?(sub_county.downcase)
      c2 << county if county.present? && !loc.downcase.include?(county.downcase)
      c2 << 'Kenya'
      queries << c2.uniq.join(', ')

      # Candidate 3: location + city + county
      c3 = [loc]
      c3 << city if city.present? && !loc.downcase.include?(city.downcase)
      c3 << county if county.present? && !loc.downcase.include?(county.downcase)
      c3 << 'Kenya'
      queries << c3.uniq.join(', ')

      # Candidate 4: location + county
      c4 = [loc]
      c4 << county if county.present? && !loc.downcase.include?(county.downcase)
      c4 << 'Kenya'
      queries << c4.uniq.join(', ')
    end

    # Fallback regional queries
    queries << "#{sub_county}, #{city}, #{county}, Kenya" if sub_county.present? && city.present? && county.present?
    queries << "#{sub_county}, #{county}, Kenya" if sub_county.present? && county.present?
    queries << "#{city}, #{county}, Kenya" if city.present? && county.present? && city.downcase != county.downcase
    queries << "#{county}, Kenya" if county.present?
    queries << 'Kenya' if queries.empty?

    queries.map!(&:strip).uniq!

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
      limit: 5,
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
        county_name = seller_county_name.to_s.downcase.strip

        # Match against county/state/region or fallback to first result if seller county is unspecified
        result = data.find do |r|
          address = r['address'] || {}
          fields = [
            address['state'], address['county'], address['region'],
            address['state_district'], address['city'], address['town']
          ].compact.map(&:to_s).map(&:downcase)

          county_name.blank? || fields.any? { |f| f.include?(county_name) || county_name.include?(f) }
        end

        result ||= data.first if county_name.blank?

        if result
          return {
            lat: result['lat'].to_f,
            lon: result['lon'].to_f,
            display_name: result['display_name'],
            query: query
          }
        end
      end
    end

    nil
  rescue => e
    Rails.logger.warn "Nominatim search error for query '#{query}': #{e.message}"
    nil
  end
end

