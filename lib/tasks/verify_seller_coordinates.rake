require "csv"
require "uri"

desc "Generate a CSV of seller coordinates with Google Maps verification links (no API key)."
task verify_seller_coordinates: :environment do
  before_days = ENV["BEFORE_DAYS"] || "30"
  limit       = ENV["LIMIT"] ? ENV["LIMIT"].to_i : nil
  use_nominatim = %w[1 true yes].include?(ENV["USE_NOMINATIM"].to_s.downcase)
  distance_threshold_km = (ENV["KM_THRESHOLD"] || "20").to_f

  sellers = Seller.joins(:branches)
                  .where(deleted: false)
                  .where.not(branches: { latitude: nil, longitude: nil })

  if before_days.downcase != "all"
    before = before_days.to_i.days.ago
    sellers = sellers.where("sellers.created_at <= ?", before)
    puts "Filtering sellers created before #{before.to_date} (#{before_days} days ago)..."
  else
    puts "Processing all sellers with coordinates..."
  end

  sellers = sellers.limit(limit) if limit && limit > 0
  total = sellers.count
  puts "Found #{total} sellers to verify."

  timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
  out_path = Rails.root.join("tmp", "seller_coordinate_verification_#{timestamp}.csv")

  headers = [
    "id", "enterprise_name", "fullname", "location", "city",
    "sub_county", "county", "stored_lat", "stored_lng",
    "google_maps_search_url", "google_maps_pin_url"
  ]

  if use_nominatim
    headers += ["nominatim_lat", "nominatim_lng", "distance_km", "flag"]
  end

  CSV.open(out_path, "w") do |csv|
    csv << headers

    sellers.find_each.with_index do |seller, i|
      branch = seller.branches.find_by(is_main_branch: true) || seller.branches.first

      location = seller.location.to_s
      city = seller.city.to_s
      county = seller.county&.name.to_s
      sub_county = seller.sub_county&.name.to_s

      google_search_query = [seller.enterprise_name, location, city, sub_county, county]
                            .map(&:to_s)
                            .map(&:strip)
                            .reject(&:blank?)
                            .uniq
                            .join(", ")

      search_url = "https://www.google.com/maps/search/?api=1&query=#{URI.encode_www_form_component(google_search_query)}"
      pin_url = "https://www.google.com/maps/search/?api=1&query=#{branch.latitude},#{branch.longitude}"

      row = [
        seller.id,
        seller.enterprise_name,
        seller.fullname,
        location,
        city,
        sub_county,
        county,
        branch.latitude,
        branch.longitude,
        search_url,
        pin_url
      ]

      if use_nominatim
        nominatim_query = [location, city, sub_county, county]
                          .map(&:to_s)
                          .map(&:strip)
                          .reject(&:blank?)
                          .uniq
                          .join(", ")

        result = GeocodeSellersJob.new.send(:nominatim_search, nominatim_query, county, true)
        sleep 1 # Nominatim rate limit

        if result
          nominatim_lat = result[:lat]
          nominatim_lng = result[:lon]
          distance = haversine_km(branch.latitude, branch.longitude, nominatim_lat, nominatim_lng)
          flag = distance <= distance_threshold_km ? "distance_ok" : "distance_mismatch"
          row += [nominatim_lat, nominatim_lng, distance.round(3), flag]
        else
          row += [nil, nil, nil, "nominatim_unavailable"]
        end
      end

      csv << row
      puts "#{i + 1}/#{total} processed" if (i + 1) % 100 == 0
    end
  end

  puts "Verification CSV written to: #{out_path}"
  puts "Open the search_url column in a browser to compare the enterprise name + location with the stored pin."
  puts "Set USE_NOMINATIM=1 to add an automated Nominatim distance cross-check (slower)." unless use_nominatim
end

def haversine_km(lat1, lon1, lat2, lon2)
  d_lat = to_rad(lat2 - lat1)
  d_lon = to_rad(lon2 - lon1)
  a = Math.sin(d_lat / 2) ** 2 +
      Math.cos(to_rad(lat1)) * Math.cos(to_rad(lat2)) * Math.sin(d_lon / 2) ** 2
  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  6371.0 * c
end

def to_rad(deg)
  deg * Math::PI / 180.0
end
