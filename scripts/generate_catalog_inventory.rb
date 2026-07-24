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

SERVICE_SUBCATEGORIES = %w[
  Computer\ Repairs Equipment\ Leasing Mechanics Electrician Plumber Appliance\ Specialist
  Electronics\ Specialist Welder Mason Painter Carpenter Industrial\ Machinery\ Specialist
  Borehole\ Specialist Phone\ Repairs
].freeze

SERVICE_PRICING_OPTIONS = 'Hourly Rate, Daily Rate, Fixed Fee, Starting From, Quote on Request'.freeze

OUTPUT_FILE = '/Users/user/Desktop/work/docs/catalog_inventory.md'

NOTABLE_SPEC_KEYS = %w[
  Internal Storage Ram Battery Display Screen Size Resolution Processor
  Operating System Camera Front Camera Rear Camera Network SIM Card Type
  Weight Dimensions Color Condition source
].freeze

def pricing_structure_for(category_key, _subcategory)
  return SERVICE_PRICING_OPTIONS if category_key.to_s.downcase == 'services'
  # All subcategories with external catalog data are physical products, so Fixed Fee is correct.
  # Sellers can still mark the ad as Negotiable through the specifications.
  'Fixed Fee (default for physical products; negotiable option available)'
end

def price_for_subcategory(category_name, _subcategory, sample_title)
  category = Category.find_by('LOWER(name) = ?', category_name.to_s.downcase)
  return 'Price on Request' unless category

  result = WhatsappAiPrefillService.get_price_suggestions(sample_title, category.id)
  recommended = result[:recommended]
  return 'Price on Request' unless recommended.present? && recommended.to_f > 0

  amount = recommended.to_f.round
  "Ksh #{amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
rescue => e
  'Price on Request'
end

def usable_models_for(category_name, subcategory)
  data = DeviceCatalogService.send(:load_data, category_name, subcategory)
  return [] if data.nil? || data.empty?

  # Filter by the subcategory field when the file contains multiple subcategories
  if data.first.key?('subcategory')
    filtered = data.select { |p| p['subcategory'].to_s.downcase.strip == subcategory.to_s.downcase.strip }
    data = filtered if filtered.any?
  end

  data.select { |p| p['slug'].to_s.strip.length.positive? }
end

def spec_keys_for(data)
  data.flat_map { |p| p['specifications']&.keys || [] }.uniq.sort
end

def notable_specs(specs)
  return {} unless specs.is_a?(Hash)

  keys = NOTABLE_SPEC_KEYS & specs.keys
  keys.each_with_object({}) { |k, h| h[k] = specs[k] }
end

def markdown_for_subcategory(category_name, subcategory, models)
  return nil if models.empty?

  file_path = DeviceCatalogService.file_path_for(category_name, subcategory)
  file_name = file_path ? file_path.basename.to_s : 'N/A'

  lines = []
  lines << "### #{subcategory.titleize}"
  lines << ""
  lines << "- **Catalog file**: `#{file_name}`"
  lines << "- **Usable models**: #{models.length}"
  lines << "- **Pricing structure**: #{pricing_structure_for(category_name, subcategory)}"
  sample = models.first
  price = sample ? price_for_subcategory(category_name, subcategory, sample['title']) : 'Price on Request'
  lines << "- **Price (description)**: #{price}"
  lines << "- **Negotiable**: [ ]"
  lines << ""

  brands = models.map { |p| p['brand'] }.compact.uniq.sort
  all_spec_keys = spec_keys_for(models)
  samples = models.first(3)

  lines << "- **Brands**: #{brands.first(10).join(', ')}#{brands.length > 10 ? ', …' : ''}"
  lines << "- **Specification fields observed**: #{all_spec_keys.any? ? all_spec_keys.join(', ') : 'None'}"
  lines << ""
  lines << "- **Sample models**:"

  samples.each do |model|
    lines << "  - **#{model['title']}** (#{model['brand']}) — slug: `#{model['slug']}`"
    notable = notable_specs(model['specifications'])
    if notable.any?
      lines << "    - Notable specs:"
      notable.each { |k, v| lines << "      - #{k}: #{v}" }
    end
    if (model['specifications'] || {}).keys.length > notable.length
      remaining = (model['specifications'].keys - NOTABLE_SPEC_KEYS).first(5)
      lines << "    - Other spec keys: #{remaining.join(', ')}#{model['specifications'].keys.length - notable.length > 5 ? ', …' : ''}"
    end
  end

  lines << ""
  lines.join("\n")
end

def service_markdown(subcategory)
  lines = []
  lines << "### #{subcategory.titleize}"
  lines << ""
  lines << "- **Pricing structure**: #{SERVICE_PRICING_OPTIONS}"
  lines << "- **Price (description)**: Flexible (Hourly / Daily / Fixed / Starting From / Quote on Request)"
  lines << "- **Negotiable**: [ ]"
  lines << ""
  lines.join("\n")
end

# Monkey-patch String#titleize if ActiveSupport is not loaded
class String
  def titleize
    split.map(&:capitalize).join(' ')
  end
end unless String.method_defined?(:titleize)

sections = []
DeviceCatalogService::CATEGORY_FILES.each do |cat_key, subcats|
  category_name = CATEGORY_DISPLAY_NAMES[cat_key] || cat_key
  sub_sections = []

  subcats.each do |subcategory, filename|
    next unless filename # skip entries intentionally mapped to nil (e.g. services/others)

    models = usable_models_for(category_name, subcategory)
    sub_sections << markdown_for_subcategory(category_name, subcategory, models)
  end

  sub_sections.compact!
  next if sub_sections.empty?

  sections << "## #{category_name}"
  sections.concat(sub_sections)
end

sections << "## Services"
SERVICE_SUBCATEGORIES.each { |sub| sections << service_markdown(sub) }

File.write(OUTPUT_FILE, "# External Catalog Inventory\n\n" + sections.join("\n"))
puts "Wrote #{OUTPUT_FILE} with #{sections.count { |s| s.start_with?('## ') }} categories and #{sections.count { |s| s.start_with?('### ') }} subcategories."
