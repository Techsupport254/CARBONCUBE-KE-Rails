#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'nokogiri'
require 'json'
require 'fileutils'
require 'shellwords'

OUTPUT_DIR = File.expand_path('scripts/output', Dir.pwd)
OUT_FILE   = File.join(OUTPUT_DIR, 'laptops.json')
LOG_FILE   = File.join(OUTPUT_DIR, 'scrape_apple_laptops.log')
PROXY_URL  = 'socks5h://127.0.0.1:9050'

USER_AGENTS = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
].freeze

def log(msg)
  line = "[#{Time.now.strftime('%H:%M:%S')}] #{msg}"
  puts line
  File.open(LOG_FILE, 'a') { |f| f.puts(line) }
end

def rotate_tor_ip
  require 'socket'
  begin
    TCPSocket.open('127.0.0.1', 9051) do |s|
      s.puts "AUTHENTICATE \"\""
      s.puts "SIGNAL NEWNYM"
      s.puts "QUIT"
    end
    true
  rescue
    false
  end
end

def fetch_html(url, retries: 5)
  attempt = 0
  begin
    attempt += 1
    cmd = ["curl", "-L", "-s", "-w", "\sHTTP_CODE:%{http_code}", "-A", Shellwords.escape(USER_AGENTS.sample), "-x", PROXY_URL, Shellwords.escape(url)]
    output = `#{cmd.join(' ')}`
    http_code = output[/HTTP_CODE:(\d+)$/i, 1].to_i
    html_content = output.sub(/HTTP_CODE:\d+$/i, '')
    
    if http_code == 200 && html_content.size > 2000
      return Nokogiri::HTML(html_content)
    elsif http_code == 403 || http_code == 429 || html_content.include?("Too Many Requests") || html_content.size < 2000
      log "  🛑 Blocked or Empty (HTTP #{http_code}). Rotating IP..."
      rotate_tor_ip
      sleep(10)
      raise "Blocked"
    else
      log "  ⚠️ HTTP #{http_code} for #{url}"
      raise "Non-success"
    end
  rescue => e
    if attempt < retries
      sleep(5 * attempt)
      retry
    end
    log "  ❌ Failed to fetch #{url}"
    nil
  end
end

def scrape_91mobiles(brand = 'apple')
  base_url = "https://www.91mobiles.com/#{brand}-laptop-price-list-in-india"
  log "🔍 Scraping 91mobiles for #{brand.upcase}..."
  doc = fetch_html(base_url)
  return [] unless doc
  laptops = []
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
  laptops.first(5).each do |laptop|
    log "  📄 Fetching specs for #{laptop[:title]}..."
    sleep(2 + rand(3))
    detail_doc = fetch_html(laptop[:url])
    next unless detail_doc
    specs = {}
    detail_doc.css('table.spec-table, .spec_table tr').each do |row|
      label = row.at_css('td:first-child')&.text&.strip
      value = row.at_css('td:last-child')&.text&.strip
      specs[label] = value if label && value
    end
    laptop[:specifications] = specs
  end
  laptops
end

def scrape_gadgets360(brand = 'apple')
  base_url = "https://www.gadgets360.com/laptops/#{brand}-laptop-price-list"
  log "🔍 Scraping Gadgets360 for #{brand.upcase}..."
  doc = fetch_html(base_url)
  return [] unless doc
  laptops = []
  doc.css('.product-list-item, .v-list-item').each do |item|
    name_el = item.at_css('a.hl, .product-name')
    next unless name_el
    url = name_el['href']
    laptops << {
      title: name_el.text.strip,
      url: url,
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
    detail_doc.css('.specs-container .section-body .row').each do |row|
      label = row.at_css('.spec-name')&.text&.delete(':')&.strip
      value = row.at_css('.spec-value')&.text&.strip
      specs[label] = value if label && value
    end
    laptop[:specifications] = specs
  end
  laptops
end

# Main
FileUtils.mkdir_p(OUTPUT_DIR)
all_results = File.exist?(OUT_FILE) ? JSON.parse(File.read(OUT_FILE)) : []

brand = 'apple'
brand_data = []

begin
  res_91 = scrape_91mobiles(brand)
  brand_data.concat(res_91) if res_91
rescue => e
  log "  ❌ Error in 91mobiles: #{e.message}"
end

begin
  res_g360 = scrape_gadgets360(brand)
  brand_data.concat(res_g360) if res_g360
rescue => e
  log "  ❌ Error in Gadgets360: #{e.message}"
end

if brand_data.any?
  # Clean up existing results to avoid duplicates
  existing_titles = Set.new(all_results.map { |l| (l[:title] || l['title']).to_s.downcase })
  
  new_items = brand_data.reject { |l| existing_titles.include?((l[:title] || l['title']).to_s.downcase) }
  
  all_results.concat(new_items)
  File.write(OUT_FILE, JSON.pretty_generate(all_results))
  log "✅ Finished Apple — Added #{new_items.size} new MacBooks. Total in catalog: #{all_results.size}"
else
  log "⚠️ No Apple data found."
end
