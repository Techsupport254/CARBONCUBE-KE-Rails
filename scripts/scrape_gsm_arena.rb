#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# GSMArena Phone Scraper — Major Brands
# =============================================================================
# Scrapes: Samsung, Apple, Xiaomi, Huawei, OPPO, OnePlus, Nokia, Realme,
#          Google, Motorola, Sony, Vivo
# Output : scripts/output/phones.json
# Resume : scripts/output/checkpoint.json
#
# Usage:
#   ruby scripts/scrape_gsm_arena.rb                   # all brands below
#   ruby scripts/scrape_gsm_arena.rb --brand Apple     # single brand
#   ruby scripts/scrape_gsm_arena.rb --limit 50        # cap at N phones
#   ruby scripts/scrape_gsm_arena.rb --reset           # wipe & restart
# =============================================================================

require 'net/http'
require 'json'
require 'uri'
require 'set'
require 'fileutils'
require 'optparse'

# ── Hardcoded popular brands (name → GSMArena brand page slug) ────────────────
BRANDS = [
  { name: 'Samsung',  slug: 'samsung-phones-9.php'    },
  { name: 'Apple',    slug: 'apple-phones-48.php'     },
  { name: 'Xiaomi',   slug: 'xiaomi-phones-80.php'    },
  { name: 'Tecno',    slug: 'tecno-phones-120.php'    },
  { name: 'Infinix',  slug: 'infinix-phones-119.php'  },
  { name: 'itel',     slug: 'itel-phones-131.php'     },
  { name: 'Oppo',     slug: 'oppo-phones-82.php'      },
  { name: 'Vivo',     slug: 'vivo-phones-98.php'      },
  { name: 'Realme',   slug: 'realme-phones-118.php'   },
  { name: 'Huawei',   slug: 'huawei-phones-58.php'    },
  { name: 'OnePlus',  slug: 'oneplus-phones-95.php'   },
  { name: 'Nokia',    slug: 'nokia-phones-1.php'      },
  { name: 'HMD',      slug: 'hmd-phones-130.php'      },
  { name: 'Nothing',  slug: 'nothing-phones-128.php'  },
  { name: 'ZTE',      slug: 'zte-phones-62.php'       },
  { name: 'Motorola', slug: 'motorola-phones-8.php'    },
  { name: 'TCL',      slug: 'tcl-phones-123.php'      },
  { name: 'Sony',     slug: 'sony-phones-7.php'       },
  { name: 'Google',   slug: 'google-phones-107.php'   },
  { name: 'Honor',    slug: 'honor-phones-121.php'    },
  { name: 'Asus',     slug: 'asus-phones-46.php'      },
  { name: 'Lenovo',   slug: 'lenovo-phones-73.php'    },
  { name: 'Blackview', slug: 'blackview-phones-116.php' },
  { name: 'Meizu',    slug: 'meizu-phones-74.php'     },
  { name: 'HTC',      slug: 'htc-phones-45.php'       },
  { name: 'LG',       slug: 'lg-phones-20.php'        },
  { name: 'BlackBerry', slug: 'blackberry-phones-36.php' },
  { name: 'Alcatel',  slug: 'alcatel-phones-5.php'     },
  { name: 'Energizer', slug: 'energizer-phones-106.php' },
  { name: 'Cat',       slug: 'cat-phones-89.php'       },
  { name: 'Microsoft', slug: 'microsoft-phones-64.php' },
  { name: 'Kyocera',  slug: 'kyocera-phones-17.php'    },
  { name: 'Panasonic', slug: 'panasonic-phones-6.php'   },
  { name: 'BLU',       slug: 'blu-phones-67.php'       },
  { name: 'Nvidia',    slug: 'nvidia-phones-105.php'   },
  { name: 'Casio',     slug: 'casio-phones-12.php'      },
  { name: 'Icemobile', slug: 'icemobile-phones-69.php'  },
  { name: 'Yezz',      slug: 'yezz-phones-78.php'       },
  { name: 'Lava',      slug: 'lava-phones-94.php'       },
  { name: 'Micromax',  slug: 'micromax-phones-66.php'   },
  { name: 'Intex',     slug: 'intex-phones-90.php'      },
  { name: 'Spice',     slug: 'spice-phones-68.php'      },
  { name: 'XOLO',      slug: 'xolo-phones-85.php'       },
  { name: 'O2',        slug: 'o2-phones-30.php'         },
  { name: 'Virgin',    slug: 'virgin-phones-35.php'     },
  { name: 'Palm',      slug: 'palm-phones-27.php'       },
].freeze

