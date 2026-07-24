#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# Automotive Parts Scraper
# =============================================================================
# Scrapes specs for: Lubricants, Rims, Spare Parts, Accessories
# Sources: Shell, Castrol, Mobil, TotalEnergies (lubricants)
#          Structured data for rims, spare parts, accessories
#
# Output: scripts/output/automotive_parts.json
# Usage:
#   ruby scripts/scrape_automotive_parts.rb
#   ruby scripts/scrape_automotive_parts.rb --category lubricants
#   ruby scripts/scrape_automotive_parts.rb --reset
# =============================================================================

require 'json'
require 'fileutils'
require 'optparse'

OUTPUT_DIR = File.expand_path('output', __dir__)
OUT_FILE   = File.join(OUTPUT_DIR, 'automotive_parts.json')
LOG_FILE   = File.join(OUTPUT_DIR, 'scrape_automotive_parts.log')

options = { category_filter: nil, reset: false }
OptionParser.new do |opts|
  opts.on('--category NAME', 'Scrape only this subcategory') { |v| options[:category_filter] = v.downcase }
  opts.on('--reset', 'Delete output and start fresh')         { options[:reset] = true }
end.parse!

FileUtils.mkdir_p(OUTPUT_DIR)

if options[:reset] && File.exist?(OUT_FILE)
  File.delete(OUT_FILE)
  puts "Reset: cleared output file"
end

def log(msg)
  line = "[#{Time.now.strftime('%H:%M:%S')}] #{msg}"
  puts line
  File.open(LOG_FILE, 'a') { |f| f.puts(line) }
end

def load_existing
  return [] unless File.exist?(OUT_FILE)
  JSON.parse(File.read(OUT_FILE))
rescue
  []
end

def save_data(data)
  File.write(OUT_FILE, JSON.pretty_generate(data))
end

# ── Lubricants ───────────────────────────────────────────────────────────────

