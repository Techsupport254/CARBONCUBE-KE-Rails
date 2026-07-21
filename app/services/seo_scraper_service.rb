require 'net/http'
require 'uri'
require 'timeout'
require 'nokogiri'

class SeoScraperService
  TIMEOUT_SECONDS = 10
  MAX_REDIRECTS = 5
  MAX_CONTENT_LENGTH = 5_000_000 # 5MB

  def initialize(url)
    @url = url
    @uri = URI.parse(url)
  end

  def analyze
    return error_result('Invalid URL') unless valid_url?

    start_time = Time.now

    begin
      response = fetch_with_redirects(@uri, 0)
      load_time = ((Time.now - start_time) * 1000).round

      return error_result("HTTP #{response.code}", load_time) unless response.is_a?(Net::HTTPSuccess)

      body = response.body
      doc = Nokogiri::HTML(body)

      {
        success: true,
        url: @url,
        final_url: response.respond_to?(:uri) ? response.uri.to_s : @url,
        http_status: response.code.to_i,
        load_time_ms: load_time,
        content_type: response['content-type'],
        title: extract_title(doc),
        description: extract_meta(doc, 'description'),
        keywords: extract_meta(doc, 'keywords'),
        canonical: extract_canonical(doc),
        robots: extract_meta(doc, 'robots'),
        og_data: extract_og_data(doc),
        twitter_data: extract_twitter_data(doc),
        headings: extract_headings(doc),
        images: extract_image_info(doc),
        links: extract_link_info(doc, @uri),
        word_count: extract_word_count(doc),
        schema_data: extract_schema_data(doc),
        lang: doc.at('html')&.attr('lang'),
        viewport: extract_meta(doc, 'viewport'),
        favicon: extract_favicon(doc, @uri),
        score: calculate_seo_score(doc)
      }
    rescue Timeout::Error
      error_result('Request timed out')
    rescue => e
      error_result(e.message)
    end
  end

  private

  def valid_url?
    @uri.is_a?(URI::HTTP) || @uri.is_a?(URI::HTTPS)
  rescue
    false
  end

  def fetch_with_redirects(uri, redirect_count)
    return error_result('Too many redirects') if redirect_count >= MAX_REDIRECTS

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = TIMEOUT_SECONDS
    http.open_timeout = TIMEOUT_SECONDS

    request = Net::HTTP::Get.new(uri.request_uri, {
      'User-Agent' => 'Mozilla/5.0 (compatible; CentiMarketSEOBot/1.0)',
      'Accept' => 'text/html,application/xhtml+xml',
      'Accept-Language' => 'en-US,en;q=0.9'
    })

    response = http.request(request)

    if response.is_a?(Net::HTTPRedirection)
      location = response['location']
      new_uri = location.start_with?('http') ? URI.parse(location) : URI.join(uri, location)
      fetch_with_redirects(new_uri, redirect_count + 1)
    else
      response
    end
  end

  def extract_title(doc)
    title = doc.at('title')
    og_title = doc.at('meta[property="og:title"]')
    title&.text&.strip || og_title&.attr('content')&.strip
  end

  def extract_meta(doc, name)
    tag = doc.at("meta[name='#{name}']") || doc.at("meta[property='#{name}']")
    tag&.attr('content')&.strip
  end

  def extract_canonical(doc)
    link = doc.at("link[rel='canonical']")
    link&.attr('href')&.strip
  end

  def extract_og_data(doc)
    {
      title: doc.at('meta[property="og:title"]')&.attr('content')&.strip,
      description: doc.at('meta[property="og:description"]')&.attr('content')&.strip,
      image: doc.at('meta[property="og:image"]')&.attr('content')&.strip,
      url: doc.at('meta[property="og:url"]')&.attr('content')&.strip,
      type: doc.at('meta[property="og:type"]')&.attr('content')&.strip,
      site_name: doc.at('meta[property="og:site_name"]')&.attr('content')&.strip,
      locale: doc.at('meta[property="og:locale"]')&.attr('content')&.strip
    }.compact
  end

  def extract_twitter_data(doc)
    {
      card: doc.at('meta[name="twitter:card"]')&.attr('content')&.strip,
      title: doc.at('meta[name="twitter:title"]')&.attr('content')&.strip,
      description: doc.at('meta[name="twitter:description"]')&.attr('content')&.strip,
      image: doc.at('meta[name="twitter:image"]')&.attr('content')&.strip,
      site: doc.at('meta[name="twitter:site"]')&.attr('content')&.strip,
      creator: doc.at('meta[name="twitter:creator"]')&.attr('content')&.strip
    }.compact
  end

  def extract_headings(doc)
    {
      h1: doc.css('h1').map(&:text).map(&:strip).reject(&:empty?),
      h2: doc.css('h2').map(&:text).map(&:strip).reject(&:empty?),
      h3: doc.css('h3').map(&:text).map(&:strip).reject(&:empty?),
      h4_count: doc.css('h4').size,
      h5_count: doc.css('h5').size,
      h6_count: doc.css('h6').size
    }
  end

  def extract_image_info(doc)
    images = doc.css('img')
    {
      total: images.size,
      with_alt: images.select { |img| img.attr('alt')&.strip&.present? }.size,
      without_alt: images.reject { |img| img.attr('alt')&.strip&.present? }.size,
      with_title: images.select { |img| img.attr('title')&.strip&.present? }.size
    }
  end

  def extract_link_info(doc, base_uri)
    links = doc.css('a[href]')
    internal = 0
    external = 0
    nofollow = 0

    links.each do |link|
      href = link.attr('href')&.strip
      next if href.nil? || href.empty? || href.start_with?('#', 'javascript:', 'mailto:')

      begin
        link_uri = href.start_with?('http') ? URI.parse(href) : URI.join(base_uri, href)
        if link_uri.host == base_uri.host
          internal += 1
        else
          external += 1
        end
      rescue
        internal += 1
      end

      rel = link.attr('rel')&.downcase
      nofollow += 1 if rel&.include?('nofollow')
    end

    {
      total: links.size,
      internal: internal,
      external: external,
      nofollow: nofollow
    }
  end

  def extract_word_count(doc)
    doc.css('script, style, noscript').remove
    text = doc.at('body')&.text || doc.text
    text.split.reject(&:empty?).size
  end

  def extract_schema_data(doc)
    scripts = doc.css("script[type='application/ld+json']")
    schemas = []

    scripts.each do |script|
      begin
        data = JSON.parse(script.text)
        schemas << data
      rescue
        next
      end
    end

    schemas
  end

  def extract_favicon(doc, base_uri)
    icon = doc.at("link[rel='icon']") || doc.at("link[rel='shortcut icon']") || doc.at("link[rel='apple-touch-icon']")
    href = icon&.attr('href')
    return nil unless href

    href.start_with?('http') ? href : URI.join(base_uri, href).to_s
  end

  def calculate_seo_score(doc)
    score = 0
    max_score = 100

    # Title (15 points)
    title = extract_title(doc)
    score += 15 if title.present? && title.length >= 10 && title.length <= 60

    # Meta description (15 points)
    desc = extract_meta(doc, 'description')
    score += 15 if desc.present? && desc.length >= 50 && desc.length <= 160

    # Canonical (5 points)
    score += 5 if extract_canonical(doc).present?

    # OG tags (15 points)
    og = extract_og_data(doc)
    score += 5 if og[:title].present?
    score += 5 if og[:description].present?
    score += 5 if og[:image].present?

    # Twitter cards (10 points)
    twitter = extract_twitter_data(doc)
    score += 10 if twitter[:card].present?

    # Headings (15 points)
    headings = extract_headings(doc)
    score += 5 if headings[:h1].size == 1
    score += 5 if headings[:h2].size > 0
    score += 5 if headings[:h1].size <= 1

    # Images alt (10 points)
    images = extract_image_info(doc)
    if images[:total] > 0
      ratio = images[:with_alt].to_f / images[:total]
      score += 10 if ratio >= 0.8
      score += 5 if ratio >= 0.5
    else
      score += 10
    end

    # Word count (5 points)
    word_count = extract_word_count(doc)
    score += 5 if word_count >= 300

    # Schema.org (5 points)
    score += 5 if extract_schema_data(doc).any?

    # Lang attribute (5 points)
    score += 5 if doc.at('html')&.attr('lang').present?

    [score, max_score].min
  end

  def error_result(message, load_time = 0)
    {
      success: false,
      error: message,
      url: @url,
      load_time_ms: load_time
    }
  end
end