BASE_URL   = 'https://www.gsmarena.com'
OUTPUT_DIR = File.expand_path('output', __dir__)
OUT_FILE   = File.join(OUTPUT_DIR, 'phones.json')
CKP_FILE   = File.join(OUTPUT_DIR, 'checkpoint.json')
LOG_FILE   = File.join(OUTPUT_DIR, 'scrape.log')

# Delays for normal operation
MIN_DELAY  = 1.0
MAX_DELAY  = 3.0

USER_AGENTS = [
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
].freeze

# ── CLI ───────────────────────────────────────────────────────────────────────
options = { brand_filter: nil, limit: nil, reset: false }
OptionParser.new do |opts|
  opts.on('--brand NAME', 'Scrape only this brand')             { |v| options[:brand_filter] = v.downcase }
  opts.on('--limit N',   Integer, 'Stop after N phones total')  { |v| options[:limit] = v }
  opts.on('--reset',     'Delete checkpoint and start fresh')   { options[:reset] = true }
end.parse!

FileUtils.mkdir_p(OUTPUT_DIR)

# ── Logging ───────────────────────────────────────────────────────────────────
def log(msg)
  line = "[#{Time.now.strftime('%H:%M:%S')}] #{msg}"
  puts line
  File.open(LOG_FILE, 'a') { |f| f.puts(line) }
end

# ── HTTP / Proxy / Tor ───────────────────────────────────────────────────────
PROXY_URL   = ENV['SCRAPE_PROXY'] || 'socks5h://127.0.0.1:9050'
TOR_CONTROL = '127.0.0.1'        # Port 9051 by default

def rotate_tor_ip
  require 'socket'
  begin
    TCPSocket.open(TOR_CONTROL, 9051) do |s|
      s.puts "AUTHENTICATE \"\"" # Assumes no password config or cookie auth handles it
      s.puts "SIGNAL NEWNYM"
      s.puts "QUIT"
    end
    log "  🔄 Tor IP rotation requested (SIGNAL NEWNYM)"
    true
  rescue => e
    # Silently fail if Tor control isn't setup
    false
  end
end

def polite_sleep
  sleep(MIN_DELAY + rand * (MAX_DELAY - MIN_DELAY))
end

