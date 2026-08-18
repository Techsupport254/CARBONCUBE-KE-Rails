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

desc "Import manually confirmed Google Maps coordinates from a CSV and update branch coordinates safely"
task update_seller_coordinates_from_csv: :environment do
  csv_path = ENV["CSV_PATH"] || Dir.glob(Rails.root.join("tmp", "seller_manual_review_*.csv")).max_by { |f| File.mtime(f) }

  raise "No CSV file provided or found. Usage: rake update_seller_coordinates_from_csv CSV_PATH=tmp/your_file.csv" unless csv_path && File.exist?(csv_path)

  puts "Reading manual coordinates from: #{csv_path}"
  rows = CSV.read(csv_path, headers: :first_row)

  timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
  out_path = Rails.root.join("tmp", "manual_coordinate_update_log_#{timestamp}.csv")
  headers = %w[seller_id enterprise_name old_lat old_lng new_lat new_lng distance_moved_km status notes]

  updated_count = 0
  skipped_count = 0
  error_count = 0

  CSV.open(out_path, "w") do |csv|
    csv << headers

    rows.each_with_index do |row, idx|
      seller_id = row["id"] || row["seller_id"]
      enterprise_name = row["enterprise_name"]

      lat_raw = row["manual_lat"] || row["new_lat"] || row["latitude"] || row["lat"]
      lng_raw = row["manual_lng"] || row["new_lng"] || row["longitude"] || row["lng"]

      if lat_raw.blank? || lng_raw.blank?
        skipped_count += 1
        csv << [seller_id, enterprise_name, nil, nil, nil, nil, nil, "skipped", "Empty coordinates"]
        next
      end

      lat = Float(lat_raw) rescue nil
      lng = Float(lng_raw) rescue nil

      if lat.nil? || lng.nil? || lat < -90.0 || lat > 90.0 || lng < -180.0 || lng > 180.0
        error_count += 1
        puts "Invalid coordinates for Seller ID #{seller_id}: '#{lat_raw}', '#{lng_raw}'"
        csv << [seller_id, enterprise_name, nil, nil, lat_raw, lng_raw, nil, "error", "Invalid coordinate format"]
        next
      end

      # Warning check for Kenya bounding box (approx lat -5 to 5, lng 33 to 42)
      if lat < -5.0 || lat > 5.5 || lng < 33.5 || lng > 42.5
        puts "Warning: Coordinates (#{lat}, #{lng}) for seller ID #{seller_id} are outside typical Kenya boundaries."
      end

      seller = Seller.find_by(id: seller_id)
      unless seller
        error_count += 1
        puts "Seller ID #{seller_id} not found in database."
        csv << [seller_id, enterprise_name, nil, nil, lat, lng, nil, "error", "Seller record not found"]
        next
      end

      branches = seller.branches
      if branches.empty?
        error_count += 1
        puts "No branch found for Seller ID #{seller_id}."
        csv << [seller_id, seller.enterprise_name, nil, nil, lat, lng, nil, "error", "No branch record"]
        next
      end

      main_branch = branches.find_by(is_main_branch: true) || branches.first
      old_lat = main_branch.latitude
      old_lng = main_branch.longitude

      distance_km = haversine_km(old_lat&.to_f, old_lng&.to_f, lat, lng)

      # Update main branch (and secondary branches if applicable)
      branches.each do |b|
        b.update!(latitude: lat, longitude: lng)
      end

      updated_count += 1
      puts "Updated seller #{seller.id} (#{seller.enterprise_name}): (#{old_lat}, #{old_lng}) -> (#{lat}, #{lng}) [#{distance_km.round(3)} km moved]"
      csv << [seller.id, seller.enterprise_name, old_lat, old_lng, lat, lng, distance_km.round(3), "updated", "Successfully imported"]
    end
  end

  puts "--- Manual Import Summary ---"
  puts "Updated: #{updated_count}"
  puts "Skipped (empty): #{skipped_count}"
  puts "Errors: #{error_count}"
  puts "Audit log written to: #{out_path}"
end
