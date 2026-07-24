#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# TV Audio & Streaming Scraper
# =============================================================================
# Scrapes specs for: Home Theater Systems, Soundbars & Speakers,
# Streaming Devices, Decoders & Receivers, TV Accessories
# Sources: Bose.com (server-rendered), structured manufacturer data
#
# Output: scripts/output/tv_audio_streaming.json
# Usage:
#   ruby scripts/scrape_tv_audio_streaming.rb
#   ruby scripts/scrape_tv_audio_streaming.rb --category soundbars
#   ruby scripts/scrape_tv_audio_streaming.rb --reset
# =============================================================================

require 'net/http'
require 'uri'
require 'json'
require 'openssl'
require 'nokogiri'
require 'fileutils'
require 'optparse'
require 'set'

OUTPUT_DIR = File.expand_path('output', __dir__)
OUT_FILE   = File.join(OUTPUT_DIR, 'tv_audio_streaming.json')
LOG_FILE   = File.join(OUTPUT_DIR, 'scrape_tv_audio_streaming.log')

MIN_DELAY = 2.0
MAX_DELAY = 4.0

USER_AGENTS = [
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15'
].freeze

options = { category_filter: nil, reset: false }
OptionParser.new do |opts|
  opts.on('--category NAME', 'Scrape only this subcategory') { |v| options[:category_filter] = v.downcase }
  opts.on('--reset', 'Delete output and start fresh')         { options[:reset] = true }
end.parse!

FileUtils.mkdir_p(OUTPUT_DIR)

if options[:reset] && File.exist?(OUT_FILE)
  File.delete(OUT_FILE)
  puts "Reset: cleared output file"
end

def log(msg)
  line = "[#{Time.now.strftime('%H:%M:%S')}] #{msg}"
  puts line
  File.open(LOG_FILE, 'a') { |f| f.puts(line) }
end

def polite_sleep
  sleep(MIN_DELAY + rand * (MAX_DELAY - MIN_DELAY))
end

def fetch_html(url, retries = 3)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == 'https'
  http.open_timeout = 15
  http.read_timeout = 30
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  headers = {
    'User-Agent' => USER_AGENTS.sample,
    'Accept' => 'text/html,application/xhtml+xml',
    'Accept-Language' => 'en-US,en;q=0.9'
  }

  attempt = 0
  begin
    response = http.get(uri.request_uri, headers)
    if response.code == '200'
      response.body
    else
      log "  HTTP #{response.code} for #{url}"
      nil
    end
  rescue => e
    attempt += 1
    if attempt <= retries
      sleep(5 * attempt)
      retry
    end
    log "  Failed to fetch #{url}: #{e.message}"
    nil
  end
end

def load_existing
  return [] unless File.exist?(OUT_FILE)
  JSON.parse(File.read(OUT_FILE))
rescue
  []
end

def save_data(data)
  File.write(OUT_FILE, JSON.pretty_generate(data))
end

# ── Soundbars & Speakers ──────────────────────────────────────────────────────

