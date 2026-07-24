#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# Computer Accessories Scraper
# =============================================================================
# Scrapes specs for: Peripherals, Storage, Networking Equipment,
# Cooling & Maintenance, Internal Components
# Sources: Logitech.com (server-rendered product tiles), structured data
#
# Output: scripts/output/computer_accessories.json
# Usage:
#   ruby scripts/scrape_computer_accessories.rb
#   ruby scripts/scrape_computer_accessories.rb --category peripherals
#   ruby scripts/scrape_computer_accessories.rb --reset
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
OUT_FILE   = File.join(OUTPUT_DIR, 'computer_accessories.json')
LOG_FILE   = File.join(OUTPUT_DIR, 'scrape_computer_accessories.log')

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

def fetch_html(url, retries = 3, redirect_limit = 5)
  return nil if redirect_limit <= 0
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
    elsif ['301', '302', '303', '307', '308'].include?(response.code)
      location = response['Location']
      if location
        new_url = location.start_with?('http') ? location : "#{uri.scheme}://#{uri.host}#{location}"
        return fetch_html(new_url, retries, redirect_limit - 1)
      end
      nil
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

# ── Peripherals (from Logitech.com) ───────────────────────────────────────────

def scrape_logitech_products
  log "\n━━━ Scraping Logitech Peripherals ━━━"
  products = []

  category_pages = [
    { url: 'https://www.logitech.com/en-us/products/mice.html', sub: 'Peripherals', type: 'Mouse' },
    { url: 'https://www.logitech.com/en-us/products/keyboards.html', sub: 'Peripherals', type: 'Keyboard' },
    { url: 'https://www.logitech.com/en-us/products/webcams.html', sub: 'Peripherals', type: 'Webcam' },
    { url: 'https://www.logitech.com/en-us/products/headsets.html', sub: 'Peripherals', type: 'Headset' },
    { url: 'https://www.logitech.com/en-us/products/speakers.html', sub: 'Peripherals', type: 'Speaker' },
  ]

  category_pages.each do |cp|
    polite_sleep
    log "  Fetching #{cp[:type]}s from logitech.com..."
    html = fetch_html(cp[:url])
    next unless html

    doc = Nokogiri::HTML(html)
    tiles = doc.css('.product-tile, .product-card, .product')
    log "  Found #{tiles.size} #{cp[:type]} products"

    tiles.each do |tile|
      name_el = tile.at_css('h2, h3, .product-name, [data-product-name]')
      next unless name_el
      name = name_el.text.strip
      next if name.empty?

      link_el = tile.at_css('a[href]')
      href = link_el ? link_el['href'] : nil
      url = href ? "https://www.logitech.com#{href}" : cp[:url]

      specs = {
        'Brand' => 'Logitech',
        'Type' => cp[:type],
        'Connectivity' => name.match?(/wireless|bluetooth/i) ? 'Wireless' : 'Wired',
        'Category' => cp[:type]
      }

      products << {
        'title' => "Logitech #{name}",
        'brand' => 'Logitech',
        'subcategory' => cp[:sub],
        'source' => 'logitech.com',
        'source_url' => url,
        'specifications' => specs
      }
    end
  end

  # Add structured entries for other peripheral brands
  structured_peripherals = [
    { title: 'Razer DeathAdder V3 Pro Wireless Mouse', brand: 'Razer', specs: { 'Type' => 'Mouse', 'Connectivity' => 'Wireless', 'Sensor' => 'Focus Pro 30K Optical', 'DPI' => '30000', 'Buttons' => '5', 'Weight' => '63g', 'Brand' => 'Razer' } },
    { title: 'Razer BlackWidow V4 Pro Keyboard', brand: 'Razer', specs: { 'Type' => 'Keyboard', 'Connectivity' => 'Wired', 'Switch Type' => 'Green Mechanical', 'Backlight' => 'RGB', 'Key Rollover' => 'N-Key', 'Brand' => 'Razer' } },
    { title: 'Corsair K70 RGB Pro Keyboard', brand: 'Corsair', specs: { 'Type' => 'Keyboard', 'Connectivity' => 'Wired', 'Switch Type' => 'Cherry MX Red', 'Backlight' => 'RGB', 'Key Rollover' => 'N-Key', 'Brand' => 'Corsair' } },
    { title: 'Corsair M65 RGB Ultra Mouse', brand: 'Corsair', specs: { 'Type' => 'Mouse', 'Connectivity' => 'Wired', 'Sensor' => '18,000 DPI Optical', 'DPI' => '18000', 'Buttons' => '8', 'Weight' => '97g', 'Brand' => 'Corsair' } },
    { title: 'SteelSeries Apex Pro Keyboard', brand: 'SteelSeries', specs: { 'Type' => 'Keyboard', 'Connectivity' => 'Wired', 'Switch Type' => 'OmniPoint Adjustable', 'Backlight' => 'RGB', 'Key Rollover' => 'N-Key', 'Brand' => 'SteelSeries' } },
    { title: 'SteelSeries Arctis Nova Pro Wireless Headset', brand: 'SteelSeries', specs: { 'Type' => 'Headset', 'Connectivity' => 'Wireless', 'Driver' => '40mm', 'Frequency Response' => '10-40,000 Hz', 'Microphone' => 'ClearCast Gen2', 'Brand' => 'SteelSeries' } },
    { title: 'Microsoft Surface Mouse', brand: 'Microsoft', specs: { 'Type' => 'Mouse', 'Connectivity' => 'Wireless', 'Sensor' => 'BlueTrack', 'DPI' => '1000', 'Buttons' => '3', 'Brand' => 'Microsoft' } },
    { title: 'Microsoft Modern Webcam', brand: 'Microsoft', specs: { 'Type' => 'Webcam', 'Resolution' => '1080p', 'Frame Rate' => '30fps', 'Field of View' => '78 degrees', 'Microphone' => 'Built-in', 'Brand' => 'Microsoft' } },
    { title: 'Dell UltraSharp U2723QE Monitor 27"', brand: 'Dell', specs: { 'Type' => 'Monitor', 'Screen Size' => '27 inches', 'Resolution' => '3840x2160 (4K)', 'Panel Type' => 'IPS Black', 'Refresh Rate' => '60Hz', 'Ports' => 'USB-C 90W, HDMI, DisplayPort', 'Brand' => 'Dell' } },
    { title: 'Samsung Odyssey G7 32" Curved Monitor', brand: 'Samsung', specs: { 'Type' => 'Monitor', 'Screen Size' => '32 inches', 'Resolution' => '2560x1440', 'Panel Type' => 'VA Curved', 'Refresh Rate' => '240Hz', 'Response Time' => '1ms', 'Brand' => 'Samsung' } },
    { title: 'LG UltraFine 5K 27" Monitor', brand: 'LG', specs: { 'Type' => 'Monitor', 'Screen Size' => '27 inches', 'Resolution' => '5120x2880 (5K)', 'Panel Type' => 'IPS', 'Refresh Rate' => '60Hz', 'Ports' => 'Thunderbolt 3', 'Brand' => 'LG' } },
    { title: 'ASUS ProArt PA278CV 27" Monitor', brand: 'Asus', specs: { 'Type' => 'Monitor', 'Screen Size' => '27 inches', 'Resolution' => '2560x1440', 'Panel Type' => 'IPS', 'Refresh Rate' => '75Hz', 'Ports' => 'DisplayPort, HDMI, USB-C', 'Brand' => 'Asus' } },
  ]

  structured_peripherals.each do |p|
    products << {
      'title' => p[:title],
      'brand' => p[:brand],
      'subcategory' => 'Peripherals',
      'source' => 'manufacturer',
      'specifications' => p[:specs]
    }
  end

  log "  Total peripherals: #{products.size}"
  products
