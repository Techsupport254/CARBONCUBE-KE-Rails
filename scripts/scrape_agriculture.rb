#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# Agriculture Equipment Scraper — TractorData.com
# =============================================================================
# Scrapes full tractor specifications from TractorData.com (server-rendered HTML,
# similar to GSMArena for phones).
#
# Covers subcategories:
#   - Farm Machinery (tractors from all major brands)
#   - Spare Parts (tractor models for compatibility reference)
#
# For subcategories without a dedicated spec site (Farm Tools, Irrigation,
# Accessories), we generate structured generic entries with known brands.
#
# Output: scripts/output/agriculture.json
#
# Usage:
#   ruby scripts/scrape_agriculture.rb
#   ruby scripts/scrape_agriculture.rb --brand "john deere"
#   ruby scripts/scrape_agriculture.rb --limit 50
#   ruby scripts/scrape_agriculture.rb --reset
# =============================================================================

require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'
require 'fileutils'
require 'optparse'
require 'set'

OUTPUT_DIR = File.expand_path('output', __dir__)
OUT_FILE   = File.join(OUTPUT_DIR, 'agriculture.json')
CKP_FILE   = File.join(OUTPUT_DIR, 'checkpoint_agriculture.json')
LOG_FILE   = File.join(OUTPUT_DIR, 'scrape_agriculture.log')

BASE_URL = 'https://www.tractordata.com'

MIN_DELAY = 1.0
MAX_DELAY = 2.5

USER_AGENTS = [
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15'
].freeze

# TractorData brand pages — slug maps to URL path
TRACTOR_BRANDS = [
  { name: 'John Deere',       slug: 'johndeere',       display: 'John Deere' },
  { name: 'Kubota',           slug: 'kubota',          display: 'Kubota' },
  { name: 'Massey Ferguson',  slug: 'massey-ferguson', display: 'Massey Ferguson' },
  { name: 'New Holland',      slug: 'newholland',      display: 'New Holland' },
  { name: 'Mahindra',         slug: 'mahindra',        display: 'Mahindra' },
  { name: 'Case IH',          slug: 'caseih',          display: 'Case IH' },
  { name: 'Ford',             slug: 'ford',            display: 'Ford' },
  { name: 'Deutz-Fahr',       slug: 'deutzfahr',       display: 'Deutz-Fahr' },
  { name: 'Valtra',           slug: 'valtra',          display: 'Valtra' },
  { name: 'McCormick',        slug: 'mccormick',       display: 'McCormick' },
  { name: 'LS Tractor',       slug: 'ls',              display: 'LS' },
  { name: 'Kioti',            slug: 'kioti',           display: 'Kioti' },
  { name: 'Branson',          slug: 'branson',         display: 'Branson' },
  { name: 'Tafe',             slug: 'tafe',            display: 'TAFE' },
  { name: 'Sonalika',         slug: 'sonalika',        display: 'Sonalika' },
].freeze

# Generic brand entries for non-tractor subcategories
FARM_TOOL_BRANDS = %w[Fiskars Corona True\ Temper Stanley Bahco Spear\ Jackson Husqvarna Stihl]
IRRIGATION_BRANDS = %w[Rain\ Bird Hunter Orbit Netafim Jain Lindsay Weathermatic
                       Giordano Toro Nelson Hydro-Rain]
ACCESSORY_BRANDS = %w[Carhartt Dickies DeWalt Milwaukee Stihl Husqvarna]

options = { brand_filter: nil, limit: nil, reset: false }
OptionParser.new do |opts|
  opts.on('--brand NAME', 'Scrape only this brand')  { |v| options[:brand_filter] = v.downcase }
  opts.on('--limit N', Integer, 'Max tractors per brand') { |v| options[:limit] = v }
  opts.on('--reset', 'Delete checkpoint and start fresh') { options[:reset] = true }
end.parse!

FileUtils.mkdir_p(OUTPUT_DIR)

