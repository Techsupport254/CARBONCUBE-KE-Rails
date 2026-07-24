#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# Electronics & Accessories Scraper
# =============================================================================
# Scrapes full specifications from server-rendered spec sites:
#
#   Projectors  → ProjectorCentral.com (spec sheets with dd/dt pairs)
#   Printers    → Brother-usa.com (embedded JSON product data)
#
# For subcategories without a dedicated spec site (Copiers, Scanners, POS,
# Shredders), we generate structured generic entries with known brands and
# relevant spec fields.
#
# Output: scripts/output/electronics_accessories.json
#
# Usage:
#   ruby scripts/scrape_electronics_accessories.rb
#   ruby scripts/scrape_electronics_accessories.rb --category projectors
#   ruby scripts/scrape_electronics_accessories.rb --limit 30
#   ruby scripts/scrape_electronics_accessories.rb --reset
# =============================================================================

require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'
require 'fileutils'
require 'optparse'
require 'set'

OUTPUT_DIR = File.expand_path('output', __dir__)
OUT_FILE   = File.join(OUTPUT_DIR, 'electronics_accessories.json')
CKP_FILE   = File.join(OUTPUT_DIR, 'checkpoint_electronics.json')
LOG_FILE   = File.join(OUTPUT_DIR, 'scrape_electronics.log')

MIN_DELAY = 1.0
MAX_DELAY = 2.5

USER_AGENTS = [
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15'
].freeze

options = { category_filter: nil, limit: nil, reset: false }
OptionParser.new do |opts|
  opts.on('--category NAME', 'Scrape only this subcategory') { |v| options[:category_filter] = v.downcase }
  opts.on('--limit N', Integer, 'Max items per source')      { |v| options[:limit] = v }
  opts.on('--reset', 'Delete checkpoint and start fresh')     { options[:reset] = true }
end.parse!

FileUtils.mkdir_p(OUTPUT_DIR)

if options[:reset]
  File.delete(OUT_FILE) if File.exist?(OUT_FILE)
  File.delete(CKP_FILE) if File.exist?(CKP_FILE)
  puts "Reset: cleared output and checkpoint files"
end

def log(msg)
  line = "[#{Time.now.strftime('%H:%M:%S')}] #{msg}"
  puts line
  File.open(LOG_FILE, 'a') { |f| f.puts(line) }
end

def fetch_html(url, retries: 3)
  uri = URI(url)
  attempt = 0
  begin
    attempt += 1
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 15
    http.open_timeout = 10

    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = USER_AGENTS.sample
    request['Accept'] = 'text/html,application/xhtml+xml'
    request['Accept-Language'] = 'en-US,en;q=0.9'

    response = http.request(request)
    if response.code == '200'
      return Nokogiri::HTML(response.body)
    else
      log "  HTTP #{response.code} for #{url}"
      raise "Non-success"
    end
  rescue => e
    if attempt < retries
      sleep(3 * attempt)
      retry
    end
    log "  Failed to fetch #{url}: #{e.message}"
    nil
  end
end

def fetch_raw(url, retries: 3)
  uri = URI(url)
  attempt = 0
  begin
    attempt += 1
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 15
    http.open_timeout = 10

    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = USER_AGENTS.sample
    request['Accept'] = 'text/html,application/xhtml+xml'
    request['Accept-Language'] = 'en-US,en;q=0.9'

    response = http.request(request)
    if response.code == '200'
      return response.body
    else
      log "  HTTP #{response.code} for #{url}"
      raise "Non-success"
    end
  rescue => e
    if attempt < retries
      sleep(3 * attempt)
      retry
    end
    log "  Failed to fetch #{url}: #{e.message}"
    nil
  end
end

# ── ProjectorCentral scraper ─────────────────────────────────────────────────

