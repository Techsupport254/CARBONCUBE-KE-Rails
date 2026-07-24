#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# Apple Products Specs Scraper — apple.com/specs pages
# =============================================================================
# Scrapes full technical specifications for all Apple Mac products directly
# from Apple's server-rendered tech specs pages.
#
# Covers: Mac Mini, Mac Studio, iMac, MacBook Air, MacBook Pro
# Includes latest M4, M4 Pro, M3, M3 Pro, M3 Max, M2, M2 Pro, M2 Max, M2 Ultra
#
# Output: scripts/output/apple_computers.json
#
# Usage:
#   ruby scripts/scrape_apple_specs.rb
# =============================================================================

require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'
require 'fileutils'
require 'set'

OUTPUT_DIR = File.expand_path('output', __dir__)
OUT_FILE   = File.join(OUTPUT_DIR, 'apple_computers.json')
LOG_FILE   = File.join(OUTPUT_DIR, 'scrape_apple_specs.log')

MIN_DELAY = 2.0
MAX_DELAY = 4.0

APPLE_PRODUCTS = [
  { name: 'Mac Mini',      url: 'https://www.apple.com/mac-mini/specs/',     category: 'computers' },
  { name: 'Mac Studio',    url: 'https://www.apple.com/mac-studio/specs/',   category: 'computers' },
  { name: 'iMac',          url: 'https://www.apple.com/imac/specs/',         category: 'computers' },
  { name: 'MacBook Air',   url: 'https://www.apple.com/macbook-air/specs/',  category: 'laptops' },
  { name: 'MacBook Pro',   url: 'https://www.apple.com/macbook-pro/specs/',  category: 'laptops' },
].freeze

FileUtils.mkdir_p(OUTPUT_DIR)

def log(msg)
  line = "[#{Time.now.strftime('%H:%M:%S')}] #{msg}"
  puts line
  File.open(LOG_FILE, 'a') { |f| f.puts(line) }
end

def fetch_html(url)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = 20
  http.open_timeout = 15

  request = Net::HTTP::Get.new(uri)
  request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
  request['Accept'] = 'text/html,application/xhtml+xml'
  request['Accept-Language'] = 'en-US,en;q=0.9'

  response = http.request(request)
  if response.code == '200'
    Nokogiri::HTML(response.body)
  else
    log "  HTTP #{response.code} for #{url}"
    nil
  end
rescue => e
  log "  Failed to fetch #{url}: #{e.message}"
  nil
end

def scrape_apple_specs_page(product_name, url, category)
  log "  Fetching: #{url}"
  doc = fetch_html(url)
  return [] unless doc

  results = []

  # Parse the techspecs rows — Apple uses .techspecs-row with .techspecs-rowheader and .techspecs-column
  spec_rows = {}
  doc.css('.techspecs-row').each do |row|
    label = row.at_css('.techspecs-rowheader')&.text&.strip
    next unless label
    columns = row.css('.techspecs-column').map { |c| c.text.strip.gsub(/\s+/, ' ') }
    spec_rows[label] = columns
  end

  # Determine number of models from the column headers
  model_headers = doc.css('.techspecs-columnheader').map { |c| c.text.strip }
  num_models = model_headers.size
  num_models = spec_rows.values.map(&:size).max || 1 if num_models == 0
  num_models = 1 if num_models == 0

  log "  Found #{num_models} model configurations"

  # Build a product entry for each model configuration
  (0...num_models).each do |model_idx|
    specs = {}

    spec_rows.each do |label, columns|
      val = columns[model_idx]
      next if val.nil? || val.to_s.strip.empty?
      specs[label] = val.strip
    end

    next if specs.empty?

    # Build title from chip and product name
    chip = specs['Chip']&.split&.first(3)&.join(' ') || ''
    memory = specs['Memory']&.match(/(\d+GB)/)&.[](1) || ''
    storage = specs['Storage']&.match(/(\d+GB\sSSD|\d+TB\sSSD)/)&.[](1) || ''

    title_parts = [product_name]
    title_parts << "(#{chip})" if !chip.empty?
    title_parts << "/ #{memory}" if !memory.empty?
    title_parts << "/ #{storage}" if !storage.empty?
    title = title_parts.join(' ')

    # Map to standardized spec keys
    mapped = {}
    mapped['Chip'] = specs['Chip'] if specs['Chip']
    mapped['Memory'] = specs['Memory'] if specs['Memory']
    mapped['Storage'] = specs['Storage'] if specs['Storage']
    mapped['Display Support'] = specs['Display Support'] if specs['Display Support']
    mapped['Video Playback'] = specs['Video Playback'] if specs['Video Playback']
    mapped['Audio'] = specs['Audio'] if specs['Audio']
    mapped['Connections and Expansion'] = specs['Connections and Expansion'] if specs['Connections and Expansion']
    mapped['Communications'] = specs['Communications'] if specs['Communications']
    mapped['Size and Weight'] = specs['Size and Weight'] if specs['Size and Weight']
    mapped['Electrical and Operating Requirements'] = specs['Electrical and Operating Requirement'] if specs['Electrical and Operating Requirement']
    mapped['Operating System'] = specs['Operating System'] if specs['Operating System']
    mapped['In the Box'] = specs['In the Box'] if specs['In the Box']
    mapped['Finish'] = specs['Finish'] if specs['Finish']
    mapped['Price'] = specs['Price'] if specs['Price']

    mapped.reject { |_, v| v.nil? || v.to_s.strip.empty? }

    results << {
      'title' => title,
      'brand' => 'Apple',
      'subcategory' => category,
      'specifications' => mapped,
      'source' => 'apple.com'
    }
  end

  results
end

# ── Main ──────────────────────────────────────────────────────────────────────

log "\n=== Scraping Apple Tech Specs ==="

all_results = []

APPLE_PRODUCTS.each do |product|
  log "\n--- #{product[:name]} ---"
  sleep(rand(MIN_DELAY..MAX_DELAY))

  results = scrape_apple_specs_page(product[:name], product[:url], product[:category])
  if results.any?
    all_results.concat(results)
    log "  #{results.size} configurations extracted"
  else
    log "  No specs found"
  end
end

# Deduplicate by title
seen = Set.new
all_results = all_results.select { |r| seen.add?(r['title']) }

File.write(OUT_FILE, JSON.pretty_generate(all_results))

log "\n=== Done! ==="
log "Total items: #{all_results.size}"
log "Subcategories: #{all_results.group_by { |d| d['subcategory'] }.transform_values(&:size).inspect}"
log "Output: #{OUT_FILE}"