end

# ── Storage ───────────────────────────────────────────────────────────────────

def scrape_storage
  log "\n━━━ Storage Devices ━━━"
  products = []

  storage = [
    { title: 'Samsung 990 Pro 2TB NVMe SSD', brand: 'Samsung', specs: { 'Type' => 'NVMe SSD', 'Capacity' => '2TB', 'Form Factor' => 'M.2 2280', 'Interface' => 'PCIe 4.0 x4', 'Read Speed' => '7450 MB/s', 'Write Speed' => '6900 MB/s', 'Brand' => 'Samsung' } },
    { title: 'Samsung 990 Pro 1TB NVMe SSD', brand: 'Samsung', specs: { 'Type' => 'NVMe SSD', 'Capacity' => '1TB', 'Form Factor' => 'M.2 2280', 'Interface' => 'PCIe 4.0 x4', 'Read Speed' => '7450 MB/s', 'Write Speed' => '6900 MB/s', 'Brand' => 'Samsung' } },
    { title: 'Samsung 870 EVO 1TB SATA SSD', brand: 'Samsung', specs: { 'Type' => 'SATA SSD', 'Capacity' => '1TB', 'Form Factor' => '2.5"', 'Interface' => 'SATA III', 'Read Speed' => '560 MB/s', 'Write Speed' => '530 MB/s', 'Brand' => 'Samsung' } },
    { title: 'WD Black SN850X 2TB NVMe SSD', brand: 'Western Digital', specs: { 'Type' => 'NVMe SSD', 'Capacity' => '2TB', 'Form Factor' => 'M.2 2280', 'Interface' => 'PCIe 4.0 x4', 'Read Speed' => '7300 MB/s', 'Write Speed' => '6600 MB/s', 'Brand' => 'Western Digital' } },
    { title: 'WD Blue 1TB SATA SSD', brand: 'Western Digital', specs: { 'Type' => 'SATA SSD', 'Capacity' => '1TB', 'Form Factor' => '2.5"', 'Interface' => 'SATA III', 'Read Speed' => '560 MB/s', 'Write Speed' => '530 MB/s', 'Brand' => 'Western Digital' } },
    { title: 'Crucial MX500 1TB SATA SSD', brand: 'Crucial', specs: { 'Type' => 'SATA SSD', 'Capacity' => '1TB', 'Form Factor' => '2.5"', 'Interface' => 'SATA III', 'Read Speed' => '560 MB/s', 'Write Speed' => '510 MB/s', 'Brand' => 'Crucial' } },
    { title: 'Crucial P3 Plus 2TB NVMe SSD', brand: 'Crucial', specs: { 'Type' => 'NVMe SSD', 'Capacity' => '2TB', 'Form Factor' => 'M.2 2280', 'Interface' => 'PCIe 4.0 x4', 'Read Speed' => '5000 MB/s', 'Write Speed' => '4200 MB/s', 'Brand' => 'Crucial' } },
    { title: 'Seagate IronWolf 4TB NAS HDD', brand: 'Seagate', specs: { 'Type' => 'NAS HDD', 'Capacity' => '4TB', 'Form Factor' => '3.5"', 'Interface' => 'SATA III', 'RPM' => '7200', 'Cache' => '256MB', 'Brand' => 'Seagate', 'Workload' => 'NAS' } },
    { title: 'Seagate Barracuda 2TB HDD', brand: 'Seagate', specs: { 'Type' => 'Desktop HDD', 'Capacity' => '2TB', 'Form Factor' => '3.5"', 'Interface' => 'SATA III', 'RPM' => '7200', 'Cache' => '256MB', 'Brand' => 'Seagate' } },
    { title: 'WD Red Plus 4TB NAS HDD', brand: 'Western Digital', specs: { 'Type' => 'NAS HDD', 'Capacity' => '4TB', 'Form Factor' => '3.5"', 'Interface' => 'SATA III', 'RPM' => '5400', 'Cache' => '256MB', 'Brand' => 'Western Digital', 'Workload' => 'NAS' } },
    { title: 'Toshiba N300 8TB NAS HDD', brand: 'Toshiba', specs: { 'Type' => 'NAS HDD', 'Capacity' => '8TB', 'Form Factor' => '3.5"', 'Interface' => 'SATA III', 'RPM' => '7200', 'Cache' => '256MB', 'Brand' => 'Toshiba', 'Workload' => 'NAS' } },
    { title: 'LaCie Rugged Mini 2TB External HDD', brand: 'LaCie', specs: { 'Type' => 'External HDD', 'Capacity' => '2TB', 'Form Factor' => '2.5" Portable', 'Interface' => 'USB 3.0', 'RPM' => '5400', 'Brand' => 'LaCie', 'Feature' => 'Rugged/Drop Resistant' } },
    { title: 'Samsung T7 Portable 1TB External SSD', brand: 'Samsung', specs: { 'Type' => 'External SSD', 'Capacity' => '1TB', 'Form Factor' => 'Portable', 'Interface' => 'USB 3.2 Gen2', 'Read Speed' => '1050 MB/s', 'Write Speed' => '1000 MB/s', 'Brand' => 'Samsung' } },
    { title: 'SanDisk Extreme Portable 2TB SSD', brand: 'SanDisk', specs: { 'Type' => 'External SSD', 'Capacity' => '2TB', 'Form Factor' => 'Portable', 'Interface' => 'USB 3.2 Gen2', 'Read Speed' => '1050 MB/s', 'Write Speed' => '1000 MB/s', 'Brand' => 'SanDisk', 'Feature' => 'IP65 Water/Dust Resistant' } },
  ]

  storage.each do |s|
    products << {
      'title' => s[:title],
      'brand' => s[:brand],
      'subcategory' => 'Storage',
      'source' => 'manufacturer',
      'specifications' => s[:specs]
    }
  end
  log "  #{products.size} storage devices"
  products