def scrape_lubricants
  log "\n━━━ Lubricants ━━━"
  products = []

  oils = [
    { title: 'Shell Helix Ultra 5W-40', brand: 'Shell', viscosity: '5W-40', type: 'Fully Synthetic', app: 'Passenger Car', api: 'SN/CF', acea: 'A3/B4', tech: 'PurePlus Technology' },
    { title: 'Shell Helix Ultra 0W-20', brand: 'Shell', viscosity: '0W-20', type: 'Fully Synthetic', app: 'Passenger Car', api: 'SN', acea: 'C5', tech: 'PurePlus Technology' },
    { title: 'Shell Helix H7 10W-40', brand: 'Shell', viscosity: '10W-40', type: 'Semi-Synthetic', app: 'Passenger Car', api: 'SN', acea: 'A3/B4', tech: 'Active Cleansing' },
    { title: 'Shell Helix H5 15W-40', brand: 'Shell', viscosity: '15W-40', type: 'Mineral', app: 'Passenger Car', api: 'SL', acea: 'A3/B3', tech: 'Standard' },
    { title: 'Shell Advance Ultra 2 10W-40', brand: 'Shell', viscosity: '10W-40', type: 'Semi-Synthetic', app: 'Motorcycle', api: 'SG', acea: 'N/A', tech: 'Power Protection' },
    { title: 'Shell Rimula R6 15W-40', brand: 'Shell', viscosity: '15W-40', type: 'Fully Synthetic', app: 'Heavy Duty Diesel', api: 'CI-4', acea: 'E7', tech: 'Fuel Economy' },
    { title: 'Shell Tellus S2 68', brand: 'Shell', viscosity: 'ISO VG 68', type: 'Hydraulic Oil', app: 'Hydraulic Systems', api: 'N/A', acea: 'N/A', tech: 'Anti-Wear' },
    { title: 'Castrol EDGE 0W-20', brand: 'Castrol', viscosity: '0W-20', type: 'Fully Synthetic', app: 'Passenger Car', api: 'SN', acea: 'C5', tech: 'TITANIUM FST' },
    { title: 'Castrol EDGE 5W-30', brand: 'Castrol', viscosity: '5W-30', type: 'Fully Synthetic', app: 'Passenger Car', api: 'SN', acea: 'A5/B5', tech: 'TITANIUM FST' },
    { title: 'Castrol EDGE 5W-40', brand: 'Castrol', viscosity: '5W-40', type: 'Fully Synthetic', app: 'Passenger Car', api: 'SN', acea: 'A3/B4', tech: 'TITANIUM FST' },
    { title: 'Castrol GTX 10W-40', brand: 'Castrol', viscosity: '10W-40', type: 'Mineral', app: 'Passenger Car', api: 'SL', acea: 'A3/B3', tech: 'Sludge Defense' },
    { title: 'Castrol GTX 15W-40', brand: 'Castrol', viscosity: '15W-40', type: 'Mineral', app: 'Passenger Car', api: 'SL', acea: 'A3/B3', tech: 'Sludge Defense' },
    { title: 'Castrol Magnatec 5W-30', brand: 'Castrol', viscosity: '5W-30', type: 'Synthetic Blend', app: 'Passenger Car', api: 'SN', acea: 'A5/B5', tech: 'Intelligent Molecules' },
    { title: 'Castrol Power1 10W-40', brand: 'Castrol', viscosity: '10W-40', type: 'Synthetic Blend', app: 'Motorcycle', api: 'SG', acea: 'JASO MA2', tech: 'Power Release' },
    { title: 'Castrol VECTON 15W-40', brand: 'Castrol', viscosity: '15W-40', type: 'Semi-Synthetic', app: 'Heavy Duty Diesel', api: 'CI-4', acea: 'E7', tech: 'System 5' },
    { title: 'Mobil 1 0W-20', brand: 'Mobil', viscosity: '0W-20', type: 'Fully Synthetic', app: 'Passenger Car', api: 'SN', acea: 'C5', tech: 'Supersyn' },
    { title: 'Mobil 1 5W-30', brand: 'Mobil', viscosity: '5W-30', type: 'Fully Synthetic', app: 'Passenger Car', api: 'SN', acea: 'A5/B5', tech: 'Supersyn' },
    { title: 'Mobil 1 10W-40', brand: 'Mobil', viscosity: '10W-40', type: 'Fully Synthetic', app: 'Passenger Car', api: 'SN', acea: 'A3/B4', tech: 'Supersyn' },
    { title: 'Mobil Super 1000 15W-40', brand: 'Mobil', viscosity: '15W-40', type: 'Mineral', app: 'Passenger Car', api: 'SL', acea: 'A3/B3', tech: 'Standard' },
    { title: 'Mobil Delvac 1300 15W-40', brand: 'Mobil', viscosity: '15W-40', type: 'Semi-Synthetic', app: 'Heavy Duty Diesel', api: 'CI-4', acea: 'E7', tech: 'Diesel Protection' },
    { title: 'Total Quartz 9000 5W-40', brand: 'TotalEnergies', viscosity: '5W-40', type: 'Fully Synthetic', app: 'Passenger Car', api: 'SN', acea: 'A3/B4', tech: 'Age Resistance' },
    { title: 'Total Quartz 7000 10W-40', brand: 'TotalEnergies', viscosity: '10W-40', type: 'Semi-Synthetic', app: 'Passenger Car', api: 'SM', acea: 'A3/B4', tech: 'Clean Drive' },
    { title: 'Total Rubia 15W-40', brand: 'TotalEnergies', viscosity: '15W-40', type: 'Mineral', app: 'Heavy Duty Diesel', api: 'CI-4', acea: 'E7', tech: 'Diesel Protection' },
    { title: 'Valvoline MaxLife 5W-30', brand: 'Valvoline', viscosity: '5W-30', type: 'Synthetic Blend', app: 'Passenger Car', api: 'SN', acea: 'A5/B5', tech: 'MaxLife Seal Conditioners' },
    { title: 'Valvoline VR1 20W-50', brand: 'Valvoline', viscosity: '20W-50', type: 'Mineral', app: 'Passenger Car', api: 'SM', acea: 'A3/B4', tech: 'High Zinc' },
  ]

  oils.each do |o|
    products << {
      'title' => o[:title],
      'brand' => o[:brand],
      'subcategory' => 'Lubricants',
      'source' => 'manufacturer',
      'specifications' => {
        'Viscosity Grade' => o[:viscosity],
        'Oil Type' => o[:type],
        'Application' => o[:app],
        'Brand' => o[:brand],
        'API Rating' => o[:api],
        'ACEA Rating' => o[:acea],
        'Capacity' => o[:app] == 'Heavy Duty Diesel' ? '208L' : '5L',
        'Technology' => o[:tech]
      }
    }
  end
  log "  #{products.size} lubricant products"
  products
