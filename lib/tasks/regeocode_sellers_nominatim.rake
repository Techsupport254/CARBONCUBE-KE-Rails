require "csv"

def haversine_km(lat1, lon1, lat2, lon2)
  return 0.0 if lat1.nil? || lon1.nil? || lat2.nil? || lon2.nil?
  d_lat = (lat2 - lat1) * Math::PI / 180.0
  d_lon = (lon2 - lon1) * Math::PI / 180.0
  a = Math.sin(d_lat / 2)**2 +
      Math.cos(lat1 * Math::PI / 180.0) * Math.cos(lat2 * Math::PI / 180.0) * Math.sin(d_lon / 2)**2
  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  6371.0 * c
end

desc "Re-geocode sellers that were flagged by verify_seller_coordinates using the more thorough GeocodeSellersJob"
task regeocode_sellers_nominatim: :environment do
  $stdout.sync = true
  csv_path = ENV["CSV_PATH"] || Dir.glob(Rails.root.join("tmp", "seller_coordinate_verification_*.csv")).max_by { |f| File.mtime(f) }

  offset = ENV["OFFSET"] ? ENV["OFFSET"].to_i : 0
  limit = ENV["LIMIT"] || ENV["BATCH_SIZE"] ? (ENV["LIMIT"] || ENV["BATCH_SIZE"]).to_i : nil
  names_filter = ENV["NAMES"].to_s.split(",").map(&:strip).map(&:downcase).reject(&:blank?)
  seller_ids = ENV["SELLER_IDS"].to_s.split(",").map(&:strip).reject(&:blank?)

  raise "No verification CSV found in tmp/seller_coordinate_verification_*.csv. Set CSV_PATH." unless csv_path && File.exist?(csv_path)

  rows = CSV.read(csv_path, headers: :first_row)
  flagged = rows.select { |r| r["flag"] != "distance_ok" }
  flagged = flagged.select { |r| seller_ids.include?(r["id"].to_s) } if seller_ids.any?
  flagged = flagged.select { |r| names_filter.any? { |n| r["enterprise_name"].to_s.downcase.include?(n) } } if names_filter.any?
  
  if offset > 0
    puts "Applying offset: skipping first #{offset} flagged records..."
    flagged = flagged.drop(offset)
  end

  flagged = flagged.first(limit) if limit && limit > 0

  total = flagged.length
  puts "Re-geocoding #{total} flagged sellers from #{csv_path} (offset #{offset})..."

  timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
  out_path = Rails.root.join("tmp", "seller_regeocode_nominatim_#{timestamp}.csv")
  out_headers = %w[id enterprise_name location county old_lat old_lng new_lat new_lng status distance_km display_name query]

  CSV.open(out_path, "w") do |csv|
    csv << out_headers

    flagged.each_with_index do |row, i|
      seller = Seller.find_by(id: row["id"])
      unless seller
        puts "Seller #{row['id']} not found, skipping"
        next
      end

      branch = seller.branches.find_by(is_main_branch: true) || seller.branches.first
      unless branch
        puts "No branch for seller #{seller.id}, skipping"
        next
      end

      old_lat = branch.latitude
      old_lng = branch.longitude

      result = GeocodeSellersJob.new.send(:geocode_location, seller, sync: false)

      if result
        new_lat = result[:lat]
        new_lng = result[:lon]

        changed = (old_lat.to_f - new_lat).abs > 0.0001 || (old_lng.to_f - new_lng).abs > 0.0001
        status = changed ? "updated" : "unchanged"
        distance = haversine_km(old_lat.to_f, old_lng.to_f, new_lat, new_lng) if changed

        branch.update(latitude: new_lat, longitude: new_lng) if changed

        csv << [
          seller.id, seller.enterprise_name, seller.location, seller.county&.name,
          old_lat, old_lng, new_lat, new_lng, status, distance&.round(3), result[:display_name], result[:query]
        ]
      else
        csv << [
          seller.id, seller.enterprise_name, seller.location, seller.county&.name,
          old_lat, old_lng, nil, nil, "still_unavailable", nil, nil, nil
        ]
      end

      puts "#{i + 1}/#{total} processed" if (i + 1) % 10 == 0 || (i + 1) == total
    end
  end

  puts "Re-geocode CSV written to: #{out_path}"
end

