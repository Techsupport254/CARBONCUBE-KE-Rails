namespace :geocode do
  desc "Dry-run each missing seller against Nominatim and write a report to tmp/geocode_preview.md"
  task preview: :environment do
    limit = ENV.fetch('LIMIT', nil)&.to_i

    sellers = Seller
      .includes(:county, :sub_county)
      .joins(:branches)
      .where(deleted: false)
      .where(branches: { latitude: nil })
      .distinct
      .order('sellers.enterprise_name ASC')

    sellers = sellers.limit(limit) if limit

    results = []

    sellers.each_with_index do |seller, index|
      begin
        sleep(1) if index.positive?

        query_parts = [
          seller.location.to_s.strip,
          seller.city.to_s.strip,
          seller.sub_county&.name,
          seller.county&.name,
          'Kenya'
        ].compact.map(&:strip).reject { |p| p.blank? || p == 'Kenya' }

        query_parts << 'Kenya'
        query = query_parts.join(', ')

        uri = URI('https://nominatim.openstreetmap.org/search')
        uri.query = URI.encode_www_form(
          q: query,
          format: 'json',
          limit: 1,
          addressdetails: 1,
          countrycodes: 'ke'
        )

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 10

        request = Net::HTTP::Get.new(uri.request_uri)
        request['User-Agent'] = 'CarbonCube-Kenya/1.0 (contact: info@carboncube-ke.com)'
        request['Accept'] = 'application/json'

        response = http.request(request)

        if response.is_a?(Net::HTTPSuccess)
          data = JSON.parse(response.body)

          if data.any?
            first = data.first
            display_name = first['display_name']
            address = first['address'] || {}
            lat = first['lat']
            lon = first['lon']

            matched_state = address['state'] || address['county']
            county = seller.county&.name&.downcase

            status = if county && matched_state && matched_state.to_s.downcase.include?(county)
                       'ok'
                     elsif county && matched_state
                       'county_mismatch'
                     else
                       'ok_no_county_data'
                     end

            results << {
              id: seller.id,
              business: seller.enterprise_name,
              location: seller.location,
              city: seller.city,
              sub_county: seller.sub_county&.name,
              county: seller.county&.name,
              query: query,
              lat: lat,
              lon: lon,
              display_name: display_name,
              status: status
            }
          else
            results << {
              id: seller.id,
              business: seller.enterprise_name,
              location: seller.location,
              city: seller.city,
              sub_county: seller.sub_county&.name,
              county: seller.county&.name,
              query: query,
              lat: nil,
              lon: nil,
              display_name: 'No results',
              status: 'not_found'
            }
          end
        else
          results << {
            id: seller.id,
            business: seller.enterprise_name,
            location: seller.location,
            city: seller.city,
            sub_county: seller.sub_county&.name,
            county: seller.county&.name,
            query: query,
            lat: nil,
            lon: nil,
            display_name: "HTTP #{response.code}",
            status: 'http_error'
          }
        end
      rescue => e
        results << {
          id: seller.id,
          business: seller.enterprise_name,
          location: seller.location,
          city: seller.city,
          sub_county: seller.sub_county&.name,
          county: seller.county&.name,
          query: query,
          lat: nil,
          lon: nil,
          display_name: "Error: #{e.message}",
          status: 'error'
        }
      end
    end

    output_path = Rails.root.join('tmp', 'geocode_preview.md')
    FileUtils.mkdir_p(output_path.dirname)

    status_counts = results.group_by { |r| r[:status] }.transform_values(&:count)

    File.open(output_path, 'w') do |f|
      f.puts "# Nominatim Geocoding Preview"
      f.puts
      f.puts "Generated: #{Time.current.strftime('%Y-%m-%d %H:%M %Z')}"
      f.puts "**Sellers checked:** #{results.size}"
      f.puts
      f.puts "## Summary"
      status_counts.each do |status, count|
        f.puts "- **#{status}:** #{count}"
      end
      f.puts
      f.puts "| # | Status | Business | Location | City | Sub-county | County | Query | Lat | Lon | OSM Display |"
      f.puts "|---|--------|----------|----------|------|------------|--------|-------|-----|-----|-------------|"
      results.each.with_index(1) do |r, idx|
        f.puts "| #{idx} | #{r[:status]} | #{r[:business]} | #{r[:location] || '-'} | #{r[:city] || '-'} | #{r[:sub_county] || '-'} | #{r[:county] || '-'} | #{r[:query]} | #{r[:lat] || '-'} | #{r[:lon] || '-'} | #{r[:display_name]} |"
      end
    end

    puts "Preview written to #{output_path}"
    puts status_counts.map { |s, c| "#{s}: #{c}" }.join(', ')
  end
end