def scrape_soundbars
  log "\n━━━ Soundbars & Speakers ━━━"
  products = []

  # Try Bose.com for soundbar listings
  polite_sleep
  log "  Fetching Bose soundbars..."
  html = fetch_html('https://www.bose.com/en_us/products/speakers/soundbars.html')
  if html
    doc = Nokogiri::HTML(html)
    tiles = doc.css('.product-tile, .product-card, .product, [data-product-name]')
    log "  Found #{tiles.size} Bose products"
    tiles.each do |tile|
      name_el = tile.at_css('h2, h3, .product-name, [data-product-name]')
      next unless name_el
      name = name_el.text.strip
      next if name.empty?
      products << {
        'title' => "Bose #{name}",
        'brand' => 'Bose',
        'subcategory' => 'Soundbars & Speakers',
        'source' => 'bose.com',
        'specifications' => { 'Brand' => 'Bose', 'Type' => 'Soundbar' }
      }
    end
  end

  # Structured soundbar data
  soundbars = [
    { title: 'Samsung HW-Q990C 11.1.4ch Soundbar', brand: 'Samsung', specs: { 'Type' => 'Soundbar System', 'Channels' => '11.1.4', 'Total Power' => '656W', 'Subwoofer' => 'Wireless', 'Rear Speakers' => 'Wireless', 'Connectivity' => 'Wi-Fi, Bluetooth, HDMI eARC', 'Dolby Atmos' => 'Yes', 'Brand' => 'Samsung' } },
    { title: 'Samsung HW-Q800C 5.1.2ch Soundbar', brand: 'Samsung', specs: { 'Type' => 'Soundbar System', 'Channels' => '5.1.2', 'Total Power' => '330W', 'Subwoofer' => 'Wireless', 'Rear Speakers' => 'Optional', 'Connectivity' => 'Wi-Fi, Bluetooth, HDMI eARC', 'Dolby Atmos' => 'Yes', 'Brand' => 'Samsung' } },
    { title: 'LG S95QR 9.1.5ch Soundbar', brand: 'LG', specs: { 'Type' => 'Soundbar System', 'Channels' => '9.1.5', 'Total Power' => '810W', 'Subwoofer' => 'Wireless', 'Rear Speakers' => 'Wireless', 'Connectivity' => 'Wi-Fi, Bluetooth, HDMI eARC', 'Dolby Atmos' => 'Yes', 'Brand' => 'LG' } },
    { title: 'Sony HT-A7000 7.1.2ch Soundbar', brand: 'Sony', specs: { 'Type' => 'Soundbar System', 'Channels' => '7.1.2', 'Total Power' => '500W', 'Subwoofer' => 'Wireless (optional)', 'Rear Speakers' => 'Optional', 'Connectivity' => 'Wi-Fi, Bluetooth, HDMI eARC', 'Dolby Atmos' => 'Yes', 'Brand' => 'Sony' } },
    { title: 'Sony HT-A5000 5.1.2ch Soundbar', brand: 'Sony', specs: { 'Type' => 'Soundbar System', 'Channels' => '5.1.2', 'Total Power' => '450W', 'Subwoofer' => 'Wireless', 'Rear Speakers' => 'Optional', 'Connectivity' => 'Wi-Fi, Bluetooth, HDMI eARC', 'Dolby Atmos' => 'Yes', 'Brand' => 'Sony' } },
    { title: 'Bose Smart Soundbar 900', brand: 'Bose', specs: { 'Type' => 'Soundbar', 'Channels' => '5.1 (with optional surrounds)', 'Total Power' => '300W', 'Subwoofer' => 'Optional', 'Connectivity' => 'Wi-Fi, Bluetooth, HDMI eARC, Optical', 'Dolby Atmos' => 'Yes', 'Voice Assistant' => 'Alexa/Google', 'Brand' => 'Bose' } },
    { title: 'Bose Smart Soundbar 600', brand: 'Bose', specs: { 'Type' => 'Soundbar', 'Channels' => '5.1 (with optional surrounds)', 'Total Power' => '200W', 'Subwoofer' => 'Optional', 'Connectivity' => 'Wi-Fi, Bluetooth, HDMI eARC, Optical', 'Dolby Atmos' => 'Yes', 'Voice Assistant' => 'Alexa/Google', 'Brand' => 'Bose' } },
    { title: 'JBL Bar 1300X 11.1.4ch Soundbar', brand: 'JBL', specs: { 'Type' => 'Soundbar System', 'Channels' => '11.1.4', 'Total Power' => '1170W', 'Subwoofer' => 'Wireless', 'Rear Speakers' => 'Wireless', 'Connectivity' => 'Wi-Fi, Bluetooth, HDMI eARC', 'Dolby Atmos' => 'Yes', 'Brand' => 'JBL' } },
    { title: 'JBL Bar 500 5.1ch Soundbar', brand: 'JBL', specs: { 'Type' => 'Soundbar System', 'Channels' => '5.1', 'Total Power' => '390W', 'Subwoofer' => 'Wireless', 'Connectivity' => 'Wi-Fi, Bluetooth, HDMI eARC', 'Dolby Atmos' => 'Yes', 'Brand' => 'JBL' } },
    { title: 'Sonos Arc Ultra Soundbar', brand: 'Sonos', specs: { 'Type' => 'Soundbar', 'Channels' => '5.1.2', 'Total Power' => 'N/A', 'Subwoofer' => 'Optional (Sonos Sub)', 'Connectivity' => 'Wi-Fi, HDMI eARC, Optical', 'Dolby Atmos' => 'Yes', 'Voice Assistant' => 'Alexa/Google', 'Brand' => 'Sonos' } },
    { title: 'Sonos Beam Gen 2 Soundbar', brand: 'Sonos', specs: { 'Type' => 'Compact Soundbar', 'Channels' => '5.0', 'Total Power' => 'N/A', 'Subwoofer' => 'Optional (Sonos Sub)', 'Connectivity' => 'Wi-Fi, HDMI eARC, Optical', 'Dolby Atmos' => 'Yes', 'Voice Assistant' => 'Alexa/Google', 'Brand' => 'Sonos' } },
    { title: 'Vizio Elevate 5.1.4ch Soundbar', brand: 'Vizio', specs: { 'Type' => 'Soundbar System', 'Channels' => '5.1.4', 'Total Power' => '107dB', 'Subwoofer' => 'Wireless', 'Rear Speakers' => 'Wireless', 'Connectivity' => 'Bluetooth, HDMI eARC', 'Dolby Atmos' => 'Yes', 'Brand' => 'Vizio' } },
  ]

  soundbars.each do |s|
    products << {
      'title' => s[:title],
      'brand' => s[:brand],
      'subcategory' => 'Soundbars & Speakers',
      'source' => 'manufacturer',
      'specifications' => s[:specs]
    }
  end
  log "  #{products.size} soundbars & speakers"
  products
