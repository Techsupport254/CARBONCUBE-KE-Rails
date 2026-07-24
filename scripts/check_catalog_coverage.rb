# frozen_string_literal: true

require "json"

OUTPUT_DIR = File.expand_path("output", __dir__)

CATALOG_MAP = [
  { category: "Phones/Tablets/Watches", subcategories: %w[phones], file: "phones_filtered.json" },
  { category: "Phones/Tablets/Watches", subcategories: %w[tablets], file: "tablets_filtered.json" },
  { category: "Phones/Tablets/Watches", subcategories: %w[ipads], file: "ipads_filtered.json" },
  { category: "Phones/Tablets/Watches", subcategories: %w[smartwatches], file: "watches_filtered.json" },
  { category: "Computers/Laptops", subcategories: %w[laptops], file: "laptops_filtered.json" },
  { category: "Computers/Laptops", subcategories: %w[computers], file: "computers_filtered.json" },
  { category: "TVs & Home Entertainment", subcategories: %w[smart\ tvs led\ &\ lcd\ tvs oled\ &\ qled\ tvs], file: "tvs_filtered.json" },
  { category: "TVs & Home Entertainment", subcategories: %w[home\ theater\ systems soundbars\ &\ speakers streaming\ devices decoders\ &\ receivers tv\ accessories], file: "tv_audio_streaming_filtered.json" },
  { category: "TVs & Home Entertainment", subcategories: %w[projectors\ &\ screens projectors], file: "electronics_accessories_filtered.json" },
  { category: "Electronics and Accessories", subcategories: %w[printers copiers scanners pos\ systems shredders others], file: "electronics_accessories_filtered.json" },
  { category: "Agriculture", subcategories: %w[farm\ tools irrigation farm\ machinery spare\ parts accessories], file: "agriculture_filtered.json" },
  { category: "Computer Accessories", subcategories: %w[peripherals storage networking\ equipment cooling\ &\ maintenance internal\ components computer\ accessories], file: "computer_accessories_filtered.json" },
  { category: "Automotive Parts & Accessories", subcategories: %w[tyres batteries lubricants rims spare\ parts accessories others], file: "automotive_filtered.json" },
  { category: "Filtration", subcategories: %w[air\ filters fuel\ filters industrial\ filters oil\ &\ hydraulic\ filters], file: "filtration_filtered.json" },
  { category: "Hardware", subcategories: %w[safety\ wear hand\ &\ power\ tools power\ &\ electrical\ equipment plumbing\ supplies construction\ materials], file: "hardware_tools_filtered.json" }
].freeze

def load_data(path)
  return nil unless File.exist?(path)

  JSON.parse(File.read(path))
rescue StandardError => e
  warn "Failed to read #{path}: #{e.message}"
  nil
end

def filter_by_subcategory(data, subcategory)
  return data if data.nil? || data.empty?
  return data unless data.first.is_a?(Hash) && data.first.key?("subcategory")

  data.select { |p| p["subcategory"].to_s.downcase.strip == subcategory }
end

def usable_model?(item)
  item["slug"].to_s.strip.length.positive?
end

problematic = []
puts "| Category | Subcategory | File | Products | With slug | Brands | Has usable models? |"
puts "|---|---|---|---|---|---|---|---|"

CATALOG_MAP.each do |entry|
  path = File.join(OUTPUT_DIR, entry[:file])
  all_data = load_data(path)

  entry[:subcategories].each do |sub|
    sub_key = sub.delete("\\")
    data = all_data ? filter_by_subcategory(all_data, sub_key) : nil

    if data.nil?
      puts "| #{entry[:category]} | #{sub_key} | #{entry[:file]} | FILE MISSING | - | - | - | - |"
      next
    end

    total = data.size
    with_slug = data.count { |p| usable_model?(p) }
    brand_groups = data.group_by { |p| p["brand"].to_s.strip }.reject { |b, _| b.empty? }
    brands = brand_groups.keys.sort

    zero_brands = 0
    usable_brand_count = 0
    zero_brand_names = []

    brands.each do |brand|
      usable = brand_groups[brand].any? { |p| usable_model?(p) }
      if usable
        usable_brand_count += 1
      else
        zero_brands += 1
        zero_brand_names << brand
      end
    end

    has_models = usable_brand_count.positive?
    flag = has_models ? "YES" : "NO"

    row = "| #{entry[:category]} | #{sub_key} | #{entry[:file]} | #{total} | #{with_slug} | #{brands.size} | #{flag} |"
    puts row

    problematic << { category: entry[:category], subcategory: sub_key, file: entry[:file], total: total, brands: brands.size, zero_brands: zero_brand_names } unless zero_brand_names.empty?
  end
end

puts "\nSubcategories where brand dropdowns would show but NO usable model data:"
puts "---------------------------------------------------------------------"
problematic.each do |p|
  puts "Category: #{p[:category]} | Subcategory: #{p[:subcategory]}"
  puts "  File: #{p[:file]} | Products: #{p[:total]} | Brands: #{p[:brands]} | Zero-model brands: #{p[:zero_brands].join(', ')}"
  puts ""
end
