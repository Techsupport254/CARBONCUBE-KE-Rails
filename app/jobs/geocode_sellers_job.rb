class GeocodeSellersJob < ApplicationJob
  queue_as :default

  NOMINATIM_API_URL = "https://nominatim.openstreetmap.org/search"
  RATE_LIMIT_DELAY = 1 # seconds between requests (OSM requires max 1 request per second)

  def perform(seller_id = nil, force: false)
    sellers_to_process = Seller
      .joins(:branches)
      .where.not(sellers: { location: nil })

    unless force
      sellers_to_process = sellers_to_process.where(
        "branches.latitude IS NULL OR branches.location_precision IN ('sub_county', 'county', 'approximate') OR branches.location_precision IS NULL"
      )
    end

    sellers_to_process = sellers_to_process.where(id: seller_id) if seller_id.present?
    sellers_to_process = sellers_to_process.distinct.limit(1000)

    Rails.logger.info "Starting geocoding for #{sellers_to_process.count} sellers (force: #{force})"

    sellers_to_process.each_with_index do |seller, index|
      begin
        # Geocode the seller's location
        coordinates = geocode_location(seller)

        if coordinates
          # Update the seller's branch with coordinates and precision level
          seller.branches.each do |branch|
            branch.update(
              latitude: coordinates[:lat],
              longitude: coordinates[:lon],
              location_precision: coordinates[:precision] || 'approximate'
            )
          end
          
          Rails.logger.info "Successfully geocoded seller: #{seller.enterprise_name} (#{seller.location}) [precision: #{coordinates[:precision]}]"
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
      queries << { query: c1.uniq.join(', '), type: :specific }

      # Candidate 2: location + sub_county + county
      c2 = [loc]
      c2 << sub_county if sub_county.present? && !loc.downcase.include?(sub_county.downcase)
      c2 << county if county.present? && !loc.downcase.include?(county.downcase)
      c2 << 'Kenya'
      queries << { query: c2.uniq.join(', '), type: :specific }

      # Candidate 3: location + city + county
      c3 = [loc]
      c3 << city if city.present? && !loc.downcase.include?(city.downcase)
      c3 << county if county.present? && !loc.downcase.include?(county.downcase)
      c3 << 'Kenya'
      queries << { query: c3.uniq.join(', '), type: :specific }

      # Candidate 4: location + county
      c4 = [loc]
      c4 << county if county.present? && !loc.downcase.include?(county.downcase)
      c4 << 'Kenya'
      queries << { query: c4.uniq.join(', '), type: :specific }

      # Candidate 5: first specific segment (e.g. road/building) + correct sub_county/county
      first_segment = loc.split(',').first.to_s.strip
      if first_segment.present? && first_segment.length < loc.length
        c5 = [first_segment]
        c5 << sub_county if sub_county.present? && !first_segment.downcase.include?(sub_county.downcase)
        c5 << county if county.present? && !first_segment.downcase.include?(county.downcase)
        c5 << 'Kenya'
        queries << { query: c5.uniq.join(', '), type: :specific }
      end
    end

    # Fallback regional queries
    queries << { query: "#{sub_county}, #{city}, #{county}, Kenya", type: :sub_county } if sub_county.present? && city.present? && county.present?
    queries << { query: "#{sub_county}, #{county}, Kenya", type: :sub_county } if sub_county.present? && county.present?
    queries << { query: "#{city}, #{county}, Kenya", type: :sub_county } if city.present? && county.present? && city.downcase != county.downcase
    queries << { query: "#{county}, Kenya", type: :county } if county.present?
    queries << { query: 'Kenya', type: :county } if queries.empty?

    # Deduplicate queries keeping highest specificity
    unique_queries = []
    seen = Set.new
    queries.each do |q_item|
      str = q_item[:query].strip
      next if seen.include?(str)

      seen.add(str)
      unique_queries << q_item
    end

    unique_queries.each do |q_item|
      sleep(sync ? 0 : RATE_LIMIT_DELAY)

      result = nominatim_search(q_item[:query], q_item[:type], county, sync)
      return result if result
    end

    # Last resort: use the Kenya Gazetteer for coarse local points, but do not
    # treat its hardcoded points as high-precision "exact" coordinates.
    gazetteer_match = KenyaGazetteerService.resolve(loc, seller)
    if gazetteer_match
      gazetteer_precision = case gazetteer_match[:precision]
                            when 'exact'
                              'estate'
                            when 'street'
                              'street'
                            when 'estate'
                              'estate'
                            else
                              gazetteer_match[:precision]
                            end
      return {
        lat: gazetteer_match[:lat],
        lon: gazetteer_match[:lon],
        precision: gazetteer_precision
      }
    end

    nil
  end

  def nominatim_search(query, query_type, seller_county_name, sync = false)
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
        filtered = data.select do |r|
          address = r['address'] || {}
          fields = [
            address['state'], address['county'], address['region'],
            address['state_district'], address['city'], address['town']
          ].compact.map(&:to_s).map(&:downcase)

          county_name.blank? || fields.any? { |f| f.include?(county_name) || county_name.include?(f) }
        end

        filtered = data if filtered.empty?

        # For specific address queries, prefer the most detailed (highest place_rank) result
        result = if query_type == :specific && filtered.size > 1
          filtered.max_by { |r| r['place_rank'].to_i }
        else
          filtered.first
        end

        if result
          osm_type = result['type'].to_s.downcase
          osm_class = result['class'].to_s.downcase
          coarse_types = %w[administrative suburb district county state region boundary administrative_boundary]

          is_coarse = coarse_types.include?(osm_type) || coarse_types.include?(osm_class)

          precision = if query_type == :specific && !is_coarse
                        'exact'
                      elsif query_type == :sub_county || (query_type == :specific && is_coarse)
                        'sub_county'
                      elsif query_type == :county
                        'county'
                      else
                        'approximate'
                      end

          return {
            lat: result['lat'].to_f,
            lon: result['lon'].to_f,
            display_name: result['display_name'],
            query: query,
            precision: precision
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