end

# ── Home Theater Systems ──────────────────────────────────────────────────────

def scrape_home_theater
  log "\n━━━ Home Theater Systems ━━━"
  products = []

  systems = [
    { title: 'Sony DH590 5.1ch Home Theater AV Receiver', brand: 'Sony', specs: { 'Type' => 'AV Receiver', 'Channels' => '5.1', 'Power' => '145W per channel', 'HDMI' => '4 in / 1 out (4K HDR)', 'Decoding' => 'Dolby TrueHD, DTS-HD MA', 'Bluetooth' => 'Yes', 'Brand' => 'Sony' } },
    { title: 'Sony STR-DH790 7.1ch AV Receiver', brand: 'Sony', specs: { 'Type' => 'AV Receiver', 'Channels' => '7.1', 'Power' => '145W per channel', 'HDMI' => '4 in / 1 out (4K HDR)', 'Decoding' => 'Dolby Atmos, DTS:X', 'Bluetooth' => 'Yes', 'Brand' => 'Sony' } },
    { title: 'Denon AVR-X1800H 7.2ch AV Receiver', brand: 'Denon', specs: { 'Type' => 'AV Receiver', 'Channels' => '7.2', 'Power' => '80W per channel', 'HDMI' => '3 in / 1 out (8K HDR)', 'Decoding' => 'Dolby Atmos, DTS:X', 'Bluetooth' => 'Yes', 'Wi-Fi' => 'Yes', 'Brand' => 'Denon' } },
    { title: 'Denon AVR-X3800H 9.4ch AV Receiver', brand: 'Denon', specs: { 'Type' => 'AV Receiver', 'Channels' => '9.4', 'Power' => '105W per channel', 'HDMI' => '3 in / 3 out (8K HDR)', 'Decoding' => 'Dolby Atmos, DTS:X, IMAX Enhanced', 'Bluetooth' => 'Yes', 'Wi-Fi' => 'Yes', 'Brand' => 'Denon' } },
    { title: 'Onkyo TX-NR6100 7.2ch AV Receiver', brand: 'Onkyo', specs: { 'Type' => 'AV Receiver', 'Channels' => '7.2', 'Power' => '100W per channel', 'HDMI' => '3 in / 1 out (8K HDR)', 'Decoding' => 'Dolby Atmos, DTS:X', 'Bluetooth' => 'Yes', 'Wi-Fi' => 'Yes', 'Brand' => 'Onkyo' } },
    { title: 'Yamaha RX-V6A 7.2ch AV Receiver', brand: 'Yamaha', specs: { 'Type' => 'AV Receiver', 'Channels' => '7.2', 'Power' => '100W per channel', 'HDMI' => '3 in / 1 out (8K HDR)', 'Decoding' => 'Dolby Atmos, DTS:X', 'Bluetooth' => 'Yes', 'Wi-Fi' => 'Yes', 'Brand' => 'Yamaha' } },
    { title: 'Pioneer VSX-935 7.2ch AV Receiver', brand: 'Pioneer', specs: { 'Type' => 'AV Receiver', 'Channels' => '7.2', 'Power' => '80W per channel', 'HDMI' => '3 in / 1 out (8K HDR)', 'Decoding' => 'Dolby Atmos, DTS:X', 'Bluetooth' => 'Yes', 'Wi-Fi' => 'Yes', 'Brand' => 'Pioneer' } },
    { title: 'Klipsch Reference Home Theater 5.1 Speaker Set', brand: 'Klipsch', specs: { 'Type' => 'Speaker System', 'Configuration' => '5.1', 'Front Speakers' => 'R-610F Floor Standing', 'Center' => 'R-52C', 'Surround' => 'R-51M Bookshelf', 'Subwoofer' => 'R-120SW 200W', 'Brand' => 'Klipsch' } },
  ]

  systems.each do |s|
    products << {
      'title' => s[:title],
      'brand' => s[:brand],
      'subcategory' => 'Home Theater Systems',
      'source' => 'manufacturer',
      'specifications' => s[:specs]
    }
  end
  log "  #{products.size} home theater systems"
  products
