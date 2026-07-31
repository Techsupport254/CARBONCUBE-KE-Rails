namespace :geocode do
  desc "Dry-run improved geocoding using GeocodeSellersJob logic and write a report to tmp/geocode_preview2.md"
  task preview2: :environment do
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

    sellers.each do |seller|
      result = GeocodeSellersJob.new.send(:geocode_location, seller)

      results << {
        id: seller.id,
        business: seller.enterprise_name,
        location: seller.location,
        city: seller.city,
        sub_county: seller.sub_county&.name,
        county: seller.county&.name,
        query: result&.fetch(:query, nil),
        lat: result&.fetch(:lat, nil),
        lon: result&.fetch(:lon, nil),
        display_name: result&.fetch(:display_name, nil),
        status: result ? 'ok' : 'not_found'
      }
    end

    output_path = Rails.root.join('tmp', 'geocode_preview2.md')
    FileUtils.mkdir_p(output_path.dirname)

    status_counts = results.group_by { |r| r[:status] }.transform_values(&:count)

    File.open(output_path, 'w') do |f|
      f.puts "# Nominatim Geocoding Preview (improved)"
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
        f.puts "| #{idx} | #{r[:status]} | #{r[:business]} | #{r[:location] || '-'} | #{r[:city] || '-'} | #{r[:sub_county] || '-'} | #{r[:county] || '-'} | #{r[:query] || '-'} | #{r[:lat] || '-'} | #{r[:lon] || '-'} | #{r[:display_name] || '-'} |"
      end
    end

    puts "Preview written to #{output_path}"
    puts status_counts.map { |s, c| "#{s}: #{c}" }.join(', ')
  end
end