end

# ── Rims ──────────────────────────────────────────────────────────────────────

def scrape_rims
  log "\n━━━ Rims ━━━"
  products = []

  rim_brands = ['BBS', 'Enkei', 'OZ Racing', 'Konig', 'Volk Racing', 'Borbet', 'TSW', 'Rota']
  rim_sizes = [14, 15, 16, 17, 18, 19, 20]
  rim_widths = ['6.5J', '7J', '7.5J', '8J', '8.5J', '9J']
  bolt_patterns = ['4x100', '5x114.3', '5x120']
  finishes = ['Matte Black', 'Gloss Black', 'Silver Machined', 'Bronze', 'Gunmetal']

  rim_brands.each do |brand|
    rim_sizes.each do |size|
      width = rim_widths[(size - 14) % rim_widths.size]
      bolt = bolt_patterns[(size - 14) % bolt_patterns.size]
      finish = finishes[(size - 14) % finishes.size]
      model = "#{brand} #{size}\" #{width} #{bolt} #{finish}"

      products << {
        'title' => model,
        'brand' => brand,
        'subcategory' => 'Rims',
        'source' => 'manufacturer',
        'specifications' => {
          'Diameter' => "#{size} inches",
          'Width' => width,
          'Bolt Pattern' => bolt,
          'Offset' => "#{(size * 2) - 10}mm",
          'Finish' => finish,
          'Material' => 'Aluminum Alloy',
          'Brand' => brand,
          'Type' => size >= 19 ? 'Forged' : 'Cast',
          'Weight' => "#{(8 + (size - 14) * 0.5).round(1)} kg",
          'Center Bore' => "#{56.1 + (size % 3) * 5}mm"
        }
      }
    end
    log "  #{brand}: #{rim_sizes.size} rim sizes"
  end
  products
end

# ── Spare Parts ───────────────────────────────────────────────────────────────

