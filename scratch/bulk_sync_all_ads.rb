require "pg"
require "json"

puts "🚀 Connecting to production database..."
prod_conn = PG.connect("postgresql://carbon:Nx9CC4ENjmmpcnqPeWLV@49.12.235.140:6543/postgres?sslmode=disable")

# 1. Fetch all local ads with rich specifications
puts "Fetching local ads..."
local_ads = Ad.active.where.not(specifications: [nil, "", "{}"]).pluck(:id, :title, :brand, :manufacturer, :specifications, :model, :description)

puts "Comparing #{local_ads.size} local ads against production..."
updated_count = 0

prod_conn.exec("BEGIN")

local_ads.each_slice(100) do |slice|
  ids = slice.map { |a| a[0] }
  id_list = ids.join(",")
  
  res = prod_conn.exec("SELECT id, title, brand, manufacturer, specifications, model, description FROM ads WHERE id IN (#{id_list})")
  prod_map = res.index_by { |r| r["id"].to_i }

  slice.each do |id, title, brand, manufacturer, specifications, model, description|
    prod_row = prod_map[id]
    next unless prod_row

    # Check if mismatch
    prod_title = prod_row["title"].to_s.strip
    local_title = title.to_s.strip
    prod_specs = prod_row["specifications"].to_s.strip

    if prod_title != local_title || prod_specs.blank? || prod_specs == "{}"
      specs_json = specifications.is_a?(String) ? specifications : specifications.to_json
      prod_conn.exec_params(
        "UPDATE ads SET title = $1, brand = $2, manufacturer = $3, specifications = $4, model = $5, description = $6 WHERE id = $7",
        [title, brand, manufacturer, specs_json, model, description, id]
      )
      updated_count += 1
    end
  end
end

prod_conn.exec("COMMIT")
puts "✅ Successfully synchronized #{updated_count} ads to Production Database!"

