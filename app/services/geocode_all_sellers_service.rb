class GeocodeAllSellersService
  NOMINATIM_API_URL = "https://nominatim.openstreetmap.org/search".freeze
  RATE_LIMIT_DELAY = 1.0 # 1 second rate limit for OSM Nominatim

  def self.call(options = {})
    new(options).perform
  end

  def initialize(options = {})
    @force = options.fetch(:force, true)
    @batch_size = options.fetch(:batch_size, 500)
    @logger = Rails.logger
  end

  def perform
    scope = Seller.where(deleted: false).includes(:branches, :county, :sub_county)
    total_count = scope.count

    puts "Starting complete re-geocoding for ALL #{total_count} sellers..."
    puts "Using Google Maps API: #{ENV['GOOGLE_MAPS_API_KEY'].present? ? 'YES' : 'NO (fallback to Nominatim)'}"

    stats = {
      total: total_count,
      exact: 0,
      sub_county: 0,
      county: 0,
      failed: 0
    }

    scope.find_each.with_index(1) do |seller, index|
      print "\rProcessing seller #{index}/#{total_count}: #{seller.enterprise_name.to_s.truncate(30)}..."

      result = geocode_seller(seller)

      if result
        seller.branches.each do |branch|
          branch.update_columns(
            latitude: result[:lat],
            longitude: result[:lon],
            location_precision: result[:precision],
            updated_at: Time.current
          )
        end

        case result[:precision]
        when 'exact' then stats[:exact] += 1
        when 'sub_county', 'approximate' then stats[:sub_county] += 1
        when 'county' then stats[:county] += 1
        end
      else
        stats[:failed] += 1
      end
    end

    puts "\n"
    puts "=" * 50
    puts "RE-GEOCODING ALL SELLERS COMPLETED"
    puts "=" * 50
    puts "Total Processed: #{stats[:total]}"
    puts "Exact Building Pins: #{stats[:exact]} (#{(stats[:exact].to_f / [stats[:total], 1].max * 100).round(1)}%)"
    puts "Sub-County Approx:   #{stats[:sub_county]} (#{(stats[:sub_county].to_f / [stats[:total], 1].max * 100).round(1)}%)"
    puts "County Approx:       #{stats[:county]} (#{(stats[:county].to_f / [stats[:total], 1].max * 100).round(1)}%)"
    puts "Failed/No Coords:    #{stats[:failed]}"
    puts "=" * 50

    stats
  end

  private

  def geocode_seller(seller)
    raw_loc = seller.location.to_s.strip
    cleaned_loc = sanitize_location(raw_loc)
    city = seller.city.to_s.strip
    sub_county = seller.sub_county&.name.to_s.strip
    county = seller.county&.name.to_s.strip

    # Candidate address strings ordered by specificity
    candidates = []

    if cleaned_loc.present?
      c1 = [cleaned_loc]
      c1 << city if city.present? && !cleaned_loc.downcase.include?(city.downcase)
      c1 << sub_county if sub_county.present? && !cleaned_loc.downcase.include?(sub_county.downcase)
      c1 << county if county.present? && !cleaned_loc.downcase.include?(county.downcase)
      c1 << 'Kenya'
      candidates << { address: c1.uniq.join(', '), type: :specific }

      c2 = [cleaned_loc, county, 'Kenya']
      candidates << { address: c2.uniq.join(', '), type: :specific }
    end

    candidates << { address: "#{sub_county}, #{county}, Kenya", type: :sub_county } if sub_county.present? && county.present?
    candidates << { address: "#{county}, Kenya", type: :county } if county.present?

    seen = Set.new
    candidates.select! { |c| seen.add?(c[:address]) }

    # Try Google Maps Geocoding API first if available
    if ENV['GOOGLE_MAPS_API_KEY'].present?
      candidates.each do |cand|
        res = google_geocode(cand[:address], cand[:type])
        return res if res
      end
    end

    # Fallback to OpenStreetMap Nominatim
    candidates.each do |cand|
      sleep(RATE_LIMIT_DELAY) if ENV['GOOGLE_MAPS_API_KEY'].blank?
      res = nominatim_geocode(cand[:address], cand[:type], county)
      return res if res
    end

    nil
  end

  def sanitize_location(loc)
    return "" if loc.blank?

    cleaned = loc.to_s.dup
    cleaned.gsub!(/P\.?\s*O\.?\s*BOX\s*\d+[a-z]?/i, '')
    cleaned.gsub!(/(?:\+?254|0)\s*\d{3}\s*\d{3}\s*\d{3}/, '')
    cleaned.gsub!(/tel:\s*[\d\s\-]+/i, '')
    cleaned.tr!(';', ',')
    cleaned.squeeze!(' ')
    cleaned.strip!
    cleaned.sub(/\A,+,?\s*/, '').sub(/\s*,+,\z/, '').strip
  end

  def google_geocode(address, query_type)
    return nil if ENV['GOOGLE_MAPS_API_KEY'].blank?

    uri = URI("https://maps.googleapis.com/maps/api/geocode/json")
    params = {
      address: address,
      components: 'country:KE',
      key: ENV['GOOGLE_MAPS_API_KEY']
    }
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 8

    response = http.request(Net::HTTP::Get.new(uri.request_uri))

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      if data['status'] == 'OK' && data['results'].any?
        top = data['results'].first
        loc_type = top.dig('geometry', 'location_type')
        lat = top.dig('geometry', 'location', 'lat')
        lng = top.dig('geometry', 'location', 'lng')

        precision = if query_type == :specific && %w[ROOFTOP RANGE_INTERPOLATED].include?(loc_type)
                      'exact'
                    elsif query_type == :sub_county || %w[GEOMETRIC_CENTER APPROXIMATE].include?(loc_type)
                      'sub_county'
                    elsif query_type == :county
                      'county'
                    else
                      'approximate'
                    end

        return { lat: lat.to_f, lon: lng.to_f, precision: precision }
      end
    end

    nil
  rescue => e
    Rails.logger.warn "Google Geocoding error for '#{address}': #{e.message}"
    nil
  end

  def nominatim_geocode(address, query_type, seller_county_name)
    uri = URI(NOMINATIM_API_URL)
    params = {
      q: address,
      format: 'json',
      limit: 5,
      addressdetails: 1,
      countrycodes: 'ke'
    }
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 8

    req = Net::HTTP::Get.new(uri.request_uri)
    req['User-Agent'] = 'CarbonCube-Kenya/1.0 (contact: info@carboncube-ke.com)'
    req['Accept'] = 'application/json'

    response = http.request(req)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      if data.any?
        county_name = seller_county_name.to_s.downcase.strip

        result = data.find do |r|
          addr = r['address'] || {}
          fields = [addr['state'], addr['county'], addr['region'], addr['state_district'], addr['city'], addr['town']].compact.map(&:to_s).map(&:downcase)
          county_name.blank? || fields.any? { |f| f.include?(county_name) || county_name.include?(f) }
        end

        result ||= data.first

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

          return { lat: result['lat'].to_f, lon: result['lon'].to_f, precision: precision }
        end
      end
    end

    nil
  rescue => e
    Rails.logger.warn "Nominatim error for '#{address}': #{e.message}"
    nil
  end
end
