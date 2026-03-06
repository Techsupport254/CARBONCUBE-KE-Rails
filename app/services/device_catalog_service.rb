require 'json'

class DeviceCatalogService
  @cached_data = {}
  @last_mtimes = {}

  def self.search(query, subcategory = 'phones')
    data = load_data(subcategory)
    return [] if query.blank? || data.empty?
    
    normalized_query = query.to_s.downcase.strip
    
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

  def self.models_for_brand(brand, subcategory = 'phones')
    data = load_data(subcategory)
    return [] if brand.blank? || data.empty?
    
    normalized_brand = brand.to_s.downcase.strip
    
    data.select do |p|
      p['brand'].to_s.downcase == normalized_brand
    end
  end

  def self.find_by_slug(slug, subcategory = 'phones')
    data = load_data(subcategory)
    data.find { |p| p['slug'] == slug }
  end

  def self.brands(subcategory = 'phones')
    data = load_data(subcategory)
    data.map { |p| p['brand'] }.compact.uniq.sort
  end

  private

  def self.file_path_for(subcategory)
    # Default to phones if no subcategory is given
    name = (subcategory || 'phones').to_s.downcase.strip

    # Map subcategory to specific file
    filename = case name
               when 'tablets' then 'tablets_filtered.json'
               when 'ipads' then 'ipads_filtered.json'
               when 'laptops' then 'laptops_filtered.json'
               when 'tvs', 'televisions', 'tvs & home entertainment' then 'tvs_filtered.json'
               when 'watches', 'smartwatches' then 'watches_filtered.json'
               when 'phones' then 'phones_filtered.json'
               else 'phones_filtered.json' # Default to the filtered phones list instead of raw unstructured data
               end

    Rails.root.join('scripts', 'output', filename)
  end

  def self.load_data(subcategory)
    path = file_path_for(subcategory)
    return [] unless File.exist?(path)
    
    current_mtime = File.mtime(path)
    if @cached_data[path].nil? || @last_mtimes[path] != current_mtime
      begin
        @cached_data[path] = JSON.parse(File.read(path))
        @last_mtimes[path] = current_mtime
        Rails.logger.info "DeviceCatalogService: Loaded #{@cached_data[path].length} items from #{path}."
      rescue => e
        Rails.logger.error "DeviceCatalogService Error parsing #{path}: #{e.message}"
        @cached_data[path] = []
      end
    end
    @cached_data[path]
  end
end