def fetch_html(url, retries: 5, rotation_count: 0)
  uri = URI(url)
  attempt = 0
  
  begin
    attempt += 1
    
    # Construct curl command
    # -w "%{http_code}": print http status code at the end
    cmd = ["curl", "-L", "-s", "-w", "\sHTTP_CODE:%{http_code}", "-A", USER_AGENTS.sample]
    cmd += ["-H", "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"]
    cmd += ["-H", "Accept-Language: en-US,en;q=0.9"]
    cmd += ["-H", "Referer: #{BASE_URL}"]
    cmd += ["--connect-timeout", "15", "--max-time", "30"]
    cmd += ["-x", PROXY_URL] if PROXY_URL && !PROXY_URL.empty?
    cmd << url

    # Capture output and status
    require 'open3'
    stdout, stderr, status = Open3.capture3(*cmd)

    if status.success?
      # Extract HTTP code from the end of stdout
      http_code = stdout[/HTTP_CODE:(\d+)$/i, 1].to_i
      html_content = stdout.sub(/HTTP_CODE:\d+$/i, '')
      
      decoded = html_content.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') rescue html_content
      
      # Detect CAPTCHA / Rate Limit / Cloudflare / 429
      is_blocked = (http_code == 429) || 
                   decoded.include?('Turnstile check') || 
                   decoded.include?('Just a moment...') ||
                   decoded.include?('verifying you are human') ||
                   decoded.include?('checking your browser') ||
                   decoded.include?('Too Many Requests') ||
                   (decoded.size < 600 && decoded.include?('Cloudflare')) ||
                   (decoded.size < 500 && !decoded.empty?) # Short body but not network error
      
      if is_blocked
        reason = (http_code == 429) ? "HTTP 429 Rate Limit" : "CAPTCHA/Block"
        log "  🛑  #{reason} detected at #{Time.now.strftime('%H:%M:%S')}"
        
        if rotation_count >= 6
          # If we have rotated 6 times (3 normally + 3 after long cooling),
          # this URL is systemically blocked or the server is extremely angry.
          # Return nil to let the brand loop skip this one and move on.
          log "  ❌ Giving up on #{url} after multiple rotations and long cooling."
          return nil
        elsif rotation_count == 3
          # First long cooling attempt
          wait_time = 600
          log "  ⚠️  Rotation limit (3) reached for this URL. Long cooling for #{wait_time/60} mins..."
          sleep(wait_time)
          return fetch_html(url, retries: retries, rotation_count: rotation_count + 1)
        else
          rotated = rotate_tor_ip
          wait_time = rotated ? 15 : 30 # 15s after rotation to let circuit stabilize
          log "  💤  Waiting #{wait_time}s to retry #{url}..."
          sleep(wait_time)
          return fetch_html(url, retries: retries, rotation_count: rotation_count + 1)
        end
      end

      return decoded
    end

    # Handle Errors (status != 0 typically means timeout or proxy error)
    raise "Curl failed with status #{status.exitstatus}: #{stderr.strip}"

  rescue => e
    if attempt < retries
      wait = 10 * attempt
      log "  ⚠️  #{e.message} — retry #{attempt}/#{retries} in #{wait}s"
      sleep(wait)
      retry
    end
    log "  ❌ Critical Failure after #{retries} retries: #{url} — #{e.message}"
    nil
  end
end
# ── Checkpoint / file helpers ─────────────────────────────────────────────────
def load_checkpoint(path)     = File.exist?(path) ? (JSON.parse(File.read(path)) rescue {}) : {}
def save_checkpoint(path, d)  = File.write(path, JSON.pretty_generate(d))
def load_phones(path)
  return [] unless File.exist?(path) && !File.zero?(path)
  begin
    data = JSON.parse(File.read(path))
    # CRITICAL: Filter out any invalid legacy entries with 0 specs
    valid = data.reject { |p| p['specifications'].nil? || p['specifications'].empty? }
    if valid.size < data.size
      log "  🧹 Cleaned up #{data.size - valid.size} invalid (0 specs) entries from #{File.basename(path)}"
      File.write(path, JSON.pretty_generate(valid))
    end
    valid
  rescue JSON::ParserError
    []
  end
end
def append_phone(path, phone)
  phones = load_phones(path)
  phones << phone
  File.write(path, JSON.pretty_generate(phones))
end

# ── Brand listing page: extract device slugs ──────────────────────────────────
# Real HTML: <li><a href="samsung_galaxy_s26_ultra-14320.php"><img ...><strong><span>Galaxy S26 Ultra</span></strong></a></li>
def scrape_brand_page(html, brand_name)
  devices   = []
  makers_section = html[/<div class="makers">(.*?)<\/div>/m, 1] || html

  makers_section.scan(/<a href="([a-z0-9_+\-]+-\d+\.php)"[^>]*>.*?<strong>\s*<span>([^<]+)<\/span>/im) do |slug, name|
    devices << { 'slug' => slug.strip, 'title' => name.strip, 'brand' => brand_name }
  end

  # Next page: GSMArena uses href="brand-phones-9-0-p2.php" pattern
  # The » (next) anchor tends to have class="pages-next" or be near page links
  next_page = nil
  # Look for explicit next-page anchor
  if (m = html.match(/href="([^"]+)"[^>]*>\s*(?:»|›|Next)/i))
    next_page = "#{BASE_URL}/#{m[1]}" unless m[1].start_with?('http')
  end
  # Also try numbered page links: find highest page number link
  if next_page.nil?
    pages = html.scan(/href="([^"]+)"/).flatten
                .select { |h| h.match?(/-p\d+\.php/) }
    # current page can be derived from the URL itself — just collect candidates
    # We'll track page num externally
  end

  { devices: devices, next_page_url: next_page }
