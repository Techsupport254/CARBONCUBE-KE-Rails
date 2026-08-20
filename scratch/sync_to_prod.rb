require "pg"
require "json"

puts "🚀 Connecting directly to Production Database..."
prod_conn = PG.connect("postgresql://carbon:Nx9CC4ENjmmpcnqPeWLV@49.12.235.140:6543/postgres?sslmode=disable")

# 1. Backfill Seller Enterprise Names in Production
puts "\n[1/3] Backfilling Seller Enterprise Names in Production..."
unnamed_res = prod_conn.exec("SELECT id, fullname FROM sellers WHERE enterprise_name IS NULL OR TRIM(enterprise_name) = ''")
unnamed_res.each do |row|
  fallback_name = row["fullname"].to_s.strip.presence || "Merchant"
  prod_conn.exec_params("UPDATE sellers SET enterprise_name = $1 WHERE id = $2", [fallback_name, row["id"]])
end
puts "  ✅ Updated #{unnamed_res.ntuples} seller enterprise names."

# 2. Sync Unlocated Sellers & Branches in Production
puts "\n[2/3] Cleaning up unlocated branches in Production..."
clean_res = prod_conn.exec("UPDATE branches SET latitude = NULL, longitude = NULL, county_id = NULL, sub_county_id = NULL, location = NULL WHERE location IS NULL OR TRIM(location) = '' OR location ILIKE '%Unknown%'")
puts "  ✅ Cleaned #{clean_res.cmd_tuples} unlocated branches in Production."

# 3. Synchronize All Enriched Ads from Local to Production
puts "\n[3/3] Synchronizing all locally enriched ads to Production..."
enriched_count = 0
Ad.active.find_each(batch_size: 200) do |local_ad|
  next unless local_ad.specifications.present? && local_ad.specifications != {}

  res = prod_conn.exec_params("SELECT id, title, brand, manufacturer, specifications, description FROM ads WHERE id = $1", [local_ad.id])
  prod_ad = res.first
  next unless prod_ad

  prod_title = prod_ad["title"].to_s.strip
  local_title = local_ad.title.to_s.strip

  if prod_title != local_title || prod_ad["specifications"].blank? || prod_ad["specifications"] == "{}"
    specs_json = local_ad.specifications.is_a?(String) ? local_ad.specifications : local_ad.specifications.to_json
    prod_conn.exec_params(
      "UPDATE ads SET title = $1, brand = $2, manufacturer = $3, specifications = $4, description = $5 WHERE id = $6",
      [local_ad.title, local_ad.brand, local_ad.manufacturer, specs_json, local_ad.description, local_ad.id]
    )
    enriched_count += 1
  end
end
puts "  ✅ Synchronized #{enriched_count} enriched ads to Production database."

