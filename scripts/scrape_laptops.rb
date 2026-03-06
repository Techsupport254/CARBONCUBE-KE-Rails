#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# Laptop Scraper - 91mobiles & Gadgets360
# =============================================================================
# Scrapes laptop specifications for brand: HP (and others)
# 
# Note: These sites have high anti-bot protection. 
# This script uses Nokogiri and mimics a browser, but for large-scale 
# production usage, rotating proxies or Selenium may be required.
# =============================================================================

require 'net/http'
require 'nokogiri'
require 'json'
require 'fileutils'
require 'optparse'

# ── Configuration ─────────────────────────────────────────────────────────────
OUTPUT_DIR = File.expand_path('output', __dir__)
OUT_FILE   = File.join(OUTPUT_DIR, 'laptops.json')
CKP_FILE   = File.join(OUTPUT_DIR, 'checkpoint_laptops.json')
LOG_FILE   = File.join(OUTPUT_DIR, 'scrape_laptops.log')

LAPTOP_BRANDS = %w[hp dell lenovo asus acer apple msi microsoft samsung razer lg gigabyte huawei xiaomi].freeze

USER_AGENTS = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36'
].freeze

# ── Logging ───────────────────────────────────────────────────────────────────
def log(msg)
  line = "[#{Time.now.strftime('%H:%M:%S')}] #{msg}"
  puts line
  File.open(LOG_FILE, 'a') { |f| f.puts(line) }
end

# ── HTTP Helper ───────────────────────────────────────────────────────────────
def fetch_html(url, retries: 3)
  uri = URI(url)
  attempt = 0
  
  begin
    attempt += 1
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = USER_AGENTS.sample
    request['Accept'] = 'text/html,application/xhtml+xml,application/xml'
    request['Accept-Language'] = 'en-US,en;q=0.9'
    request['Referer'] = 'https://www.google.com/'

    response = http.request(request)

    if response.code == '200'
      return Nokogiri::HTML(response.body)
    elsif response.code == '403' || response.code == '429'
      log "  🛑 Blocked (HTTP #{response.code}). These sites often require human interaction or rotating proxies."
      return nil
    else
      log "  ⚠️ HTTP #{response.code} for #{url}"
      raise "Non-success"
    end
  rescue => e
    if attempt < retries
      sleep(10 * attempt)
      retry
    end
    log "  ❌ Failed to fetch #{url}: #{e.message}"
    nil
  end
end

# ── Site Scrapers ───────────────────────────────────────────────────────────

def scrape_91mobiles(brand = 'hp')
  base_url = "https://www.91mobiles.com/#{brand}-laptop-price-list-in-india"
  log "🔍 Scraping 91mobiles for #{brand.upcase}..."
  
  doc = fetch_html(base_url)
  return [] unless doc

  laptops = []
  # Each product card is usually in a list
  doc.css('.filter-product-item, .product-listing').each do |item|
    name_el = item.at_css('a.hover_link, .name')
    next unless name_el

    link = name_el['href']
    link = "https://www.91mobiles.com#{link}" unless link.start_with?('http')
    
    laptops << {
      title: name_el.text.strip,
      url: link,
      price: item.at_css('.price')&.text&.strip,
      brand: brand,
      source: '91mobiles'
    }
  end

  # Now fetch details for each (Sampling first 5 for speed)
  laptops.first(5).each do |laptop|
    log "  📄 Fetching specs for #{laptop[:title]}..."
    sleep(2 + rand(3))
    detail_doc = fetch_html(laptop[:url])
    next unless detail_doc

    specs = {}
    # 91mobiles often uses a table for specs
    detail_doc.css('table.spec-table, .spec_table tr').each do |row|
      label = row.at_css('td:first-child')&.text&.strip
      value = row.at_css('td:last-child')&.text&.strip
      specs[label] = value if label && value
    end
    laptop[:specifications] = specs
  end

  laptops
end

def scrape_gadgets360(brand = 'hp')
  base_url = "https://www.gadgets360.com/laptops/#{brand}-laptop-price-list"
  log "🔍 Scraping Gadgets360 for #{brand.upcase}..."

  doc = fetch_html(base_url)
  return [] unless doc

  laptops = []
  doc.css('.product-list-item, .v-list-item').each do |item|
    name_el = item.at_css('a.hl, .product-name')
    next unless name_el

    laptops << {
      title: name_el.text.strip,
      url: name_el['href'],
      price: item.at_css('.price')&.text&.strip,
      brand: brand,
      source: 'Gadgets360'
    }
  end

  laptops.first(5).each do |laptop|
    log "  📄 Fetching specs for #{laptop[:title]}..."
    sleep(2 + rand(3))
    detail_doc = fetch_html(laptop[:url])
    next unless detail_doc

    specs = {}
    # Gadgets360 uses divs/columns for specs
    detail_doc.css('.specs-container .section-body .row').each do |row|
      label = row.at_css('.spec-name')&.text&.delete(':')&.strip
      value = row.at_css('.spec-value')&.text&.strip
      specs[label] = value if label && value
    end
    laptop[:specifications] = specs
  end

  laptops
end

# ── Main ──────────────────────────────────────────────────────────────────────
FileUtils.mkdir_p(OUTPUT_DIR)

def load_json(path, default = [])
  File.exist?(path) ? (JSON.parse(File.read(path)) rescue default) : default
end

def save_json(path, data)
  File.write(path, JSON.pretty_generate(data))
end

all_results = load_json(OUT_FILE, [])
checkpoint  = load_json(CKP_FILE, { 'done_brands' => [] })
done_brands = checkpoint['done_brands']

LAPTOP_BRANDS.each do |brand|
  if done_brands.include?(brand)
    log "⏭  Skipping #{brand.upcase} (already done)"
    next
  end

  log "\n" + ("=" * 30)
  log "🚀 Starting Brand: #{brand.upcase}"
  log ("=" * 30)

  brand_data = []
  
  # Try 91mobiles
  begin
    res_91 = scrape_91mobiles(brand)
    brand_data.concat(res_91) if res_91
  rescue => e
    log "  ❌ Error in 91mobiles for #{brand}: #{e.message}"
  end

  # Try Gadgets360
  begin
    res_g360 = scrape_gadgets360(brand)
    brand_data.concat(res_g360) if res_g360
  rescue => e
    log "  ❌ Error in Gadgets360 for #{brand}: #{e.message}"
  end

  if brand_data.any?
    all_results.concat(brand_data)
    save_json(OUT_FILE, all_results)
    
    done_brands << brand
    checkpoint['done_brands'] = done_brands
    save_json(CKP_FILE, checkpoint)
    log "✅ Finished #{brand.upcase} — Total Laptops Scraped: #{all_results.size}"
  else
    log "⚠️  No data found for #{brand.upcase}. Skipping checkpoint."
  end

  # Cooling down between brands
  log "💤 Cooling down for 10s before next brand..."
  sleep(10)
end

log "\n🎉 All done! Final list saved to #{OUT_FILE}"