end

# ── Spec page: extract all data-spec pairs ────────────────────────────────────
def scrape_specs(html)
  specs = {}
  html.scan(/data-spec="([^"]+)"[^>]*>([^<]*)</).each do |key, val|
    v = val.strip
    specs[key] = v unless v.empty?
  end
  title_m = html.match(/<h1 class="specs-phone-name-title"[^>]*>([^<]+)</)
  specs['modelname'] = title_m[1].strip if title_m
  specs
end

# ── Map raw GSMArena keys → our spec keys ─────────────────────────────────────
def map_specs(raw)
  m = {}

  # Display
  if raw['displaysize-hl'].to_s.strip.length > 0
    m['Screen Size (inches)'] = raw['displaysize-hl'].gsub('"', '').strip
  elsif raw['displaysize'].to_s =~ /([\d.]+)\s*inches/i
    m['Screen Size (inches)'] = $1
  end
  m['Display Type'] = raw['displaytype'].strip        if raw['displaytype'].to_s.strip.length > 0
  if raw['displayresolution'].to_s =~ /([\dx ]+pixels)/i
    m['Resolution'] = $1.strip
  elsif raw['displayres-hl'].to_s.strip.length > 0
    m['Resolution'] = raw['displayres-hl'].strip
  end
  m['Protection'] = raw['displayprotection'].strip    if raw['displayprotection'].to_s.strip.length > 0

  # Platform
  chipset_val = [raw['chipset-hl'], raw['chipset']].find { |v| v.to_s.strip.length > 0 }
  m['Chipset'] = chipset_val.strip if chipset_val
  cpu_val = [raw['cpu-hl'], raw['cpu']].find { |v| v.to_s.strip.length > 0 }
  m['CPU'] = cpu_val.strip if cpu_val
  gpu_val = [raw['gpu-hl'], raw['gpu']].find { |v| v.to_s.strip.length > 0 }
  m['GPU'] = gpu_val.strip if gpu_val

  # Memory (Ram)
  if raw['ramsize-hl'].to_s.strip.length > 0
    val = raw['ramsize-hl'].strip
    # Extract numerical value to guess unit
    first_num = val.match(/[\d\.]+/).to_s.to_f
    # Check if internalmemory explicitly states MB
    is_mb = raw['internalmemory'].to_s.upcase.include?('MB RAM') || (first_num >= 64 && first_num < 1000 && !raw['internalmemory'].to_s.upcase.include?('GB RAM'))
    m['Ram'] = is_mb ? "#{val} MB" : "#{val} GB"
  elsif raw['internalmemory'].to_s =~ /(\d+)\s*(MB|GB)\s*RAM/i
    m['Ram'] = "#{$1} #{$2.upcase}"
  end

  # Internal Storage
  if raw['storage-hl'].to_s.strip.length > 0
    sm = raw['storage-hl'].match(/([\d\/\.]+(?:MB|GB|TB)[^\s,]*)/i)
    if sm
      m['Internal Storage'] = sm[1]
    else
      # no unit in storage-hl?
      val = raw['storage-hl'].strip
      first_num = val.match(/[\d\.]+/).to_s.to_f
      is_mb = raw['internalmemory'].to_s.upcase.include?("MB") || (first_num >= 64 && first_num < 2000)
      m['Internal Storage'] = is_mb ? "#{val} MB" : "#{val} GB"
    end
  elsif raw['internalmemory'].to_s.strip.length > 0
    parts = raw['internalmemory'].split(',').map(&:strip)
    storages = parts.map { |p| p.match(/^(\d+(?:MB|GB|TB))/i) }.compact.map { |x| x[1] }
    m['Internal Storage'] = storages.uniq.join('/') if storages.any?
  end
  m['Card Slot'] = raw['memoryslot'].strip            if raw['memoryslot'].to_s.strip.length > 0

  # Camera
  if raw['cam1modules'].to_s.strip.length > 0
    cam = raw['cam1modules'].match(/^(\d+\s*MP)/)
    m['Main Camera'] = cam ? cam[1] : raw['cam1modules'].split(',').first.strip
  elsif raw['camerapixels-hl'].to_s.strip.length > 0
    m['Main Camera'] = "#{raw['camerapixels-hl'].strip} MP"
  end
  if raw['cam2modules'].to_s.strip.length > 0
    cam2 = raw['cam2modules'].match(/^(\d+\s*MP)/)
    m['Selfie Camera'] = cam2 ? cam2[1] : raw['cam2modules'].split(',').first.strip
  end

  # Battery
  if raw['batsize-hl'].to_s.strip.length > 0
    m['Battery (mAh)'] = raw['batsize-hl'].strip
  elsif raw['batdescription1'].to_s =~ /(\d+)\s*mAh/i
    m['Battery (mAh)'] = $1
  end
  if raw['batdescription2'].to_s.strip.length > 0
    cl = raw['batdescription2'].split("\n").first.strip
    m['Charging'] = cl unless cl.empty?
  elsif raw['batdescription1'].to_s =~ /(\d+W[^,\n]*)/i
    m['Charging'] = $1.strip
  end

  # Connectivity
  m['Network']   = raw['nettech'].strip               if raw['nettech'].to_s.strip.length > 0
  if raw['sim'].to_s.strip.length > 0
    sv = raw['sim'].gsub('·', '').strip
    m['SIM'] = sv unless sv.empty?
  end
  m['NFC']       = raw['nfc'].strip                   if raw['nfc'].to_s.strip.length > 0
  m['USB']       = raw['usb'].strip                   if raw['usb'].to_s.strip.length > 0
  m['Bluetooth'] = raw['bluetooth'].split("\n").first.strip if raw['bluetooth'].to_s.strip.length > 0
  if raw['wlan'].to_s.strip.length > 0
    m['WiFi'] = raw['wlan'].gsub('·', '').split("\n").first.strip
  end

  # OS
  os_val = [raw['os'], raw['os-hl']].find { |v| v.to_s.strip.length > 0 }
  m['Operating System'] = os_val.strip if os_val

  # Colors / sensors
  m['Color']    = raw['colors'].strip                  if raw['colors'].to_s.strip.length > 0
  m['Features'] = raw['sensors'].strip                 if raw['sensors'].to_s.strip.length > 0

  # Water Resistance — IP rating lives in bodyother
  ip_src = [raw['bodyother'], raw['protection'], raw['body']].compact.find { |v| v.to_s =~ /IP\d/i }
  if ip_src
    ip_m = ip_src.match(/(IP\d{2}(?:[\/\s]\d{2})?)/i)
    m['Water Resistance'] = ip_m ? ip_m[1].upcase : ip_src.split('.').first.strip
  end

  # Release
  m['Announcement Date'] = raw['announce-hl'].strip   if raw['announce-hl'].to_s.strip.length > 0
  m['Status']            = raw['status'].strip         if raw['status'].to_s.strip.length > 0

  m.reject { |_, v| v.to_s.strip.empty? }
