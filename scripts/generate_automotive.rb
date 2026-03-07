#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'set'

OUTPUT_DIR = File.expand_path('output', __dir__)
OUT_FILE   = File.join(OUTPUT_DIR, 'automotive.json')

all_items = []

# =========================================================================
# TYRES
# =========================================================================

# Helper to build a Tyre entry
def build_tyre(brand, model, width, ratio, radius, load_index = "91", speed_rating = "V", extra_specs = {})
  title = "#{brand} #{model} #{width}/#{ratio} R#{radius} #{load_index}#{speed_rating} Tyre"
  slug = title.downcase.gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_').sub(/_$/, '')
  
  specs = {
    "Size" => "#{width}/#{ratio} R#{radius}",
    "Width" => "#{width} mm",
    "Aspect Ratio" => "#{ratio}%",
    "Rim Diameter" => "#{radius} inches",
    "Load Index" => load_index,
    "Speed Rating" => speed_rating
  }.merge(extra_specs)

  {
    title: title,
    slug: slug,
    brand: brand,
    category: "Automotive Parts & Accessories",
    subcategory: "Tyres",
    specifications: specs
  }
end

# Standard tyre dimensions
TYRE_DIMENSIONS = [
  [175, 70, 13], [175, 70, 14], [185, 65, 14], [185, 70, 14],
  [185, 60, 15], [185, 65, 15], [195, 65, 15], [205, 65, 15],
  [195, 55, 16], [205, 55, 16], [215, 60, 16], [225, 60, 16],
  [215, 55, 17], [225, 45, 17], [225, 50, 17], [225, 55, 17],
  [225, 60, 18], [235, 55, 18], [245, 40, 18], [245, 45, 18]
]

TYRE_BRANDS = [
  { name: "Michelin", models: ["Primacy 4", "Pilot Sport 4", "Energy Saver+"] },
  { name: "Bridgestone", models: ["Turanza T005", "Potenza Sport", "Ecopia EP150"] },
  { name: "Goodyear", models: ["EfficientGrip Performance", "Eagle F1 Asymmetric", "Assurance TripleMax"] },
  { name: "Continental", models: ["PremiumContact 6", "SportContact 7", "EcoContact 6"] },
  { name: "Pirelli", models: ["P Zero", "Cinturato P7", "Scorpion Verde"] },
  { name: "Dunlop", models: ["SP Sport Maxx", "Grandtrek", "Direzza"] },
  { name: "Hankook", models: ["Ventus Prime 3", "Kinergy Eco 2", "Dynapro", "Optimo"] },
  { name: "Yokohama", models: ["Advan Sport", "BluEarth", "Geolandar"] }
]

TYRE_BRANDS.each do |brand_data|
  brand_data[:models].each do |model|
    TYRE_DIMENSIONS.each do |w, r, rad|
      all_items << build_tyre(brand_data[:name], model, w, r, rad, ["91", "94", "98"].sample, ["H", "V", "W", "Y"].sample)
    end
  end
end

# =========================================================================
# BATTERIES
# =========================================================================

# Helper to build a Battery entry
def build_battery(brand, size_code, capacity_ah, cca, terminals, extra_specs = {})
  title = "#{brand} #{size_code} Car Battery - #{capacity_ah}Ah, #{cca} CCA"
  slug = title.downcase.gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_').sub(/_$/, '')
  
  specs = {
    "Voltage" => "12V",
    "Capacity (Ah)" => "#{capacity_ah} Ah",
    "Cold Cranking Amps (CCA)" => "#{cca} A",
    "Terminal Type" => terminals,
    "Size/Group Code" => size_code
  }.merge(extra_specs)

  {
    title: title,
    slug: slug,
    brand: brand,
    category: "Automotive Parts & Accessories",
    subcategory: "Batteries",
    specifications: specs
  }
end

BATTERY_BRANDS = ["Bosch", "Exide", "Amaron", "Varta", "Optima", "ACDelco", "Chloride Exide"]
BATTERY_SIZES = [
  { code: "N40", cap: 40, cca: 330, term: "Standard" },
  { code: "N50", cap: 50, cca: 400, term: "Standard" },
  { code: "N70", cap: 70, cca: 600, term: "Standard" },
  { code: "DIN44", cap: 44, cca: 360, term: "Recessed" },
  { code: "DIN55", cap: 55, cca: 480, term: "Recessed" },
  { code: "DIN65", cap: 65, cca: 540, term: "Recessed" },
  { code: "DIN74", cap: 74, cca: 680, term: "Recessed" },
  { code: "DIN100", cap: 100, cca: 850, term: "Recessed" }
]

BATTERY_BRANDS.each do |brand|
  BATTERY_SIZES.each do |info|
    all_items << build_battery(brand, info[:code], info[:cap], info[:cca], info[:term])
  end
end

# Merge with existing file to maintain uniqueness
existing_items = []
if File.exist?(OUT_FILE)
  existing_items = JSON.parse(File.read(OUT_FILE)) rescue []
end

existing_slugs = Set.new(existing_items.map { |t| t['slug'] || t[:slug] })
new_items = all_items.reject { |t| existing_slugs.include?(t[:slug]) }

final_list = existing_items + new_items

FileUtils.mkdir_p(OUTPUT_DIR)
File.write(OUT_FILE, JSON.pretty_generate(final_list))

puts "Successfully added #{new_items.size} Automotive items."
puts "Total Automotive catalog size: #{final_list.size}"