# Brand pages on ProjectorCentral
PROJECTOR_BRANDS = [
  { name: 'Epson',      page: 'epson-projectors.htm' },
  { name: 'BenQ',       page: 'benq-projectors.htm' },
  { name: 'Optoma',     page: 'optoma-projectors.htm' },
  { name: 'ViewSonic',  page: 'viewsonic-projectors.htm' },
  { name: 'Sony',       page: 'sony-projectors.htm' },
  { name: 'Panasonic',  page: 'panasonic-projectors.htm' },
  { name: 'NEC',        page: 'nec-projectors.htm' },
  { name: 'LG',         page: 'lg-projectors.htm' },
].freeze

def scrape_projector_brand_page(brand_name, page_slug, limit = nil)
  url = "https://www.projectorcentral.com/#{page_slug}"
  log "  Fetching brand page: #{url}"
  doc = fetch_html(url)
  return [] unless doc

  models = []
  doc.css('a').each do |a|
    href = a['href'].to_s
    # Only accept absolute paths starting with / and ending in .htm
    # Exclude nav pages, reviews, calculators, prices, etc.
    next unless href.start_with?('/') && href.end_with?('.htm')
    next if href.match?(/projectors\.htm$|\.cfm$|review\.htm$|prices\.htm$|calculator\.htm$|best-|award|new-|buyers|guide|podcast|blog|news|article|movie|lamp|mount|screen|lens|dealer|login|about|contact|privacy|copyright|user-reviews|projection-calculator/i)
    # Must look like a spec page: /brand-model_name.htm (contains a dash after brand)
    next unless href.match?(%r{^/[a-z]+-[a-z0-9_]+\.htm$}i)

    title = a.text.strip
    next if title.empty? || title.size < 3
    # Skip nav labels
    next if title.match?(/^(Home Theater|Ultra Short Throw|Portable|Large Venue|Education|Interactive|Conference|Accessory|Pocket|Throw|Lamp|Screen|Mount|Review|Price|Calculator)/i)

    full_url = "https://www.projectorcentral.com#{href}"
    models << { url: full_url, title: title }
  end

  seen = Set.new
  models = models.select { |m| seen.add?(m[:url]) }
  models = models.first(limit) if limit

  log "  Found #{models.size} projector models for #{brand_name}"
  models
end