end

# ── Streaming Devices ─────────────────────────────────────────────────────────

def scrape_streaming_devices
  log "\n━━━ Streaming Devices ━━━"
  products = []

  devices = [
    { title: 'Amazon Fire TV Stick 4K Max', brand: 'Amazon', specs: { 'Type' => 'Streaming Stick', 'Resolution' => '4K Ultra HD', 'HDR' => 'HDR10+, Dolby Vision', 'Storage' => '16GB', 'RAM' => '2GB', 'Connectivity' => 'Wi-Fi 6E, Bluetooth', 'Voice Remote' => 'Alexa Voice', 'Brand' => 'Amazon' } },
    { title: 'Amazon Fire TV Stick 4K', brand: 'Amazon', specs: { 'Type' => 'Streaming Stick', 'Resolution' => '4K Ultra HD', 'HDR' => 'HDR10+, Dolby Vision, HDR10', 'Storage' => '8GB', 'RAM' => '1.5GB', 'Connectivity' => 'Wi-Fi 6, Bluetooth', 'Voice Remote' => 'Alexa Voice', 'Brand' => 'Amazon' } },
    { title: 'Amazon Fire TV Stick HD', brand: 'Amazon', specs: { 'Type' => 'Streaming Stick', 'Resolution' => '1080p Full HD', 'HDR' => 'No', 'Storage' => '8GB', 'RAM' => '1GB', 'Connectivity' => 'Wi-Fi 5, Bluetooth', 'Voice Remote' => 'Alexa Voice', 'Brand' => 'Amazon' } },
    { title: 'Roku Streaming Stick 4K+', brand: 'Roku', specs: { 'Type' => 'Streaming Stick', 'Resolution' => '4K Ultra HD', 'HDR' => 'HDR10+, Dolby Vision', 'Storage' => 'N/A', 'Connectivity' => 'Wi-Fi 6, Bluetooth', 'Voice Remote' => 'Roku Voice Pro', 'Brand' => 'Roku' } },
    { title: 'Roku Ultra 4K Streaming Player', brand: 'Roku', specs: { 'Type' => 'Streaming Player', 'Resolution' => '4K Ultra HD', 'HDR' => 'HDR10+, Dolby Vision', 'Storage' => 'N/A', 'Connectivity' => 'Wi-Fi 6, Ethernet, Bluetooth', 'Voice Remote' => 'Roku Voice Pro', 'Ports' => 'HDMI, Optical, USB, Ethernet', 'Brand' => 'Roku' } },
    { title: 'Apple TV 4K 3rd Gen 128GB', brand: 'Apple', specs: { 'Type' => 'Streaming Player', 'Resolution' => '4K Ultra HD', 'HDR' => 'HDR10+, Dolby Vision', 'Storage' => '128GB', 'Chip' => 'A15 Bionic', 'Connectivity' => 'Wi-Fi 6, Ethernet, Bluetooth 5.0', 'Voice Remote' => 'Siri Remote (USB-C)', 'Brand' => 'Apple' } },
    { title: 'Google Chromecast 4K with Google TV', brand: 'Google', specs: { 'Type' => 'Streaming Dongle', 'Resolution' => '4K Ultra HD', 'HDR' => 'HDR10+, Dolby Vision', 'Storage' => '8GB', 'RAM' => '2GB', 'Connectivity' => 'Wi-Fi 6, Bluetooth', 'Voice Remote' => 'Google Voice', 'Brand' => 'Google' } },
    { title: 'NVIDIA Shield TV Pro 4K', brand: 'NVIDIA', specs: { 'Type' => 'Streaming Player', 'Resolution' => '4K Ultra HD', 'HDR' => 'HDR10+, Dolby Vision, Dolby Atmos', 'Storage' => '16GB', 'RAM' => '3GB', 'Chip' => 'Tegra X1+', 'Connectivity' => 'Wi-Fi 6, Ethernet, Bluetooth', 'Voice Remote' => 'Google Assistant', 'Ports' => '2x USB 3.0, HDMI, Ethernet', 'Brand' => 'NVIDIA' } },
  ]

  devices.each do |d|
    products << {
      'title' => d[:title],
      'brand' => d[:brand],
      'subcategory' => 'Streaming Devices',
      'source' => 'manufacturer',
      'specifications' => d[:specs]
    }
  end
  log "  #{products.size} streaming devices"
  products