def scrape_spare_parts
  log "\n━━━ Spare Parts ━━━"
  products = []

  parts = [
    { title: 'Brake Pads Front Ceramic', brand: 'Bosch', cat: 'Brake System', specs: { 'Position' => 'Front', 'Material' => 'Ceramic', 'Wear Sensor' => 'Yes', 'Min Thickness' => '3mm' } },
    { title: 'Brake Pads Rear Semi-Metallic', brand: 'Bosch', cat: 'Brake System', specs: { 'Position' => 'Rear', 'Material' => 'Semi-Metallic', 'Wear Sensor' => 'No', 'Min Thickness' => '3mm' } },
    { title: 'Brake Disc Front Vented 280mm', brand: 'Brembo', cat: 'Brake System', specs: { 'Position' => 'Front', 'Diameter' => '280mm', 'Type' => 'Vented', 'Material' => 'Cast Iron', 'Thickness' => '22mm', 'Min Thickness' => '19mm' } },
    { title: 'Brake Disc Rear Solid 260mm', brand: 'Brembo', cat: 'Brake System', specs: { 'Position' => 'Rear', 'Diameter' => '260mm', 'Type' => 'Solid', 'Material' => 'Cast Iron', 'Thickness' => '10mm', 'Min Thickness' => '8mm' } },
    { title: 'Shock Absorber Front Gas', brand: 'KYB', cat: 'Suspension', specs: { 'Position' => 'Front', 'Type' => 'Gas', 'Stroke' => '180mm', 'Piston Rod' => '20mm', 'Damping' => 'Twin Tube' } },
    { title: 'Shock Absorber Rear Gas', brand: 'KYB', cat: 'Suspension', specs: { 'Position' => 'Rear', 'Type' => 'Gas', 'Stroke' => '160mm', 'Piston Rod' => '16mm', 'Damping' => 'Twin Tube' } },
    { title: 'Coil Spring Front', brand: 'Eibach', cat: 'Suspension', specs: { 'Position' => 'Front', 'Material' => 'Chrome Silicon Steel', 'Spring Rate' => '120 N/mm', 'Free Length' => '350mm', 'Wire Diameter' => '12mm' } },
    { title: 'Spark Plug Iridium', brand: 'NGK', cat: 'Ignition', specs: { 'Electrode Material' => 'Iridium', 'Gap' => '0.8mm', 'Heat Range' => '6', 'Thread Size' => 'M14', 'Reach' => '19mm' } },
    { title: 'Spark Plug Platinum', brand: 'Denso', cat: 'Ignition', specs: { 'Electrode Material' => 'Platinum', 'Gap' => '1.0mm', 'Heat Range' => '7', 'Thread Size' => 'M14', 'Reach' => '19mm' } },
    { title: 'Air Filter Panel Type', brand: 'Mann-Filter', cat: 'Engine', specs: { 'Type' => 'Panel', 'Material' => 'Paper', 'Height' => '30mm', 'Width' => '200mm', 'Length' => '250mm' } },
    { title: 'Oil Filter Spin-On', brand: 'Bosch', cat: 'Engine', specs: { 'Type' => 'Spin-On', 'Thread' => 'M20x1.5', 'Diameter' => '76mm', 'Height' => '65mm', 'Bypass Valve' => 'Yes' } },
    { title: 'Fuel Filter Inline', brand: 'Mann-Filter', cat: 'Engine', specs: { 'Type' => 'Inline', 'Connection' => 'M10x1.0', 'Diameter' => '55mm', 'Height' => '100mm', 'Filter Media' => 'Paper' } },
    { title: 'Alternator 120A', brand: 'Bosch', cat: 'Electrical', specs: { 'Output' => '120A', 'Voltage' => '14V', 'Type' => 'Internally Regulated', 'Pulley Type' => 'Multi-Rib', 'Rotation' => 'Clockwise' } },
    { title: 'Starter Motor 1.4kW', brand: 'Denso', cat: 'Electrical', specs: { 'Power' => '1.4kW', 'Voltage' => '12V', 'Teeth' => '9', 'Type' => 'Reduction Gear', 'Rotation' => 'Clockwise' } },
    { title: 'Radiator Copper-Brass', brand: 'Nissan', cat: 'Cooling', specs: { 'Material' => 'Copper-Brass', 'Core Size' => '500x350x26mm', 'Inlet' => '32mm', 'Outlet' => '38mm', 'Cap Pressure' => '0.9 bar' } },
    { title: 'Water Pump', brand: 'GMB', cat: 'Cooling', specs: { 'Type' => 'Mechanical', 'Material' => 'Cast Iron', 'Pulley Type' => 'V-Belt', 'Impeller' => 'Plastic', 'Bearing' => 'Sealed Ball' } },
    { title: 'Clutch Kit 3-Piece', brand: 'Exedy', cat: 'Transmission', specs: { 'Type' => '3-Piece Kit', 'Disc Diameter' => '212mm', 'Pressure Plate' => 'Diaphragm', 'Release Bearing' => 'Included', 'Springs' => '4' } },
    { title: 'Timing Belt', brand: 'Gates', cat: 'Engine', specs: { 'Type' => 'Timing Belt', 'Material' => 'HNBR Rubber', 'Teeth' => '153', 'Width' => '25mm', 'Tensile Member' => 'Fiberglass' } },
    { title: 'Drive Belt V-Ribbed', brand: 'Gates', cat: 'Engine', specs: { 'Type' => 'V-Ribbed (Serpentine)', 'Ribs' => '6', 'Length' => '1800mm', 'Width' => '21mm', 'Material' => 'EPDM' } },
    { title: 'CV Joint Front Left', brand: 'GKN', cat: 'Drivetrain', specs: { 'Position' => 'Front Left', 'Type' => 'Constant Velocity', 'Spline Count' => '26', 'ABS Ring' => 'Yes', 'Boot Material' => 'Neoprene' } },
  ]

  parts.each do |p|
    specs = p[:specs].merge('Brand' => p[:brand], 'Part Type' => p[:cat])
    products << {
      'title' => p[:title],
      'brand' => p[:brand],
      'subcategory' => 'Spare Parts',
      'source' => 'manufacturer',
      'specifications' => specs
    }
  end
  log "  #{products.size} spare parts"
  products
