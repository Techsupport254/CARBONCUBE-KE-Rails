# frozen_string_literal: true

require_relative '../config/environment'

CATEGORY_DISPLAY_NAMES = {
  'computersphonesandaccessories' => 'Computers, Phones and Accessories',
  'tvsandhomeentertainment' => 'TVs & Home Entertainment',
  'electronicsandaccessories' => 'Electronics and Accessories',
  'agriculture' => 'Agriculture',
  'automotivepartsaccessories' => 'Automotive Parts & Accessories',
  'filtration' => 'Filtration',
  'hardware' => 'Hardware'
}.freeze

OUTPUT_FILE = '/Users/user/Desktop/work/docs/catalog_zero_model_samples.md'

def sample_for(category_name, subcategory)
  data = DeviceCatalogService.send(:load_data, category_name, subcategory)
  return nil if data.nil? || data.empty?

  if data.first.key?('subcategory')
    data = data.select { |p| p['subcategory'].to_s.downcase.strip == subcategory.to_s.downcase.strip }
  end

  # Pick a representative record with no usable slug
  sample = data.find { |p| p['slug'].to_s.strip.empty? }
  sample || data.first
end

sections = ["# Sample Catalog Records for Subcategories with Zero Usable Models\n"]

count = 0
DeviceCatalogService::CATEGORY_FILES.each do |cat_key, subcats|
  category_name = CATEGORY_DISPLAY_NAMES[cat_key] || cat_key
  category_sections = []

  subcats.each do |subcategory, filename|
    next unless filename

    data = DeviceCatalogService.send(:load_data, category_name, subcategory)
    next if data.nil? || data.empty?

    if data.first.key?('subcategory')
      sub_data = data.select { |p| p['subcategory'].to_s.downcase.strip == subcategory.to_s.downcase.strip }
      data = sub_data if sub_data.any?
    end

    total = data.length
    usable = data.count { |p| p['slug'].to_s.strip.length.positive? }
    next unless total > 0 && usable == 0

    sample = data.find { |p| p['slug'].to_s.strip.empty? } || data.first
    count += 1

    category_sections << "### #{subcategory.titleize}"
    category_sections << ""
    category_sections << "- **Catalog file**: `#{filename}`"
    category_sections << "- **Total records**: #{total}"
    category_sections << "- **Usable models**: #{usable}"
    category_sections << "- **Sample record**:"
    category_sections << "```json"
    category_sections << JSON.pretty_generate(sample)
    category_sections << "```"
    category_sections << ""
  end

  next if category_sections.empty?

  sections << "## #{category_name}"
  sections.concat(category_sections)
end

File.write(OUTPUT_FILE, sections.join("\n"))
puts "Wrote #{OUTPUT_FILE} with #{count} sample records."