end

# ── Paginate a brand: return ALL device stubs across all pages ────────────────
# GSMArena URL pattern:
#   Page 1 : samsung-phones-9.php
#   Page 2 : samsung-phones-f-9-0-p2.php
#   Page N : samsung-phones-f-9-0-pN.php
def collect_all_devices_for_brand(brand_name, start_url)
  all_devices = []

  # Extract brand slug prefix and numeric ID
  # e.g. "samsung-phones-9" → prefix="samsung-phones", id="9"
  m = start_url.match(/([a-z0-9_-]+-phones)-(\d+)\.php$/i)
  unless m
    log "  ❌ Could not parse brand base from #{start_url}"
    return []
  end
  prefix, brand_id = m[1], m[2]

  page = 1
  loop do
    url = if page == 1
      start_url
    else
      "#{BASE_URL}/#{prefix}-f-#{brand_id}-0-p#{page}.php"
    end

    polite_sleep
    log "  📄 Page #{page} — #{url}"
    html = fetch_html(url)

    unless html
      log "  ⚠️  Page #{page} fetch failed — stopping pagination"
      break
    end

    devices = scrape_brand_page(html, brand_name)[:devices]
    log "  → #{devices.size} devices"

    # Empty page = past the last page
    break if devices.empty?

    all_devices.concat(devices)
    page += 1
    break if page > 100  # safety cap
  end

  log "  📱 #{all_devices.size} total devices across #{page - 1} page(s)"
  all_devices.uniq { |d| d['slug'] }