if options[:reset]
  File.delete(OUT_FILE) if File.exist?(OUT_FILE)
  File.delete(CKP_FILE) if File.exist?(CKP_FILE)
  log_msg = "Reset: cleared output and checkpoint files"
  puts log_msg
  File.open(LOG_FILE, 'a') { |f| f.puts("[#{Time.now.strftime('%H:%M:%S')}] #{log_msg}") }
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

# ── TractorData scraping ─────────────────────────────────────────────────────

# Step 1: Get all tractor model URLs from a brand page
def scrape_brand_page(brand_slug, brand_display, limit = nil)
  url = "#{BASE_URL}/farm-tractors/tractor-brands/#{brand_slug}/#{brand_slug}-tractors.html"
  log "  Fetching brand page: #{url}"
  doc = fetch_html(url)
  return [] unless doc

  models = []
  doc.css('a').each do |a|
    href = a['href'].to_s
    if href.match?(%r{/farm-tractors/\d+/\d+/\d+/\d+-.*\.html$})
      title = a.text.strip
      next if title.empty?
      full_url = href.start_with?('http') ? href : "#{BASE_URL}#{href}"
      models << { url: full_url, title: title }
    end
  end

  # Deduplicate
  seen = Set.new
  models = models.select { |m| seen.add?(m[:url]) }

  # Apply limit
  models = models.first(limit) if limit

  log "  Found #{models.size} tractor models for #{brand_display}"
  models
end