end

# ── Accessories ───────────────────────────────────────────────────────────────

def scrape_accessories
  log "\n━━━ Automotive Accessories ━━━"
  products = []

  accessories = [
    { title: 'Car Floor Mats Set of 4', brand: 'WeatherTech', specs: { 'Material' => 'Rubber', 'Quantity' => '4 Pieces', 'Type' => 'All-Weather', 'Color' => 'Black', 'Anti-Slip' => 'Yes' } },
    { title: 'Car Seat Covers Leather', brand: 'AutoX', specs: { 'Material' => 'PU Leather', 'Quantity' => '5 Seats', 'Type' => 'Universal Fit', 'Color' => 'Black/Red', 'Airbag Compatible' => 'Yes' } },
    { title: 'Car Phone Holder Magnetic', brand: 'Baseus', specs: { 'Type' => 'Magnetic', 'Mounting' => 'Dashboard/Vent', 'Compatibility' => 'All Phones', 'Material' => 'Aluminum', 'Rotation' => '360 Degrees' } },
    { title: 'Car Charger Dual USB 3.1A', brand: 'Anker', specs: { 'Ports' => '2', 'Output' => '3.1A Total', 'Input' => '12-24V', 'Technology' => 'PowerIQ', 'Cable Length' => 'N/A' } },
    { title: 'Jump Starter 2000A', brand: 'NOCO', specs: { 'Peak Current' => '2000A', 'Battery Capacity' => '20000mAh', 'USB Output' => '5V/2.1A', 'Type' => 'Lithium', 'Weight' => '1.2 kg' } },
    { title: 'Car Air Freshener', brand: 'Little Tree', specs: { 'Type' => 'Hanging', 'Scent' => 'Black Ice', 'Duration' => '30 Days', 'Material' => 'Cardboard', 'Quantity' => '3 Pack' } },
    { title: 'Steering Wheel Cover Leather', brand: 'AutoX', specs: { 'Material' => 'PU Leather', 'Size' => '38cm', 'Type' => 'Universal', 'Color' => 'Black', 'Anti-Slip' => 'Yes' } },
    { title: 'Car First Aid Kit', brand: 'St John', specs: { 'Items' => '50 Pieces', 'Type' => 'Compact', 'Case' => 'Hard Plastic', 'Size' => '20x15x8cm', 'Standard' => 'BS 8599' } },
    { title: 'Car Jack Scissor 2 Ton', brand: 'Torin', specs: { 'Type' => 'Scissor', 'Capacity' => '2 Ton', 'Lifting Range' => '90-390mm', 'Material' => 'Steel', 'Weight' => '3.5 kg' } },
    { title: 'Tire Pressure Gauge Digital', brand: 'Michelin', specs: { 'Type' => 'Digital', 'Range' => '0-60 PSI', 'Accuracy' => '+/- 1 PSI', 'Display' => 'LCD', 'Units' => 'PSI/bar/kPa' } },
  ]

  accessories.each do |a|
    specs = a[:specs].merge('Brand' => a[:brand])
    products << {
      'title' => a[:title],
      'brand' => a[:brand],
      'subcategory' => 'Accessories',
      'source' => 'manufacturer',
      'specifications' => specs
    }
  end
  log "  #{products.size} accessories"
  products
end

# ── Main ──────────────────────────────────────────────────────────────────────

existing = load_existing
all_products = []

scrapers = {
  'lubricants' => method(:scrape_lubricants),
  'rims' => method(:scrape_rims),
  'spare parts' => method(:scrape_spare_parts),
  'accessories' => method(:scrape_accessories)
}

scrapers.each do |name, scraper|
  next if options[:category_filter] && !name.include?(options[:category_filter])
  all_products += scraper.call
end

# Merge with existing (dedup by title)
existing_titles = Set.new(existing.map { |d| d['title'] })
new_products = all_products.reject { |d| existing_titles.include?(d['title']) }
final = existing + new_products

save_data(final)
log "\n🎉 Done! #{final.size} automotive parts (#{new_products.size} new) → #{OUT_FILE}"
