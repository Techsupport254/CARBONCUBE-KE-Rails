require 'net/http'
require 'json'
require 'uri'

class GsmArenaService
  BASE_URL = 'https://www.gsmarena.com'
  USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'

  # Main entry: search for a device, then scrape its full spec page.
  def self.fetch_device_specs(query)
    slug = search_device(query)
    return nil unless slug

    specs = scrape_device_page(slug)
    return nil unless specs && specs.any?

    brand = extract_brand_from_name(specs['modelname'] || query)

    {
      title: specs['modelname'] || query.titleize,
      brand: brand,
      specifications: map_to_jiji_keys(specs)
    }
  rescue StandardError => e
    Rails.logger.error "GsmArenaService error: #{e.message}"
    nil
  end

  private

  # Step 1: Search gsmarena for the device and return the first result slug.
  def self.search_device(query)
    uri = URI("#{BASE_URL}/results.php3?sQuickSearch=yes&sName=#{URI.encode_www_form_component(query)}")
    html = get_html(uri)
    return nil unless html

    # Extract first device link from search results, e.g. samsung_galaxy_s24_ultra-12771.php
    match = html.match(/href="([a-z0-9_\-]+-\d+\.php)"/)
    match ? match[1] : nil
  end

  # Step 2: Scrape the device page and extract all data-spec values.
  def self.scrape_device_page(slug)
    uri = URI("#{BASE_URL}/#{slug}")
    html = get_html(uri)
    return nil unless html

    specs = {}
    # Extract all data-spec="key">value</span> pairs
    html.scan(/data-spec="([^"]+)"[^>]*>([^<]*)</).each do |key, value|
      val = value.strip
      specs[key] = val if val.present?
    end

    specs
  end

  # Map raw GSMArena data-spec keys → Jiji-style UI keys.
  def self.map_to_jiji_keys(raw)
    mapped = {}

    # Screen Size
    if raw['displaysize-hl'].present?
      mapped['Screen Size (inches)'] = raw['displaysize-hl'].gsub('"', '').strip
    elsif raw['displaysize'].present?
      size = raw['displaysize'].match(/([\d.]+)\s*inches/)
      mapped['Screen Size (inches)'] = size[1] if size
    end

    # RAM
    if raw['ramsize-hl'].present?
      mapped['Ram'] = "#{raw['ramsize-hl']} GB"
    elsif raw['internalmemory'].present?
      ram = raw['internalmemory'].match(/(\d+)\s*GB\s*RAM/)
      mapped['Ram'] = "#{ram[1]} GB" if ram
    end

    # Internal Storage
    if raw['storage-hl'].present?
      storage = raw['storage-hl'].match(/([\d\/]+(?:GB|TB)[^\s,]*)/)
      mapped['Internal Storage'] = storage[1] if storage
    elsif raw['internalmemory'].present?
      parts = raw['internalmemory'].split(',').map(&:strip)
      storages = parts.map { |p| p.match(/^(\d+(?:GB|TB))/) }.compact.map { |m| m[1] }
      mapped['Internal Storage'] = storages.uniq.join(' / ') if storages.any?
    end

    # Color
    if raw['colors'].present?
      mapped['Color'] = raw['colors'].split(',').first.strip
    end

    # Operating System
    if raw['os'].present?
      mapped['Operating System'] = raw['os']
    elsif raw['os-hl'].present?
      mapped['Operating System'] = raw['os-hl']
    end

    # Display Type
    mapped['Display Type'] = raw['displaytype'] if raw['displaytype'].present?

    # Resolution
    if raw['displayresolution'].present?
      res = raw['displayresolution'].match(/([\dx ]+pixels)/)
      mapped['Resolution'] = res[1].strip if res
    elsif raw['displayres-hl'].present?
      mapped['Resolution'] = raw['displayres-hl']
    end

    # SIM
    if raw['sim'].present?
      sim_val = raw['sim'].gsub('·', '').strip
      mapped['SIM'] = sim_val if sim_val.present?
    end

    # Card Slot
    mapped['Card Slot'] = raw['memoryslot'] if raw['memoryslot'].present?

    # Main Camera
    if raw['cam1modules'].present?
      # Extract just megapixel values like "200 MP"
      cams = raw['cam1modules'].match(/^(\d+\s*MP)/)
      mapped['Main Camera'] = cams ? cams[1] : raw['cam1modules'].split(',').first.strip
    elsif raw['camerapixels-hl'].present?
      mapped['Main Camera'] = "#{raw['camerapixels-hl']} MP"
    end

    # Selfie Camera
    if raw['cam2modules'].present?
      cams = raw['cam2modules'].match(/^(\d+\s*MP)/)
      mapped['Selfie Camera'] = cams ? cams[1] : raw['cam2modules'].split(',').first.strip
    end

    # Battery
    if raw['batsize-hl'].present?
      mapped['Battery (mAh)'] = raw['batsize-hl']
    elsif raw['batdescription1'].present?
      bat = raw['batdescription1'].match(/(\d+)\s*mAh/)
      mapped['Battery (mAh)'] = bat[1] if bat
    end

    # Features (sensors)
    if raw['sensors'].present?
      mapped['Features'] = raw['sensors']
    end

    # --- New fields ---

    # Chipset
    if raw['chipset-hl'].present?
      mapped['Chipset'] = raw['chipset-hl']
    elsif raw['chipset'].present?
      mapped['Chipset'] = raw['chipset']
    end

    # CPU
    if raw['cpu-hl'].present?
      mapped['CPU'] = raw['cpu-hl']
    elsif raw['cpu'].present?
      mapped['CPU'] = raw['cpu']
    end

    # GPU
    if raw['gpu-hl'].present?
      mapped['GPU'] = raw['gpu-hl']
    elsif raw['gpu'].present?
      mapped['GPU'] = raw['gpu']
    end

    # Network (2G/3G/4G/5G) — GSMArena key is 'nettech'
    if raw['nettech'].present?
      mapped['Network'] = raw['nettech'].strip
    end

    # Charging — GSMArena key is 'batdescription2'
    if raw['batdescription2'].present?
      # First line is usually the summary (e.g. "45W wired, 15W wireless")
      charging_line = raw['batdescription2'].split("\n").first.strip
      mapped['Charging'] = charging_line if charging_line.present?
    elsif raw['batdescription1'].present?
      # Fallback: regex for wattage mention inside the battery description
      charge_match = raw['batdescription1'].match(/(\d+W[^,\n]*)/i)
      mapped['Charging'] = charge_match[1].strip if charge_match
    end

    # NFC
    mapped['NFC'] = raw['nfc'] if raw['nfc'].present?

    # USB
    mapped['USB'] = raw['usb'] if raw['usb'].present?

    # Bluetooth
    mapped['Bluetooth'] = raw['bluetooth'] if raw['bluetooth'].present?

    # WiFi
    if raw['wlan'].present?
      mapped['WiFi'] = raw['wlan'].gsub('·', '').strip
    end

    # Protection
    mapped['Protection'] = raw['displayprotection'] if raw['displayprotection'].present?

    # Water Resistance — IP rating is in 'bodyother' on GSMArena
    ip_source = [raw['bodyother'], raw['protection'], raw['body']].compact.find { |v| v.match?(/IP\d/i) }
    if ip_source
      ip_match = ip_source.match(/(IP\d{2}(?:[\/\s]\d{2})?)/i)
      mapped['Water Resistance'] = ip_match ? ip_match[1].upcase : ip_source.split('.').first.strip
    end

    # Release/Announcement dates
    if raw['announced'].present?
      mapped['Announcement Date'] = raw['announced']
    end
    if raw['status'].present?
      mapped['Status'] = raw['status']
    end

    mapped
  end

  def self.extract_brand_from_name(name)
    name.to_s.split(' ').first || 'Unknown'
  end

  def self.get_html(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 8
    http.open_timeout = 5

    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = USER_AGENT
    request['Accept'] = 'text/html,application/xhtml+xml'
    request['Accept-Language'] = 'en-US,en;q=0.9'

    response = http.request(request)
    # Follow one redirect if needed
    if response.is_a?(Net::HTTPRedirection) && response['location']
      redirect_uri = URI(response['location'])
      redirect_uri = URI("#{uri.scheme}://#{uri.host}#{response['location']}") unless redirect_uri.host
      return get_html(redirect_uri)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)
    body = response.body
    body = body.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.encoding == Encoding::UTF_8
    body
  rescue StandardError => e
    Rails.logger.error "GsmArenaService HTTP error: #{e.message}"
    nil
  end
end
