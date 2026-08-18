require "csv"
require "uri"

desc "Generate a focused review list CSV for sellers needing manual Google Maps coordinate confirmation"
task generate_manual_review_csv: :environment do
  csv_path = ENV["CSV_PATH"] || Dir.glob(Rails.root.join("tmp", "seller_regeocode_nominatim_*.csv")).max_by { |f| File.mtime(f) } ||
             Dir.glob(Rails.root.join("tmp", "seller_coordinate_verification_*.csv")).max_by { |f| File.mtime(f) }
  limit = ENV["LIMIT"] ? ENV["LIMIT"].to_i : nil
  names_filter = ENV["NAMES"].to_s.split(",").map(&:strip).map(&:downcase).reject(&:blank?)
  seller_ids = ENV["SELLER_IDS"].to_s.split(",").map(&:strip).reject(&:blank?)

  sellers_data = []

  if csv_path && File.exist?(csv_path)
    puts "Reading candidates from CSV: #{csv_path}"
    rows = CSV.read(csv_path, headers: :first_row)

    target_rows = rows.select do |r|
      status = r["status"] || r["flag"]
      status.nil? || status != "distance_ok"
    end

    target_rows = target_rows.select { |r| seller_ids.include?(r["id"].to_s) } if seller_ids.any?
    target_rows = target_rows.select { |r| names_filter.any? { |n| r["enterprise_name"].to_s.downcase.include?(n) } } if names_filter.any?
    target_rows = target_rows.first(limit) if limit && limit > 0

    target_rows.each do |r|
      seller = Seller.find_by(id: r["id"])
      next unless seller

      branch = seller.branches.find_by(is_main_branch: true) || seller.branches.first
      sellers_data << { seller: seller, branch: branch, notes: r["status"] || r["flag"] || "manual_review" }
    end
  else
    puts "No previous verification CSV found. Fetching sellers directly from DB..."
    query = Seller.joins(:branches).where(deleted: false).distinct
    query = query.where(id: seller_ids) if seller_ids.any?
    query = query.where("enterprise_name ILIKE ?", "%#{names_filter.first}%") if names_filter.any?
    query = query.limit(limit) if limit && limit > 0

    query.find_each do |seller|
      branch = seller.branches.find_by(is_main_branch: true) || seller.branches.first
      sellers_data << { seller: seller, branch: branch, notes: "db_export" }
    end
  end

  timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
  out_path = Rails.root.join("tmp", "seller_manual_review_#{timestamp}.csv")

  headers = [
    "id", "enterprise_name", "fullname", "location", "city",
    "sub_county", "county", "current_lat", "current_lng",
    "google_maps_search_url", "google_maps_pin_url", "manual_lat", "manual_lng", "notes"
  ]

  CSV.open(out_path, "w") do |csv|
    csv << headers

    sellers_data.each do |item|
      s = item[:seller]
      b = item[:branch]
      loc = s.location.to_s
      city = s.city.to_s
      sub_county = s.sub_county&.name.to_s
      county = s.county&.name.to_s

      search_query = [s.enterprise_name, loc, city, sub_county, county]
                     .map(&:to_s).map(&:strip).reject(&:blank?).uniq.join(", ")

      search_url = "https://www.google.com/maps/search/?api=1&query=#{URI.encode_www_form_component(search_query)}"
      pin_url = b&.latitude && b&.longitude ? "https://www.google.com/maps/search/?api=1&query=#{b.latitude},#{b.longitude}" : ""

      csv << [
        s.id,
        s.enterprise_name,
        s.fullname,
        loc,
        city,
        sub_county,
        county,
        b&.latitude,
        b&.longitude,
        search_url,
        pin_url,
        nil, # manual_lat (empty for human review)
        nil, # manual_lng (empty for human review)
        item[:notes]
      ]
    end
  end

  puts "Manual review CSV generated: #{out_path}"
  puts "Total sellers in review list: #{sellers_data.size}"
  puts "Fill in 'manual_lat' and 'manual_lng' in the CSV and import using rake update_seller_coordinates_from_csv CSV_PATH=#{out_path}"
end
