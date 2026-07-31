require 'json'

class DeviceCatalogService
  @cached_data = {}
  @last_mtimes = {}

  CATEGORY_FILES = {
    'computersphonesandaccessories' => {
      'phones' => 'phones_filtered.json',
      'tablets' => 'tablets_filtered.json',
      'ipads' => 'ipads_filtered.json',
      'smartwatches' => 'watches_filtered.json',
      'laptops' => 'laptops_filtered.json',
      'computers' => 'computers_filtered.json',
      'computers ' => 'computers_filtered.json',
      'peripherals' => 'computer_accessories_filtered.json',
      'storage' => 'computer_accessories_filtered.json',
      'networking equipment' => 'computer_accessories_filtered.json',
      'cooling & maintenance' => 'computer_accessories_filtered.json',
      'internal components' => 'computer_accessories_filtered.json',
      'accessories' => 'computer_accessories_filtered.json',
      'computer accessories' => 'computer_accessories_filtered.json',
      'computer spare parts' => 'computer_accessories_filtered.json'
    },
    'tvsandhomeentertainment' => {
      'smart tvs' => 'tvs_filtered.json',
      'led & lcd tvs' => 'tvs_filtered.json',
      'oled & qled tvs' => 'tvs_filtered.json',
      'home theater systems' => 'tv_audio_streaming_filtered.json',
      'soundbars & speakers' => 'tv_audio_streaming_filtered.json',
      'streaming devices' => 'tv_audio_streaming_filtered.json',
      'decoders & receivers' => 'tv_audio_streaming_filtered.json',
      'tv accessories' => 'tv_audio_streaming_filtered.json',
      'projectors & screens' => 'electronics_accessories_filtered.json',
      'projectors' => 'electronics_accessories_filtered.json'
    },
    'electronicsandaccessories' => {
      'printers' => 'electronics_accessories_filtered.json',
      'copiers' => 'electronics_accessories_filtered.json',
      'scanners' => 'electronics_accessories_filtered.json',
      'pos systems' => 'electronics_accessories_filtered.json',
      'shredders' => 'electronics_accessories_filtered.json',
      'projectors' => 'electronics_accessories_filtered.json'
    },
    'agriculture' => {
      'farm tools' => 'agriculture_filtered.json',
      'irrigation' => 'agriculture_filtered.json',
      'farm machinery' => 'agriculture_filtered.json',
      'spare parts' => 'agriculture_filtered.json',
      'agriculture spare parts' => 'agriculture_filtered.json',
      'accessories' => 'agriculture_filtered.json',
      'agriculture accessories' => 'agriculture_filtered.json'
    },
    'automotivepartsaccessories' => {
      'tyres' => 'automotive_filtered.json',
      'batteries' => 'automotive_filtered.json',
      'lubricants' => 'automotive_filtered.json',
      'rims' => 'automotive_filtered.json',
      'spare parts' => 'automotive_filtered.json',
      'automotive spare parts' => 'automotive_filtered.json',
      'accessories' => 'automotive_filtered.json',
      'automotive accessories' => 'automotive_filtered.json'
    },
    'filtration' => {
      'air filters' => 'filtration_filtered.json',
      'fuel filters' => 'filtration_filtered.json',
      'industrial filters' => 'filtration_filtered.json',
      'oil & hydraulic filters' => 'filtration_filtered.json'
    },
    'hardware' => {
      'safety wear' => 'hardware_tools_filtered.json',
      'hand & power tools' => 'hardware_tools_filtered.json',
      'power & electrical equipment' => 'hardware_tools_filtered.json',
      'plumbing supplies' => 'hardware_tools_filtered.json',
      'construction materials' => 'hardware_tools_filtered.json'
    }
  }.freeze

  def self.search(query, subcategory = 'phones', category = nil)
    data = load_data(category, subcategory)
    return [] if query.blank? || data.empty?
    
    normalized_query = query.to_s.downcase.strip
    
    if subcategory.present? && data.first && data.first.key?('subcategory')
      normalized_sub = subcategory.to_s.downcase.strip
      filtered_data = data.select { |p| p['subcategory'].to_s.downcase.strip == normalized_sub }
      data = filtered_data if filtered_data.any?
    end

    # Rank matches: exact title first, then starts with, then includes
    matches = data.select do |p|
      p['title'].to_s.downcase.include?(normalized_query) ||
      p['brand'].to_s.downcase.include?(normalized_query)
    end
    
    matches.sort_by do |p|
      title = p['title'].to_s.downcase
      score = 0
      score += 100 if title == normalized_query
      score += 50 if title.start_with?(normalized_query)
      score += 10 if title.include?(normalized_query)
      -score
    end.first(10)
  end

  def self.models_for_brand(brand, subcategory = 'phones', category = nil)
    data = load_data(category, subcategory)
    return [] if brand.blank? || data.empty?
    
    normalized_brand = brand.to_s.downcase.strip
    
    if subcategory.present? && data.first && data.first.key?('subcategory')
      normalized_sub = subcategory.to_s.downcase.strip
      filtered_data = data.select { |p| p['subcategory'].to_s.downcase.strip == normalized_sub }
      data = filtered_data if filtered_data.any?
    end
    
    data.select do |p|
      p['brand'].to_s.downcase == normalized_brand &&
        p['slug'].to_s.strip.length.positive?
    end
  end

  def self.find_by_slug(slug, subcategory = 'phones', category = nil)
    data = load_data(category, subcategory)
    data.find { |p| p['slug'] == slug }
  end

  def self.brands(subcategory = 'phones', category = nil)
    data = load_data(category, subcategory)
    
    # Filter by specific subcategory if present in the data (like Tyres vs Batteries)
    if subcategory.present? && data.first && data.first.key?('subcategory')
      normalized_sub = subcategory.to_s.downcase.strip
      filtered_data = data.select { |p| p['subcategory'].to_s.downcase.strip == normalized_sub }
      data = filtered_data if filtered_data.any?
    end
    
    data
      .map { |p| p['brand'] }
      .compact
      .uniq
      .sort
  end

  private

  def self.file_path_for(category, subcategory = 'phones')
    sub = (subcategory || 'phones').to_s.downcase.strip

    if category.present?
      cat_key = category.to_s.downcase.gsub(/[^a-z0-9]+/, '')
      filename = CATEGORY_FILES.dig(cat_key, sub)
      return Rails.root.join('scripts', 'output', filename) if filename
    end

    # Backward-compatible fallback for callers without a category
    filename = legacy_file_path_for(sub)
    filename ? Rails.root.join('scripts', 'output', filename) : nil
  end

  def self.legacy_file_path_for(subcategory)
    name = (subcategory || 'phones').to_s.downcase.strip

    case name
    # --- Phones/Tablets/Watches ---
    when 'phones' then 'phones_filtered.json'
    when 'tablets' then 'tablets_filtered.json'
    when 'ipads' then 'ipads_filtered.json'
    when 'smartwatches' then 'watches_filtered.json'
    # --- Computers/Laptops ---
    when 'laptops' then 'laptops_filtered.json'
    when 'computers', 'computers ' then 'computers_filtered.json'
    # --- TVs & Home Entertainment ---
    when 'smart tvs', 'led & lcd tvs', 'oled & qled tvs' then 'tvs_filtered.json'
    when 'home theater systems', 'soundbars & speakers',
         'streaming devices', 'decoders & receivers', 'tv accessories' then 'tv_audio_streaming_filtered.json'
    when 'projectors & screens', 'projectors' then 'electronics_accessories_filtered.json'
    # --- Electronics and Accessories ---
    when 'printers', 'copiers', 'scanners', 'pos systems',
         'shredders', 'others' then 'electronics_accessories_filtered.json'
    # --- Agriculture ---
    when 'farm tools', 'irrigation', 'farm machinery',
         'spare parts', 'accessories' then 'agriculture_filtered.json'
    # --- Computer Accessories ---
    when 'peripherals', 'storage', 'networking equipment',
         'cooling & maintenance', 'internal components',
         'computer accessories' then 'computer_accessories_filtered.json'
    # --- Automotive Parts & Accessories ---
    when 'tyres', 'batteries', 'lubricants', 'rims',
         'spare parts', 'accessories', 'others' then 'automotive_filtered.json'
    # --- Filtration ---
    when 'air filters', 'fuel filters', 'industrial filters',
         'oil & hydraulic filters' then 'filtration_filtered.json'
    # --- Hardware ---
    when 'safety wear', 'hand & power tools', 'power & electrical equipment',
         'plumbing supplies', 'construction materials' then 'hardware_tools_filtered.json'
    else nil
    end
  end

  def self.load_data(category, subcategory = 'phones')
    path = file_path_for(category, subcategory)
    return [] if path.nil? || !File.exist?(path)
    
    current_mtime = File.mtime(path)
    if @cached_data[path].nil? || @last_mtimes[path] != current_mtime
      begin
        @cached_data[path] = JSON.parse(File.read(path))
        @last_mtimes[path] = current_mtime
      rescue => e
        Rails.logger.error "DeviceCatalogService Error parsing #{path}: #{e.message}"
        @cached_data[path] = []
      end
    end
    @cached_data[path]
  end
end