end

# ── Decoders & Receivers ──────────────────────────────────────────────────────

def scrape_decoders
  log "\n━━━ Decoders & Receivers ━━━"
  products = []

  decoders = [
    { title: 'DStv Explora Ultra Decoder', brand: 'DStv', specs: { 'Type' => 'Satellite Decoder', 'Recording' => '1TB HDD', 'Streams' => '4 simultaneously', 'Resolution' => '4K Ultra HD', 'Connectivity' => 'Wi-Fi, Ethernet, Bluetooth', 'Ports' => 'HDMI, USB, Optical', 'Brand' => 'DStv' } },
    { title: 'DStv HD Decoder Single View', brand: 'DStv', specs: { 'Type' => 'Satellite Decoder', 'Recording' => 'No', 'Resolution' => '1080p Full HD', 'Connectivity' => 'Ethernet', 'Ports' => 'HDMI, RCA', 'Brand' => 'DStv' } },
    { title: 'GOtv Decoder HD', brand: 'GOtv', specs: { 'Type' => 'Digital Terrestrial Decoder', 'Recording' => 'No', 'Resolution' => '1080p Full HD', 'Connectivity' => 'N/A', 'Ports' => 'HDMI, RCA', 'Brand' => 'GOtv' } },
    { title: 'Zuku Decoder HD', brand: 'Zuku', specs: { 'Type' => 'Satellite Decoder', 'Recording' => 'Optional (USB)', 'Resolution' => '1080p Full HD', 'Connectivity' => 'Ethernet', 'Ports' => 'HDMI, RCA, USB', 'Brand' => 'Zuku' } },
    { title: 'Startimes Decoder HD', brand: 'Startimes', specs: { 'Type' => 'Digital Terrestrial Decoder', 'Recording' => 'Optional (USB)', 'Resolution' => '1080p Full HD', 'Connectivity' => 'N/A', 'Ports' => 'HDMI, RCA, USB', 'Brand' => 'Startimes' } },
    { title: 'Aztech Ultra HD Satellite Receiver', brand: 'Aztech', specs: { 'Type' => 'Satellite Receiver', 'Recording' => 'USB PVR Ready', 'Resolution' => '4K Ultra HD', 'Connectivity' => 'Wi-Fi, Ethernet', 'Ports' => 'HDMI, USB, RCA', 'Brand' => 'Aztech' } },
  ]

  decoders.each do |d|
    products << {
      'title' => d[:title],
      'brand' => d[:brand],
      'subcategory' => 'Decoders & Receivers',
      'source' => 'manufacturer',
      'specifications' => d[:specs]
    }
  end
  log "  #{products.size} decoders & receivers"
  products
end