end

# ── Networking Equipment ──────────────────────────────────────────────────────

def scrape_networking
  log "\n━━━ Networking Equipment ━━━"
  products = []

  networking = [
    { title: 'TP-Link Archer AX73 Wi-Fi 6 Router', brand: 'TP-Link', specs: { 'Type' => 'Router', 'Wi-Fi Standard' => 'Wi-Fi 6 (802.11ax)', 'Speed' => 'AX5400', 'Bands' => 'Dual Band', 'Ports' => '5x Gigabit', 'Antennas' => '6 High Gain', 'Brand' => 'TP-Link' } },
    { title: 'TP-Link Archer AX55 Wi-Fi 6 Router', brand: 'TP-Link', specs: { 'Type' => 'Router', 'Wi-Fi Standard' => 'Wi-Fi 6 (802.11ax)', 'Speed' => 'AX3000', 'Bands' => 'Dual Band', 'Ports' => '4x Gigabit', 'Antennas' => '4 High Gain', 'Brand' => 'TP-Link' } },
    { title: 'ASUS RT-AX86U Wi-Fi 6 Router', brand: 'Asus', specs: { 'Type' => 'Router', 'Wi-Fi Standard' => 'Wi-Fi 6 (802.11ax)', 'Speed' => 'AX5700', 'Bands' => 'Dual Band', 'Ports' => '4x Gigabit + 1x 2.5G', 'Antennas' => '3 External', 'Brand' => 'Asus' } },
    { title: 'Netgear Nighthawk RAX120 Wi-Fi 6 Router', brand: 'Netgear', specs: { 'Type' => 'Router', 'Wi-Fi Standard' => 'Wi-Fi 6 (802.11ax)', 'Speed' => 'AX6000', 'Bands' => 'Dual Band', 'Ports' => '4x Gigabit + 1x 5G', 'Antennas' => '8 Internal', 'Brand' => 'Netgear' } },
    { title: 'TP-Link Deco X60 Mesh Wi-Fi 6 System', brand: 'TP-Link', specs: { 'Type' => 'Mesh System', 'Wi-Fi Standard' => 'Wi-Fi 6 (802.11ax)', 'Speed' => 'AX3000', 'Coverage' => '5000 sq ft (3-pack)', 'Bands' => 'Dual Band', 'Ports' => '2x Gigabit per node', 'Brand' => 'TP-Link' } },
    { title: 'Netgear Orbi RBK852 Mesh Wi-Fi 6 System', brand: 'Netgear', specs: { 'Type' => 'Mesh System', 'Wi-Fi Standard' => 'Wi-Fi 6 (802.11ax)', 'Speed' => 'AX6000', 'Coverage' => '5000 sq ft (2-pack)', 'Bands' => 'Tri-Band', 'Ports' => '4x Gigabit per node', 'Brand' => 'Netgear' } },
    { title: 'TP-Link TL-SG1008D 8-Port Gigabit Switch', brand: 'TP-Link', specs: { 'Type' => 'Switch', 'Ports' => '8x Gigabit', 'Switching Capacity' => '16 Gbps', 'Form Factor' => 'Desktop', 'Power' => 'External 5V', 'Brand' => 'TP-Link' } },
    { title: 'TP-Link TL-SG1024D 24-Port Gigabit Switch', brand: 'TP-Link', specs: { 'Type' => 'Switch', 'Ports' => '24x Gigabit', 'Switching Capacity' => '48 Gbps', 'Form Factor' => 'Rack Mount 1U', 'Power' => 'Internal 100-240V', 'Brand' => 'TP-Link' } },
    { title: 'Cisco SG250-24 Smart Switch', brand: 'Cisco', specs: { 'Type' => 'Smart Switch', 'Ports' => '24x Gigabit + 2x SFP', 'Switching Capacity' => '52 Gbps', 'Management' => 'Web-based', 'VLAN Support' => 'Yes', 'Brand' => 'Cisco' } },
    { title: 'Ubiquiti UniFi Dream Machine Pro', brand: 'Ubiquiti', specs: { 'Type' => 'Gateway/Router', 'Ports' => '8x Gigabit + 1x 10G SFP+', 'Throughput' => '3.5 Gbps', 'Wi-Fi' => 'No (Router only)', 'Management' => 'UniFi Network Controller', 'Brand' => 'Ubiquiti' } },
    { title: 'TP-Link RE700X Wi-Fi 6 Range Extender', brand: 'TP-Link', specs: { 'Type' => 'Range Extender', 'Wi-Fi Standard' => 'Wi-Fi 6 (802.11ax)', 'Speed' => 'AX3000', 'Bands' => 'Dual Band', 'Ports' => '1x Gigabit', 'Brand' => 'TP-Link' } },
    { title: 'Netgear GS108 8-Port Gigabit Switch', brand: 'Netgear', specs: { 'Type' => 'Switch', 'Ports' => '8x Gigabit', 'Switching Capacity' => '16 Gbps', 'Form Factor' => 'Desktop', 'Power' => 'External 12V', 'Brand' => 'Netgear' } },
  ]

  networking.each do |n|
    products << {
      'title' => n[:title],
      'brand' => n[:brand],
      'subcategory' => 'Networking Equipment',
      'source' => 'manufacturer',
      'specifications' => n[:specs]
    }
  end
  log "  #{products.size} networking devices"
  products
