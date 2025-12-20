# Check sitemap XML endpoint
# Run with: rails runner lib/scripts/check_sitemap.rb

require 'net/http'
require 'uri'

puts "=" * 80
puts "Checking Sitemap XML Endpoint"
puts "=" * 80
puts ""

sitemap_url = ENV['LOCAL_SITEMAP_URL'] || "https://carboncube-ke.com/sitemap.xml"

begin
  puts "Fetching: #{sitemap_url}"
  puts ""

  uri = URI.parse(sitemap_url)
  http = Net::HTTP.new(uri.host, uri.port)
  if uri.scheme == 'https'
    http.use_ssl = true
    # Skip SSL verification for localhost/development
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if uri.host.include?('localhost') || uri.host.include?('127.0.0.1')
  end
  http.open_timeout = 10
  http.read_timeout = 30

  request = Net::HTTP::Get.new(uri.request_uri)
  request['User-Agent'] = 'CarbonBot/1.0 (Sitemap Checker)'

  response = http.request(request)

  puts "Response Status: #{response.code} #{response.message}"
  puts "Content-Type: #{response['content-type']}"
  puts "Content-Length: #{response['content-length'] || 'unknown'}"
  puts ""

  if response.code == '200'
    puts "✅ Sitemap accessible!"
    puts ""

    content = response.body

    # Check for HTML styling contamination
    if content.include?('<style') || content.include?('palette-shift') || content.include?('class="')
      puts "❌ ERROR: Sitemap contains HTML styling or classes!"
      puts "This will cause Google Search Console errors."
      puts ""

      if content.include?('palette-shift')
        puts "Found palette-shift styling - this is browser extension contamination"
      end

      if content.include?('<style')
        puts "Found <style> tags - HTML styling should not be in XML sitemap"
      end

      puts ""
      puts "First 300 characters of problematic content:"
      puts "-" * 50
      puts content[0..299]
      puts "-" * 50
      puts ""
      puts "❌ Sitemap validation FAILED"
      return
    end

    # Parse and show basic info
    if response['content-type']&.include?('xml')
      puts "✅ Content-Type is correct: #{response['content-type']}"
      puts ""

      # Basic XML validation
      if content.start_with?('<?xml version="1.0" encoding="UTF-8"?>') && content.include?('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
        puts "✅ XML declaration and sitemap namespace are correct"
      else
        puts "⚠️  XML structure may not be standard sitemap format"
      end

      puts ""
      puts "XML Content Preview (first 500 characters):"
      puts "-" * 50
      puts content[0..499]
      puts "-" * 50

      # Count URLs in sitemap
      url_count = content.scan(/<url>/).length
      puts ""
      puts "URLs found in sitemap: #{url_count}"

      # Check for proper XML closing
      if content.include?('</urlset>')
        puts "✅ XML properly closed with </urlset>"
      else
        puts "❌ XML not properly closed - missing </urlset>"
      end

      # Show priority distribution
      priorities = content.scan(/<priority>([^<]+)<\/priority>/).flatten
      if priorities.any?
        priority_counts = priorities.group_by(&:to_s).transform_values(&:count)
        puts ""
        puts "Priority distribution:"
        priority_counts.sort_by { |k,v| -v }.each do |priority, count|
          puts "  #{priority}: #{count} URLs"
        end
      end

      # Check for XML validity
      xml_errors = []
      xml_errors << "Missing XML declaration" unless content.include?('<?xml')
      xml_errors << "Missing urlset element" unless content.include?('<urlset')
      xml_errors << "Missing namespace" unless content.include?('xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"')

      if xml_errors.empty?
        puts ""
        puts "✅ Sitemap XML structure appears valid"
      else
        puts ""
        puts "⚠️  XML structure issues found:"
        xml_errors.each { |error| puts "  - #{error}" }
      end

    else
      puts "⚠️  Response is not XML content type: #{response['content-type']}"
    end
  else
    puts "❌ Error accessing sitemap: #{response.code}"
    puts "Response body:"
    puts response.body[0..500] if response.body
  end

rescue Timeout::Error => e
  puts "❌ Timeout error: #{e.message}"
rescue SocketError => e
  puts "❌ Connection error: #{e.message}"
rescue => e
  puts "❌ Unexpected error: #{e.message}"
  puts e.backtrace.join("\n") if ENV['DEBUG']
end

puts ""
puts "=" * 80
puts "Done"
puts "=" * 80
