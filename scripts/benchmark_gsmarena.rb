#!/usr/bin/env ruby
# Benchmarks three steps: brand list, model list, model specs
require 'net/http'
require 'uri'

BASE = 'https://www.gsmarena.com'

def fetch(url)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl      = true
  http.verify_mode  = OpenSSL::SSL::VERIFY_NONE
  http.read_timeout = 15
  http.open_timeout = 8
  req = Net::HTTP::Get.new(uri)
  req['User-Agent']      = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36'
  req['Accept-Language'] = 'en-US,en;q=0.9'
  req['Referer']         = BASE
  t0   = Time.now
  resp = http.request(req)
  ms   = ((Time.now - t0) * 1000).round
  body = resp.body.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
  [body, ms, resp.code]
end

puts '=' * 58
puts 'GSMArena — Live Timing Benchmark'
puts '=' * 58

# ── Step 1: Brands list ────────────────────────────────────────
print "\nSTEP 1  Fetching brand list... "
body1, ms1, code1 = fetch("#{BASE}/makers.php3")
brands = body1.scan(/href=([a-z0-9_-]+-phones-\d+\.php)>([^<\n]+)<br>/)
             .map { |slug, name| { slug: slug.strip, name: name.strip } }
puts "#{ms1}ms (HTTP #{code1})"
puts "        #{brands.size} brands found"
puts "        Sample: #{brands.first(5).map { |b| b[:name] }.join(', ')}"

sleep 1.5

# ── Step 2: Samsung model list (page 1 — ~50 models) ──────────
print "\nSTEP 2  Fetching Samsung models (page 1)... "
body2, ms2, code2 = fetch("#{BASE}/samsung-phones-9.php")
models = body2.scan(/<a href="([a-z0-9_+\-]+-\d+\.php)"[^>]*>.*?<strong>\s*<span>([^<]+)<\/span>/im)
             .map { |slug, name| { slug: slug.strip, name: name.strip } }
puts "#{ms2}ms (HTTP #{code2})"
puts "        #{models.size} models on page 1"
puts "        Sample: #{models.first(5).map { |m| m[:name] }.join(', ')}"

sleep 1.5

# ── Step 3: Specs for first model ─────────────────────────────
first = models.first
print "\nSTEP 3  Fetching specs for '#{first[:name]}'... "
body3, ms3, code3 = fetch("#{BASE}/#{first[:slug]}")
specs = {}
body3.scan(/data-spec="([^"]+)"[^>]*>([^<]*)</).each do |k, v|
  specs[k] = v.strip unless v.strip.empty?
end
title_m = body3.match(/<h1 class="specs-phone-name-title"[^>]*>([^<]+)</)
title   = title_m ? title_m[1].strip : first[:name]
puts "#{ms3}ms (HTTP #{code3})"
puts "        #{specs.size} raw spec fields for: #{title}"

# ── Summary ────────────────────────────────────────────────────
total = ms1 + ms2 + ms3
puts "\n#{'─' * 58}"
puts "TIMING SUMMARY"
puts "#{'─' * 58}"
puts "  Step 1  Brand list          #{ms1.to_s.rjust(5)}ms"
puts "  Step 2  Model list (p.1)    #{ms2.to_s.rjust(5)}ms"
puts "  Step 3  Single model specs  #{ms3.to_s.rjust(5)}ms"
puts "  ─────────────────────────────────"
puts "  Total (3 requests)         #{total.to_s.rjust(5)}ms  (~#{(total/1000.0).round(2)}s)"
puts
puts "REAL-WORLD UX ESTIMATES (from brand select → specs shown):"
puts "  Brand dropdown load  : ~#{ms1}ms  (once, cached)"
puts "  Model dropdown load  : ~#{ms2}ms  (per brand change)"
puts "  Specs auto-fill      : ~#{ms3}ms  (per model select)"
puts "  All 3 in sequence    : ~#{(total/1000.0).round(1)}s"
puts '#' * 58