end

# ── Main ──────────────────────────────────────────────────────────────────────
log '=' * 65
log "GSMArena Scraper — #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
log "Brands : #{BRANDS.map { |b| b[:name] }.join(', ')}"
log "Output : #{OUT_FILE}"
log '=' * 65

if options[:reset]
  [CKP_FILE, OUT_FILE].each { |f| File.delete(f) if File.exist?(f) }
  log '🔄 Reset — starting fresh'
end

checkpoint    = load_checkpoint(CKP_FILE)
phones        = load_phones(OUT_FILE)
done_slugs    = Set.new(phones.map { |p| p['slug'] })
done_brands   = Set.new(checkpoint['done_brands'] || [])
total_saved   = phones.size
count_this_session = 0

log "Resuming: #{total_saved} phones saved, #{done_slugs.size} slugs done\n"

brands_to_run = BRANDS.dup
brands_to_run = brands_to_run.select { |b| b[:name].downcase.include?(options[:brand_filter]) } if options[:brand_filter]

brands_to_run.each_with_index do |brand, bi|
  name = brand[:name]
  url  = "#{BASE_URL}/#{brand[:slug]}"

  if done_brands.include?(name) && !options[:brand_filter]
    next
  end

  log "\n[#{bi+1}/#{brands_to_run.size}] ━━━ #{name} ━━━ #{url}"

  # Step 1: collect all device slugs for this brand (all pages)
  brand_devices = collect_all_devices_for_brand(name, url)
  log "  📱 #{brand_devices.size} total devices found for #{name}"

  pending = brand_devices.reject { |d| done_slugs.include?(d['slug']) }
  log "  ⏭  #{brand_devices.size - pending.size} already done — #{pending.size} to scrape"

  pending.each_with_index do |device, di|
    spec_url  = "#{BASE_URL}/#{device['slug']}"
    
    # Random polite sleep between individual phone fetches
    sleep(0.5 + rand(1.0))
    
    spec_html = fetch_html(spec_url)
    unless spec_html
      log "    ⚠️  [#{di+1}/#{pending.size}] Skip (fetch failed): #{device['slug']}"
      next
    end

    raw   = scrape_specs(spec_html)
    specs = map_specs(raw)

    if specs.empty?
      log "    🛑  Zero specs extracted for #{device['title']}. Content might be blocked."
      rotated = rotate_tor_ip
      sleep(rotated ? 15 : 30)
      # We don't save or mark as done, so it will be retried
      next
    end

    phone = {
      'title'          => raw['modelname'] || device['title'],
      'slug'           => device['slug'],
      'brand'          => name,
      'gsmarena_url'   => spec_url,
      'specifications' => specs,
      'scraped_at'     => Time.now.strftime('%Y-%m-%d %H:%M:%S')
    }

    append_phone(OUT_FILE, phone)
    done_slugs    << device['slug']
    total_saved   += 1
    count_this_session += 1

    log "    ✅ [#{total_saved}] #{phone['title']} (#{specs.size} specs)"

    if options[:limit] && count_this_session >= options[:limit]
      log "\n🏁 Limit of #{options[:limit]} session items reached. Stopping."
      exit(0)
    end
  end

  # Step 2: mark as done if we actually have all devices for this brand
  # This ensures that if we have network failures during some models, 
  # next time we run, we'll re-scan the brand but skip the models we already have
  all_done = brand_devices.all? { |d| done_slugs.include?(d['slug']) }
  
  if brand_devices.any? && all_done
    done_brands << name
    checkpoint['done_brands'] = done_brands.to_a
    save_checkpoint(CKP_FILE, checkpoint)
    log "  ✅ #{name} fully completed!"
  else
    log "  ⚠️  #{name} has #{brand_devices.size - (brand_devices.count { |d| done_slugs.include?(d['slug']) })} pending or failed models. Leaving as pending."
  end
end

log "\n🎉 All done! #{total_scraped} phones saved → #{OUT_FILE}"