end

# ── Cooling & Maintenance ─────────────────────────────────────────────────────

def scrape_cooling
  log "\n━━━ Cooling & Maintenance ━━━"
  products = []

  cooling = [
    { title: 'Noctua NH-D15 CPU Cooler', brand: 'Noctua', specs: { 'Type' => 'Air Cooler', 'Fan Size' => '2x 140mm', 'Height' => '165mm', 'TDP' => '220W', 'Noise Level' => '24.6 dB(A)', 'Socket Compatibility' => 'LGA1700, AM5, AM4', 'Brand' => 'Noctua' } },
    { title: 'Cooler Master Hyper 212 Black Edition', brand: 'Cooler Master', specs: { 'Type' => 'Air Cooler', 'Fan Size' => '1x 120mm', 'Height' => '159mm', 'TDP' => '150W', 'Noise Level' => '26 dB(A)', 'Socket Compatibility' => 'LGA1700, AM5, AM4', 'Brand' => 'Cooler Master' } },
    { title: 'Corsair iCUE H150i Elite Capellix AIO', brand: 'Corsair', specs: { 'Type' => 'Liquid Cooler (AIO)', 'Radiator Size' => '360mm', 'Fans' => '3x 120mm', 'TDP' => '250W', 'Noise Level' => '36 dB(A)', 'Socket Compatibility' => 'LGA1700, AM5, AM4', 'Brand' => 'Corsair' } },
    { title: 'NZXT Kraken Z73 360mm AIO Cooler', brand: 'NZXT', specs: { 'Type' => 'Liquid Cooler (AIO)', 'Radiator Size' => '360mm', 'Fans' => '3x 120mm', 'TDP' => '250W', 'Display' => '2.36" LCD', 'Socket Compatibility' => 'LGA1700, AM5, AM4', 'Brand' => 'NZXT' } },
    { title: 'Arctic Liquid Freezer II 280', brand: 'Arctic', specs: { 'Type' => 'Liquid Cooler (AIO)', 'Radiator Size' => '280mm', 'Fans' => '2x 140mm', 'TDP' => '250W', 'Noise Level' => '22.5 dB(A)', 'Socket Compatibility' => 'LGA1700, AM5, AM4', 'Brand' => 'Arctic' } },
    { title: 'Thermalright Peerless Assassin 120 SE', brand: 'Thermalright', specs: { 'Type' => 'Air Cooler', 'Fan Size' => '2x 120mm', 'Height' => '155mm', 'TDP' => '200W', 'Noise Level' => '25.6 dB(A)', 'Socket Compatibility' => 'LGA1700, AM5, AM4', 'Brand' => 'Thermalright' } },
    { title: 'Arctic P12 PWM PST Fan 120mm', brand: 'Arctic', specs: { 'Type' => 'Case Fan', 'Size' => '120mm', 'Speed' => '200-1800 RPM', 'Airflow' => '56.3 CFM', 'Noise Level' => '22.5 dB(A)', 'Bearing' => 'Fluid Dynamic', 'Brand' => 'Arctic' } },
    { title: 'Noctua NF-A14 PWM Fan 140mm', brand: 'Noctua', specs: { 'Type' => 'Case Fan', 'Size' => '140mm', 'Speed' => '300-1500 RPM', 'Airflow' => '82.5 CFM', 'Noise Level' => '24.6 dB(A)', 'Bearing' => 'SSO2', 'Brand' => 'Noctua' } },
    { title: 'Thermal Grizzly Kryonaut Thermal Paste', brand: 'Thermal Grizzly', specs: { 'Type' => 'Thermal Paste', 'Thermal Conductivity' => '12.5 W/mK', 'Net Weight' => '1g', 'Temperature Range' => '-200 to 350C', 'Brand' => 'Thermal Grizzly' } },
    { title: 'Arctic MX-6 Thermal Paste', brand: 'Arctic', specs: { 'Type' => 'Thermal Paste', 'Thermal Conductivity' => '8.5 W/mK', 'Net Weight' => '4g', 'Temperature Range' => '-50 to 150C', 'Brand' => 'Arctic' } },
  ]

  cooling.each do |c|
    products << {
      'title' => c[:title],
      'brand' => c[:brand],
      'subcategory' => 'Cooling & Maintenance',
      'source' => 'manufacturer',
      'specifications' => c[:specs]
    }
  end
  log "  #{products.size} cooling products"
  products
