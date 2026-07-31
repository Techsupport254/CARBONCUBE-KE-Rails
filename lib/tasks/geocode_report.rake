namespace :geocode do
  desc "Export a markdown report of sellers with missing branch coordinates to tmp/missing_sellers.md"
  task missing_report: :environment do
    sellers = Seller
      .includes(:county, :sub_county)
      .joins(:branches)
      .where(deleted: false)
      .where(branches: { latitude: nil })
      .distinct
      .order('sellers.enterprise_name ASC')

    missing = sellers.map do |seller|
      {
        id: seller.id,
        name: seller.fullname,
        business: seller.enterprise_name,
        location: seller.location,
        city: seller.city,
        county: seller.county&.name || 'Unknown',
        sub_county: seller.sub_county&.name || 'Unknown',
        ads: seller.ads_count
      }
    end

    output_path = Rails.root.join('tmp', 'missing_sellers.md')
    FileUtils.mkdir_p(output_path.dirname)

    File.open(output_path, 'w') do |f|
      f.puts "# Sellers Missing Coordinates"
      f.puts
      f.puts "Generated: #{Time.current.strftime('%Y-%m-%d %H:%M %Z')}"
      f.puts
      f.puts "**Total missing:** #{missing.size}"
      f.puts
      f.puts "| # | Business | Name | Location | City | County | Sub-county | Ads |"
      f.puts "|---|----------|------|----------|------|--------|------------|-----|"
      missing.each.with_index(1) do |s, idx|
        f.puts "| #{idx} | #{s[:business]} | #{s[:name]} | #{s[:location] || '-'} | #{s[:city] || '-'} | #{s[:county]} | #{s[:sub_county]} | #{s[:ads]} |"
      end
    end

    puts "Report written to #{output_path}"
  end
end