def scrape_projector_spec_page(url, brand_name)
  doc = fetch_html(url)
  return nil unless doc

  # Extract title
  title_el = doc.at_css('h1') || doc.css('h2').first
  title = title_el ? title_el.text.strip : url.split('/').last.gsub('.htm', '').gsub('_', ' ')

  specs = {}

  # Parse dd/dt pairs from definition lists
  # ProjectorCentral uses a mix: some dl blocks have dt=label/dd=value (meta info)
  # and others have dd=label/dt=value (technical specs)
  doc.css('dl').each do |dl|
    children = dl.css('dt, dd')
    # Try both orderings — detect which one has the label first
    # If dt comes before dd in the children array, it's dt=label
    # If dd comes before dt, it's dd=label
    i = 0
    while i < children.size
      el = children[i]
      next_el = children[i + 1]
      break unless next_el

      if el.name == 'dt' && next_el.name == 'dd'
        # Standard: dt=label, dd=value
        label = el.text.strip
        val = next_el.text.strip
        i += 2
      elsif el.name == 'dd' && next_el.name == 'dt'
        # Reversed: dd=label, dt=value
        label = el.text.strip
        val = next_el.text.strip
        i += 2
      else
        i += 1
        next
      end

      next if label.empty? || val.empty?
      val = val.gsub(/\s+/, ' ').strip
      label = label.gsub(/\s+/, ' ').strip
      specs[label] = val
    end
  end

  # Also parse table rows
  doc.css('table tr').each do |tr|
    tds = tr.css('td')
    if tds.size == 2
      label = tds[0].text.strip
      val = tds[1].text.strip
      next if label.empty? || val.empty?
      val = val.gsub(/\s+/, ' ').strip
      specs[label] = val unless specs.key?(label)
    end
  end

  # Map ProjectorCentral spec keys to our standardized keys
  mapped = {}

  # Brightness
  mapped['Brightness (Lumens)'] = specs['White Brightness'] if specs['White Brightness']
  mapped['Color Brightness (Lumens)'] = specs['Color Brightness'] if specs['Color Brightness']

  # Resolution
  mapped['Resolution'] = specs['Resolution'] if specs['Resolution']
  mapped['Aspect Ratio'] = specs['Aspect Ratio'] if specs['Aspect Ratio']

  # Display
  mapped['Display Type'] = specs['Display Type'] if specs['Display Type']
  mapped['Chip Type'] = specs['Chip Type'] if specs['Chip Type']

  # Light source
  mapped['Light Source'] = specs['Light Source'] if specs['Light Source']
  mapped['Lamp Type'] = specs['Lamp Type'] if specs['Lamp Type']
  mapped['Lamp Life'] = specs['Lamp Life'] if specs['Lamp Life']

  # Throw
  mapped['Throw Ratio'] = specs['Throw Ratio'] if specs['Throw Ratio']
  mapped['Throw Distance'] = specs['Throw Distance'] if specs['Throw Distance']

  # Contrast
  mapped['Contrast Ratio'] = specs['Contrast Ratio'] if specs['Contrast Ratio']
  mapped['Dynamic Iris'] = specs['Dynamic Iris'] if specs['Dynamic Iris']

  # Connectivity
  mapped['HDMI'] = specs['HDMI'] if specs['HDMI']
  mapped['Inputs'] = specs['Inputs'] if specs['Inputs']
  mapped['Outputs'] = specs['Outputs'] if specs['Outputs']

  # Physical
  mapped['Weight'] = specs['Weight'] if specs['Weight']
  mapped['Dimensions'] = specs['Dimensions'] if specs['Dimensions']
  mapped['Audible Noise'] = specs['Audible Noise'] if specs['Audible Noise']

  # Features
  mapped['3D'] = specs['3D'] if specs['3D']
  mapped['Color Processing'] = specs['Color Processing'] if specs['Color Processing']
  mapped['Dynamic Iris'] = specs['Dynamic Iris'] if specs['Dynamic Iris']

  # Meta
  mapped['Status'] = specs['Status'] if specs['Status']
  mapped['Released'] = specs['Released'] if specs['Released']
  mapped['Warranty'] = specs['Warranty'] if specs['Warranty']
  mapped['MSRP'] = specs['MSRP'] if specs['MSRP']
  mapped['Best Used For'] = specs['Best Used For'] if specs['Best Used For']

  mapped.reject { |_, v| v.nil? || v.to_s.strip.empty? }

  {
    'title' => "#{brand_name} #{title.gsub(/^#{Regexp.escape(brand_name)}\s*/i, '')}",
    'brand' => brand_name,
    'subcategory' => 'projectors',
    'specifications' => mapped,
    'projectorcentral_url' => url,
    'source' => 'projectorcentral.com'
  }
end

# ── Brother printer scraper (embedded JSON product data) ─────────────────────

