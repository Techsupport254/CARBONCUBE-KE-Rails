# frozen_string_literal: true

require "json"

DOCS_FILE = File.expand_path("../../docs/categories-and-subcategories.md", __dir__)
OUTPUT_DIR = File.expand_path("output", __dir__)
REPORT_PATH = "/tmp/all_catalogs_report.txt"

def file_for(subcategory)
  name = subcategory.to_s.downcase.strip

  case name
  when 'phones' then 'phones_filtered.json'
  when 'tablets' then 'tablets_filtered.json'
  when 'ipads' then 'ipads_filtered.json'
  when 'smartwatches' then 'watches_filtered.json'
  when 'laptops' then 'laptops_filtered.json'
  when 'computers', 'computers ' then 'computers_filtered.json'
  when 'smart tvs', 'led & lcd tvs', 'oled & qled tvs' then 'tvs_filtered.json'
  when 'home theater systems', 'soundbars & speakers',
       'streaming devices', 'decoders & receivers', 'tv accessories' then 'tv_audio_streaming_filtered.json'
  when 'projectors & screens', 'projectors' then 'electronics_accessories_filtered.json'
  when 'printers', 'copiers', 'scanners', 'pos systems',
       'shredders', 'others' then 'electronics_accessories_filtered.json'
  when 'farm tools', 'irrigation', 'farm machinery',
       'spare parts', 'accessories' then 'agriculture_filtered.json'
  when 'peripherals', 'storage', 'networking equipment',
       'cooling & maintenance', 'internal components',
       'computer accessories' then 'computer_accessories_filtered.json'
  when 'tyres', 'batteries', 'lubricants', 'rims',
       'spare parts', 'accessories', 'others' then 'automotive_filtered.json'
  when 'air filters', 'fuel filters', 'industrial filters',
       'oil & hydraulic filters' then 'filtration_filtered.json'
  when 'safety wear', 'hand & power tools', 'power & electrical equipment',
       'plumbing supplies', 'construction materials' then 'hardware_tools_filtered.json'
  else nil
  end
end

def load_data(filename)
  return nil if filename.nil?

  path = File.join(OUTPUT_DIR, filename)
  return nil unless File.exist?(path)

  JSON.parse(File.read(path))
rescue StandardError => e
  warn "Failed to read #{path}: #{e.message}"
  nil
end

def parse_categories
  categories = []
  current_category = nil

  File.readlines(DOCS_FILE).each do |line|
    if line =~ /^###\s+(?:\d+\.\s+)?(.+)$/ && !$1.include?("---")
      current_category = $1.strip
    elsif line =~ /^\s*-\s+(.+?)$/ && current_category
      subcategory = $1.strip
      categories << { category: current_category, subcategory: subcategory }
    end
  end

  categories
end

def analyze(category:, subcategory:)
  filename = file_for(subcategory)

  if filename.nil?
    return {
      file: "none",
      file_exists: false,
      products: 0,
      keys: [],
      with_slug: 0,
      with_brand: 0,
      with_subcategory: nil,
      usable_models: 0
    }
  end

  data = load_data(filename)

  if data.nil?
    return {
      file: filename,
      file_exists: false,
      products: 0,
      keys: [],
      with_slug: 0,
      with_brand: 0,
      with_subcategory: nil,
      usable_models: 0
    }
  end

  has_subcategory = data.first.is_a?(Hash) && data.first.key?("subcategory")
  name = subcategory.to_s.downcase.strip

  filtered = if has_subcategory
    data.select { |p| p["subcategory"].to_s.downcase.strip == name }
  else
    data
  end

  sample = filtered.first || data.first
  keys = sample.is_a?(Hash) ? sample.keys.sort : []

  {
    file: filename,
    file_exists: true,
    products: filtered.size,
    keys: keys,
    with_subcategory: has_subcategory,
    with_slug: filtered.count { |p| p["slug"].to_s.strip.length.positive? },
    with_brand: filtered.count { |p| p["brand"].to_s.strip.length.positive? },
    usable_models: filtered.count { |p| p["slug"].to_s.strip.length.positive? }
  }
end

categories = parse_categories

File.open(REPORT_PATH, "w") do |f|
  f.puts "| Category | Subcategory | File | Products | Usable models | Sample keys | Subcategory field? |"
  f.puts "|---|---|---|---|---|---|---|"

  with_catalog = 0
  without_catalog = 0

  categories.each do |entry|
    result = analyze(**entry)
    f.puts "| #{entry[:category]} | #{entry[:subcategory]} | #{result[:file]} | #{result[:products]} | #{result[:usable_models]} | #{result[:keys].join(', ')} | #{result[:with_subcategory].nil? ? 'N/A' : result[:with_subcategory]} |"
    result[:usable_models].positive? ? with_catalog += 1 : without_catalog += 1
  end

  f.puts ""
  f.puts "Summary: #{with_catalog} subcategories have usable external-catalog models, #{without_catalog} do not."
end

puts "Report written to #{REPORT_PATH}"
puts "#{categories.size} categories/subcategories checked."