end

# ── Internal Components ───────────────────────────────────────────────────────

def scrape_internal_components
  log "\n━━━ Internal Components ━━━"
  products = []

  components = [
    { title: 'Intel Core i9-14900K Processor', brand: 'Intel', specs: { 'Type' => 'CPU', 'Cores' => '24 (8P+16E)', 'Threads' => '32', 'Base Clock' => '3.2 GHz', 'Boost Clock' => '6.0 GHz', 'Cache' => '36MB L3', 'Socket' => 'LGA1700', 'TDP' => '125W', 'Brand' => 'Intel' } },
    { title: 'Intel Core i7-14700K Processor', brand: 'Intel', specs: { 'Type' => 'CPU', 'Cores' => '20 (8P+12E)', 'Threads' => '28', 'Base Clock' => '3.4 GHz', 'Boost Clock' => '5.6 GHz', 'Cache' => '33MB L3', 'Socket' => 'LGA1700', 'TDP' => '125W', 'Brand' => 'Intel' } },
    { title: 'AMD Ryzen 9 9950X Processor', brand: 'AMD', specs: { 'Type' => 'CPU', 'Cores' => '16', 'Threads' => '32', 'Base Clock' => '4.3 GHz', 'Boost Clock' => '5.7 GHz', 'Cache' => '64MB L3', 'Socket' => 'AM5', 'TDP' => '170W', 'Brand' => 'AMD' } },
    { title: 'AMD Ryzen 7 9700X Processor', brand: 'AMD', specs: { 'Type' => 'CPU', 'Cores' => '8', 'Threads' => '16', 'Base Clock' => '3.8 GHz', 'Boost Clock' => '5.5 GHz', 'Cache' => '32MB L3', 'Socket' => 'AM5', 'TDP' => '105W', 'Brand' => 'AMD' } },
    { title: 'NVIDIA GeForce RTX 4090 24GB', brand: 'NVIDIA', specs: { 'Type' => 'GPU', 'Memory' => '24GB GDDR6X', 'CUDA Cores' => '16384', 'Boost Clock' => '2520 MHz', 'Memory Bus' => '384-bit', 'TDP' => '450W', 'Interface' => 'PCIe 4.0 x16', 'Brand' => 'NVIDIA' } },
    { title: 'NVIDIA GeForce RTX 4080 Super 16GB', brand: 'NVIDIA', specs: { 'Type' => 'GPU', 'Memory' => '16GB GDDR6X', 'CUDA Cores' => '10240', 'Boost Clock' => '2550 MHz', 'Memory Bus' => '256-bit', 'TDP' => '320W', 'Interface' => 'PCIe 4.0 x16', 'Brand' => 'NVIDIA' } },
    { title: 'AMD Radeon RX 7900 XTX 24GB', brand: 'AMD', specs: { 'Type' => 'GPU', 'Memory' => '24GB GDDR6', 'Stream Processors' => '12288', 'Boost Clock' => '2500 MHz', 'Memory Bus' => '384-bit', 'TDP' => '355W', 'Interface' => 'PCIe 4.0 x16', 'Brand' => 'AMD' } },
    { title: 'Corsair Vengeance 32GB DDR5-6000', brand: 'Corsair', specs: { 'Type' => 'RAM', 'Capacity' => '32GB (2x16GB)', 'Speed' => '6000 MHz', 'Latency' => 'CL30', 'Voltage' => '1.35V', 'Type' => 'DDR5', 'Brand' => 'Corsair' } },
    { title: 'G.Skill Trident Z5 64GB DDR5-6400', brand: 'G.Skill', specs: { 'Type' => 'RAM', 'Capacity' => '64GB (2x32GB)', 'Speed' => '6400 MHz', 'Latency' => 'CL32', 'Voltage' => '1.40V', 'Type' => 'DDR5', 'Brand' => 'G.Skill' } },
    { title: 'ASUS ROG Strix Z790-E Motherboard', brand: 'Asus', specs: { 'Type' => 'Motherboard', 'Chipset' => 'Z790', 'Socket' => 'LGA1700', 'Form Factor' => 'ATX', 'RAM Slots' => '4x DDR5', 'M.2 Slots' => '5', 'PCIe' => 'PCIe 5.0 x16', 'Brand' => 'Asus' } },
    { title: 'MSI MAG B650 Tomahawk Motherboard', brand: 'MSI', specs: { 'Type' => 'Motherboard', 'Chipset' => 'B650', 'Socket' => 'AM5', 'Form Factor' => 'ATX', 'RAM Slots' => '4x DDR5', 'M.2 Slots' => '3', 'PCIe' => 'PCIe 5.0 x16', 'Brand' => 'MSI' } },
    { title: 'Corsair RM850e 850W 80+ Gold PSU', brand: 'Corsair', specs: { 'Type' => 'Power Supply', 'Wattage' => '850W', 'Efficiency' => '80+ Gold', 'Modular' => 'Fully Modular', 'Fan Size' => '120mm', 'ATX Standard' => 'ATX 3.0', 'Brand' => 'Corsair' } },
    { title: 'Seasonic PRIME TX-1000 1000W 80+ Titanium', brand: 'Seasonic', specs: { 'Type' => 'Power Supply', 'Wattage' => '1000W', 'Efficiency' => '80+ Titanium', 'Modular' => 'Fully Modular', 'Fan Size' => '135mm', 'ATX Standard' => 'ATX 3.0', 'Brand' => 'Seasonic' } },
  ]

  components.each do |c|
    products << {
      'title' => c[:title],
      'brand' => c[:brand],
      'subcategory' => 'Internal Components',
      'source' => 'manufacturer',
      'specifications' => c[:specs]
    }
  end
  log "  #{products.size} internal components"
  products
end

# ── Main ──────────────────────────────────────────────────────────────────────

existing = load_existing
all_products = []

scrapers = {
  'peripherals' => method(:scrape_logitech_products),
  'storage' => method(:scrape_storage),
  'networking' => method(:scrape_networking),
  'cooling' => method(:scrape_cooling),
  'internal' => method(:scrape_internal_components)
}

scrapers.each do |name, scraper|
  next if options[:category_filter] && !name.include?(options[:category_filter])
  all_products += scraper.call
end

existing_titles = Set.new(existing.map { |d| d['title'] })
new_products = all_products.reject { |d| existing_titles.include?(d['title']) }
final = existing + new_products

save_data(final)
log "\n🎉 Done! #{final.size} computer accessories (#{new_products.size} new) → #{OUT_FILE}"