def scrape_brother_printers(limit = nil)
  url = 'https://www.brother-usa.com/c/shop/printers'
  log "  Fetching Brother printer catalog: #{url}"
  raw = fetch_raw(url)
  return [] unless raw

  # Brother embeds product data as JSON in the HTML: "productId":"XYZ","productName":"..."
  products = []
  raw.scan(/"productId":"([^"]+)".*?"productName":"([^"]+)"/).each do |pid, pname|
    products << { id: pid, name: pname }
  end

  # Deduplicate
  seen = Set.new
  products = products.select { |p| seen.add?(p[:id]) }
  products = products.first(limit) if limit

  log "  Found #{products.size} Brother printers"

  results = []
  products.each_with_index do |p, idx|
    log "  [#{idx + 1}/#{products.size}] #{p[:name]}"

    # Try to fetch the product spec page
    spec_url = "https://www.brother-usa.com/products/#{p[:id].downcase}"
    sleep(rand(MIN_DELAY..MAX_DELAY))
    doc = fetch_html(spec_url)

    specs = { 'Brand' => 'Brother', 'Model' => p[:id] }

    if doc
      # Try to extract specs from the page
      # Brother pages may have spec tables
      doc.css('table tr').each do |tr|
        tds = tr.css('td')
        if tds.size == 2
          label = tds[0].text.strip
          val = tds[1].text.strip.gsub(/\s+/, ' ')
          next if label.empty? || val.empty?
          specs[label] = val
        end
      end

      # Also look for spec lists
      doc.css('.spec-table tr, .specs tr, .product-specs tr').each do |tr|
        tds = tr.css('td, th')
        if tds.size == 2
          label = tds[0].text.strip
          val = tds[1].text.strip.gsub(/\s+/, ' ')
          next if label.empty? || val.empty?
          specs[label] = val
        end
      end

      # Try to extract from JSON-LD or embedded data
      doc.css('script[type="application/ld+json"]').each do |script|
        begin
          data = JSON.parse(script.text)
          if data.is_a?(Hash)
            specs['Description'] = data['description'] if data['description']
            specs['Category'] = data['category'] if data['category']
          end
        rescue
          # ignore parse errors
        end
      end
    end

    # Parse key specs from the product name
    name_lower = p[:name].downcase
    specs['Print Technology'] = if name_lower.include?('inkjet')
                                  'Inkjet'
                                elsif name_lower.include?('laser') && name_lower.include?('color')
                                  'Color Laser'
                                elsif name_lower.include?('laser')
                                  'Monochrome Laser'
                                end
    specs['Function'] = if name_lower.include?('all-in-one') || name_lower.include?('multifunction')
                          'All-in-One (Print, Scan, Copy, Fax)'
                        else
                          'Printer Only'
                        end
    specs['Connectivity'] = 'Wi-Fi' if name_lower.include?('wireless') || name_lower.include?('wi-fi')

    results << {
      'title' => p[:name],
      'brand' => 'Brother',
      'subcategory' => 'printers',
      'specifications' => specs,
      'source' => 'brother-usa.com'
    }
  end

  results
end

# ── Generic entries for subcategories without spec sites ─────────────────────

def singularize(word)
  word = word.to_s
  if word.end_with?('ies')
    word[0..-4] + 'y'
  elsif word.end_with?('es')
    word[0..-3]
  elsif word.end_with?('s')
    word[0..-2]
  else
    word
  end
end

def build_generic_entry(brand, subcategory, spec_overrides = {})
  specs = {
    'Brand' => brand,
    'Type' => singularize(subcategory).capitalize
  }.merge(spec_overrides)
  {
    'title' => "#{brand} #{singularize(subcategory)}",
    'brand' => brand,
    'subcategory' => subcategory,
    'specifications' => specs,
    'source' => 'generic'
  }
end

# Known brands for each subcategory
PRINTER_BRANDS = %w[HP Canon Epson Brother Lexmark Samsung Xerox Ricoh Dell]
COPIER_BRANDS = %w[Canon Xerox Ricoh Sharp Konica Toshiba]
SCANNER_BRANDS = %w[Canon Epson HP Fujitsu Brother Plustek]
POS_BRANDS = %w[Square Clover Toshiba NCR HP Epson Star]
SHREDDER_BRANDS = %w[Fellowes AmazonBasics Swingline Aurora Bonsaii]

# ── Main ──────────────────────────────────────────────────────────────────────

def load_json(path, default = [])
  File.exist?(path) ? (JSON.parse(File.read(path)) rescue default) : default
end

def save_json(path, data)
  File.write(path, JSON.pretty_generate(data))
end

all_results = load_json(OUT_FILE, [])
checkpoint  = load_json(CKP_FILE, { 'done_categories' => [] })
done_cats   = checkpoint['done_categories']

limit = options[:limit]
cat_filter = options[:category_filter]

# ── 1. Scrape projectors from ProjectorCentral ──────────────────────────────
if !cat_filter || cat_filter == 'projectors'
  if done_cats.include?('projectors')
    log "Skipping projectors (already done)"
  else
    log "\n=== Scraping Projectors from ProjectorCentral.com ==="

    projector_results = []
    PROJECTOR_BRANDS.each do |brand|
      log "\n--- #{brand[:name]} ---"
      models = scrape_projector_brand_page(brand[:name], brand[:page], limit)

      models.each_with_index do |model, idx|
        log "  [#{idx + 1}/#{models.size}] #{model[:title]}"
        sleep(rand(MIN_DELAY..MAX_DELAY))

        result = scrape_projector_spec_page(model[:url], brand[:name])
        if result && result['specifications']&.any?
          projector_results << result
          log "    OK — #{result['specifications'].size} specs extracted"
        else
          log "    SKIP — no specs found"
        end
      end

      log "  Cooling down 5s..."
      sleep(5)
    end

    if projector_results.any?
      all_results.concat(projector_results)
      done_cats << 'projectors'
      log "\n  Projectors done — #{projector_results.size} items"
    end
  end
end

# ── 2. Scrape printers from Brother ──────────────────────────────────────────
if !cat_filter || cat_filter == 'printers'
  if done_cats.include?('printers')
    log "Skipping printers (already done)"
  else
    log "\n=== Scraping Printers from Brother-usa.com ==="
    printer_results = scrape_brother_printers(limit)

    # Add generic entries for other printer brands
    PRINTER_BRANDS.each do |brand|
      next if brand == 'Brother'
      printer_results << build_generic_entry(brand, 'printers', {
        'Print Technology' => 'Inkjet, Laser',
        'Function' => 'Printer / All-in-One',
        'Connectivity' => 'USB, Wi-Fi, Ethernet'
      })
    end

    if printer_results.any?
      all_results.concat(printer_results)
      done_cats << 'printers'
      log "  Printers done — #{printer_results.size} items"
    end
  end
end

# ── 3. Generic entries for remaining subcategories ───────────────────────────
if !cat_filter || cat_filter == 'copiers'
  log "\n=== Adding generic Copier entries ==="
  COPIER_BRANDS.each do |brand|
    all_results << build_generic_entry(brand, 'copiers', {
      'Copy Speed (cpm)' => '',
      'Paper Size' => 'A4, A3',
      'Duplex Copying' => 'Yes / No',
      'Connectivity' => 'USB, Network'
    })
  end
end

if !cat_filter || cat_filter == 'scanners'
  log "\n=== Adding generic Scanner entries ==="
  SCANNER_BRANDS.each do |brand|
    all_results << build_generic_entry(brand, 'scanners', {
      'Scanner Type' => 'Flatbed, Sheet-fed',
      'Resolution (dpi)' => '',
      'Scan Speed' => '',
      'Connectivity' => 'USB, Wi-Fi'
    })
  end
end

if !cat_filter || cat_filter == 'pos systems'
  log "\n=== Adding generic POS System entries ==="
  POS_BRANDS.each do |brand|
    all_results << build_generic_entry(brand, 'pos systems', {
      'System Type' => 'All-in-one, Tablet-based',
      'Display Size' => '',
      'Connectivity' => 'Wi-Fi, Bluetooth, Ethernet',
      'Payment Methods' => 'Card, Cash, Mobile Money'
    })
  end
end

if !cat_filter || cat_filter == 'shredders'
  log "\n=== Adding generic Shredder entries ==="
  SHREDDER_BRANDS.each do |brand|
    all_results << build_generic_entry(brand, 'shredders', {
      'Sheet Capacity' => '',
      'Cut Type' => 'Strip-cut, Cross-cut, Micro-cut',
      'Security Level' => '',
      'Bin Capacity (Litres)' => ''
    })
  end
end

# ── Save ─────────────────────────────────────────────────────────────────────

# Deduplicate by title
seen = Set.new
all_results = all_results.select do |r|
  key = r['title'].to_s.downcase
  seen.add?(key)
end

save_json(OUT_FILE, all_results)
save_json(CKP_FILE, 'done_categories' => done_cats)

log "\n=== Done! ==="
log "Total items: #{all_results.size}"
log "Subcategories: #{all_results.group_by { |d| d['subcategory'] }.transform_values(&:size).inspect}"
log "Sources: #{all_results.group_by { |d| d['source'] }.transform_values(&:size).inspect}"
log "Output: #{OUT_FILE}"