# Step 2: Scrape individual tractor spec page
def scrape_tractor_page(url, brand_display)
  doc = fetch_html(url)
  return nil unless doc

  # Extract title from the page
  title_el = doc.at_css('h1') || doc.css('h2').first
  title = title_el ? title_el.text.strip : url.split('/').last.gsub('.html', '').gsub('-', ' ')

  specs = {}

  # Parse spec table rows — TractorData uses <tr> with 2 <td> cells for key-value pairs
  doc.css('tr').each do |tr|
    tds = tr.css('td')
    next unless tds.size == 2

    label = tds[0].text.strip
    val_raw = tds[1].text.strip
    next if label.empty? || val_raw.empty?
    next if label == "\u00a0" # skip nbsp labels

    # Clean up values — TractorData often has dual units (imperial + metric)
    val = val_raw.gsub(/\s+/, ' ').strip
    specs[label] = val
  end

  # Also extract section headers (colspan=2 rows with bold styling) as context
  # Map known TractorData spec keys to our standardized keys
  mapped = {}

  # Engine — look for engine description in colspan=2 rows under the Engine section
  engine_section = false
  engine_desc = nil
  doc.css('tr').each do |tr|
    tds = tr.css('td')
    if tds.size == 1
      text = tds[0].text.strip
      if text.match?(/Engine/i) && text.match?(/#{Regexp.escape(brand_display)}/i)
        engine_section = true
        next
      end
      if text.match?(/^(Transmission|Power|Mechanical|Hydraulics|Hitch|PTO|Power Take-off|Dimensions|Tires|Electrical|Photos|Attachments|Other)/i)
        engine_section = false
      end
      if engine_section && text.size > 5 && !text.match?(/details/i)
        engine_desc = text
        engine_section = false
      end
    end
  end
  mapped['Engine'] = engine_desc if engine_desc

  mapped['Fuel Tank'] = specs['Fuel tank'] if specs['Fuel tank']
  mapped['DEF Tank'] = specs['Exhaust fluid (DEF)'] if specs['Exhaust fluid (DEF)']

  # Power
  mapped['Engine Power (gross)'] = specs['Engine (gross)'] if specs['Engine (gross)']
  mapped['Engine Power (max)'] = specs['Engine (max)'] if specs['Engine (max)']
  mapped['PTO Power (claimed)'] = specs['PTO (claimed)'] if specs['PTO (claimed)']

  # Transmission
  mapped['Transmission'] = specs['Transmission'] if specs['Transmission']
  # Collect transmission descriptions from colspan rows
  trans_section = false
  trans_values = []
  doc.css('tr').each do |tr|
    tds = tr.css('td')
    if tds.size == 1
      text = tds[0].text.strip
      if text.match?(/Transmission/i) && !text.match?(/#{Regexp.escape(brand_display)}/i)
        trans_section = true
        next
      end
      if text.match?(/^(Engine|Power|Mechanical|Hydraulics|Hitch|PTO|Power Take-off|Dimensions|Tires|Electrical|Photos|Attachments|Other)/i)
        trans_section = false
      end
      if trans_section && text.size > 5 && !text.match?(/details/i) && !text.match?(/#{Regexp.escape(brand_display)}/i)
        trans_values << text
      end
    end
  end
  mapped['Transmission'] = trans_values.join('; ') if trans_values.any?

  # Mechanical
  mapped['Drive'] = specs['Final drives'] if specs['Final drives']
  mapped['Differential Lock'] = specs['Differential lock'] if specs['Differential lock']
  mapped['Steering'] = specs['Steering'] if specs['Steering']

  # Hydraulics
  mapped['Hydraulic Pump Flow'] = specs['Pump flow'] if specs['Pump flow']
  mapped['Rear Valves'] = specs['Rear valves'] if specs['Rear valves']
  mapped['Mid Valves'] = specs['Mid valves'] if specs['Mid valves']

  # Hitch
  mapped['Rear Hitch Type'] = specs['Rear Type'] if specs['Rear Type']
  mapped['Rear Lift Capacity'] = specs['Rear lift (at 24"/610mm)'] if specs['Rear lift (at 24"/610mm)']
  mapped['Front Hitch'] = specs['Front Hitch'] if specs['Front Hitch']
  mapped['Front Lift Capacity'] = specs['Front lift'] if specs['Front lift']

  # PTO
  mapped['Rear PTO'] = specs['Rear PTO'] if specs['Rear PTO']
  mapped['Rear PTO Type'] = specs['Rear PTO Type'] if specs['Rear PTO Type']
  mapped['Front PTO'] = specs['Front PTO'] if specs['Front PTO']
  mapped['Front PTO Type'] = specs['Front PTO Type'] if specs['Front PTO Type']

  # Dimensions
  mapped['Wheelbase'] = specs['Wheelbase'] if specs['Wheelbase']
  mapped['Weight'] = specs['Weight'] if specs['Weight']
  mapped['Front Tire'] = specs['Front tire'] if specs['Front tire']
  mapped['Rear Tire (2WD)'] = specs['2WD Rear tire'] if specs['2WD Rear tire']

  # Electrical
  mapped['Electrical'] = specs['Electrical'] if specs['Electrical']

  # Extract year/series from page content (excluding scripts)
  clean_text = doc.css('body').text.gsub(/\s+/, ' ').strip
  year_match = clean_text.match(/(\d{4})\s*-\s*(\d{4}|present)/)
  mapped['Years'] = year_match ? "#{year_match[1]}-#{year_match[2]}" : nil

  series_match = clean_text.match(/\b([A-Z0-9]+)\s+Series\b/)
  mapped['Series'] = series_match[1].strip if series_match

  mapped.reject { |_, v| v.nil? || v.to_s.strip.empty? }

  {
    'title' => "#{brand_display} #{title.gsub(/^#{Regexp.escape(brand_display)}\s*/i, '')}",
    'brand' => brand_display,
    'subcategory' => 'farm machinery',
    'specifications' => mapped,
    'tractordata_url' => url,
    'source' => 'tractordata.com'
  }
end

# ── Generic entries for non-tractor subcategories ────────────────────────────

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
    'Type' => subcategory.split.map(&:capitalize).join(' '),
    'Condition' => 'New / Used'
  }.merge(spec_overrides)
  {
    'title' => "#{brand} #{singularize(subcategory.split.last)}",
    'brand' => brand,
    'subcategory' => subcategory,
    'specifications' => specs,
    'source' => 'generic'
  }
end

# ── Main ──────────────────────────────────────────────────────────────────────

def load_json(path, default = [])
  File.exist?(path) ? (JSON.parse(File.read(path)) rescue default) : default
end

def save_json(path, data)
  File.write(path, JSON.pretty_generate(data))
end

all_results = load_json(OUT_FILE, [])
checkpoint  = load_json(CKP_FILE, { 'done_brands' => [] })
done_brands = checkpoint['done_brands']

brands_to_scrape = options[:brand_filter] ?
  TRACTOR_BRANDS.select { |b| b[:name].downcase.include?(options[:brand_filter]) } :
  TRACTOR_BRANDS

limit = options[:limit]

# ── 1. Scrape tractors from TractorData ──────────────────────────────────────
log "\n=== Scraping Tractors from TractorData.com ==="

brands_to_scrape.each do |brand|
  if done_brands.include?(brand[:slug])
    log "Skipping #{brand[:display]} (already done)"
    next
  end

  log "\n--- #{brand[:display]} ---"

  models = scrape_brand_page(brand[:slug], brand[:display], limit)

  brand_results = []
  models.each_with_index do |model, idx|
    log "  [#{idx + 1}/#{models.size}] #{model[:title]}"
    sleep(rand(MIN_DELAY..MAX_DELAY))

    result = scrape_tractor_page(model[:url], brand[:display])
    if result && result['specifications']&.any?
      brand_results << result
      log "    OK — #{result['specifications'].size} specs extracted"
    else
      log "    SKIP — no specs found"
    end
  end

  if brand_results.any?
    all_results.concat(brand_results)
    save_json(OUT_FILE, all_results)

    done_brands << brand[:slug]
    checkpoint['done_brands'] = done_brands
    save_json(CKP_FILE, checkpoint)
    log "  Finished #{brand[:display]} — #{brand_results.size} tractors (Total: #{all_results.size})"
  else
    log "  No data for #{brand[:display]}. Skipping checkpoint."
  end

  log "  Cooling down 5s..."
  sleep(5)
end

# ── 2. Add generic entries for non-tractor subcategories ─────────────────────
log "\n=== Adding generic entries for Farm Tools, Irrigation, Accessories ==="

# Farm Tools
FARM_TOOL_BRANDS.each do |brand|
  all_results << build_generic_entry(brand, 'farm tools', {
    'Tool Type' => '',
    'Material' => '',
    'Handle Type' => ''
  })
end

# Irrigation
IRRIGATION_BRANDS.each do |brand|
  all_results << build_generic_entry(brand, 'irrigation', {
    'System Type' => 'Drip, Sprinkler, Flood',
    'Pipe Diameter' => '',
    'Coverage Area' => '',
    'Material' => ''
  })
end

# Accessories
ACCESSORY_BRANDS.each do |brand|
  all_results << build_generic_entry(brand, 'accessories', {
    'Accessory Type' => '',
    'Compatible With' => '',
    'Material' => ''
  })
end

# Spare Parts — reference entries for major tractor brands
TRACTOR_BRANDS.each do |brand|
  all_results << build_generic_entry(brand[:display], 'spare parts', {
    'Part Type' => '',
    'Compatible Model' => '',
    'OEM Reference' => '',
    'Material' => ''
  })
end

# Deduplicate by title
seen = Set.new
all_results = all_results.select do |r|
  key = r['title'].to_s.downcase
  seen.add?(key)
end

save_json(OUT_FILE, all_results)

log "\n=== Done! ==="
log "Total items: #{all_results.size}"
log "Subcategories: #{all_results.group_by { |d| d['subcategory'] }.transform_values(&:size).inspect}"
log "Sources: #{all_results.group_by { |d| d['source'] }.transform_values(&:size).inspect}"
log "Output: #{OUT_FILE}"