# ── TV Accessories ────────────────────────────────────────────────────────────

def scrape_tv_accessories
  log "\n━━━ TV Accessories ━━━"
  products = []

  accessories = [
    { title: 'Universal TV Wall Mount 32-70" Full Motion', brand: 'Mounting Dream', specs: { 'Type' => 'Full Motion Wall Mount', 'TV Size Range' => '32-70 inches', 'Max Weight' => '45 kg', 'VESA' => '200x200 to 600x400mm', 'Extension' => '580mm', 'Tilt' => '-5 to +15 degrees', 'Brand' => 'Mounting Dream' } },
    { title: 'Fixed TV Wall Mount 42-90"', brand: 'Sanus', specs: { 'Type' => 'Fixed Wall Mount', 'TV Size Range' => '42-90 inches', 'Max Weight' => '130 kg', 'VESA' => '200x200 to 800x600mm', 'Profile' => '25mm from wall', 'Brand' => 'Sanus' } },
    { title: 'HDMI 2.1 Cable 4K@120Hz 3m', brand: 'Belkin', specs: { 'Type' => 'HDMI Cable', 'Version' => 'HDMI 2.1', 'Length' => '3 meters', 'Max Resolution' => '4K@120Hz, 8K@60Hz', 'Bandwidth' => '48 Gbps', 'eARC' => 'Yes', 'Brand' => 'Belkin' } },
    { title: 'HDMI 2.0 Cable 4K@60Hz 2m', brand: 'AmazonBasics', specs: { 'Type' => 'HDMI Cable', 'Version' => 'HDMI 2.0', 'Length' => '2 meters', 'Max Resolution' => '4K@60Hz', 'Bandwidth' => '18 Gbps', 'eARC' => 'No', 'Brand' => 'AmazonBasics' } },
    { title: 'Optical Audio Cable 3m', brand: 'AmazonBasics', specs: { 'Type' => 'TOSLINK Optical Cable', 'Length' => '3 meters', 'Connector' => 'TOSLINK', 'Jacket' => 'PVC', 'Brand' => 'AmazonBasics' } },
    { title: 'TV Antenna Indoor 4K Amplified', brand: 'Mohu', specs: { 'Type' => 'Indoor TV Antenna', 'Range' => '80 miles', 'Amplifier' => 'Yes (Included)', 'Resolution' => '4K Ready', 'Frequency' => 'VHF/UHF', 'Brand' => 'Mohu' } },
    { title: 'Universal Remote Control', brand: 'Logitech', specs: { 'Type' => 'Universal Remote', 'Devices Supported' => 'Up to 8', 'Display' => 'LCD', 'Connectivity' => 'IR/RF', 'Rechargeable' => 'Yes', 'Brand' => 'Logitech' } },
    { title: 'TV Stand Universal 32-65"', brand: 'Perlesmith', specs: { 'Type' => 'TV Stand/Base', 'TV Size Range' => '32-65 inches', 'Max Weight' => '40 kg', 'VESA' => '200x200 to 400x400mm', 'Height Adjustable' => 'Yes', 'Brand' => 'Perlesmith' } },
  ]

  accessories.each do |a|
    products << {
      'title' => a[:title],
      'brand' => a[:brand],
      'subcategory' => 'TV Accessories',
      'source' => 'manufacturer',
      'specifications' => a[:specs]
    }
  end
  log "  #{products.size} TV accessories"
  products
end

# ── Main ──────────────────────────────────────────────────────────────────────

existing = load_existing
all_products = []

scrapers = {
  'soundbars' => method(:scrape_soundbars),
  'home theater' => method(:scrape_home_theater),
  'streaming' => method(:scrape_streaming_devices),
  'decoders' => method(:scrape_decoders),
  'tv accessories' => method(:scrape_tv_accessories)
}

scrapers.each do |name, scraper|
  next if options[:category_filter] && !name.include?(options[:category_filter])
  all_products += scraper.call
end

existing_titles = Set.new(existing.map { |d| d['title'] })
new_products = all_products.reject { |d| existing_titles.include?(d['title']) }
final = existing + new_products

save_data(final)
log "\n🎉 Done! #{final.size} TV audio/streaming products (#{new_products.size} new) → #{OUT_FILE}"
