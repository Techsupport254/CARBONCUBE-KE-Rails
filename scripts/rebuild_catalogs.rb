require 'json'

input_path = Rails.root.join('scripts', 'output', 'phones.json')
out_dir = Rails.root.join('scripts', 'output')

unless File.exist?(input_path)
  puts "Input file not found at #{input_path}"
  exit 1
end

data = JSON.parse(File.read(input_path))
puts "Total devices loaded: #{data.size}"

ipads = []
tablets = []
watches = []
laptops = []
tvs = []
phones = []

tablet_keywords = %w[tab pad tablet slate note-pro notepro]
watch_keywords = %w[watch band fit tracker w1 w2 w3 w4 w5] 
laptop_keywords = %w[book laptop macbook chromebook]
tv_keywords = %w[tv vision]

data.each do |device|
  title = device['title'].to_s.downcase

  # Extract by keyword
  if title.include?('ipad')
    ipads << device
  elsif tablet_keywords.any? { |kw| title.include?(kw) } && !title.include?('keypad') && !title.include?('padfone')
    tablets << device
  elsif watch_keywords.any? { |kw| title.include?(kw) || title.match?(/\b#{kw}\b/) } && !title.include?('fitbit') # fitbit usually watch but some are phones? No fitbit is watch.
    watches << device
  elsif laptop_keywords.any? { |kw| title.include?(kw) }
    laptops << device
  elsif tv_keywords.any? { |kw| title.match?(/\b#{kw}\b/) }
    tvs << device
  else
    # Exclude basic modems, routers, VR headsets based on keywords if needed, 
    # but for now default to phone
    unless title.match?(/\b(router|modem|hotspot|vr|glass)\b/)
      phones << device
    end
  end
end

puts "Categorized:"
puts " - iPads: #{ipads.size}"
puts " - Tablets: #{tablets.size}"
puts " - Watches: #{watches.size}"
puts " - Laptops: #{laptops.size}"
puts " - TVs: #{tvs.size}"
puts " - Phones: #{phones.size}"

File.write(out_dir.join('ipads_filtered.json'), JSON.pretty_generate(ipads))
File.write(out_dir.join('tablets_filtered.json'), JSON.pretty_generate(tablets))
File.write(out_dir.join('watches_filtered.json'), JSON.pretty_generate(watches))
File.write(out_dir.join('laptops_filtered.json'), JSON.pretty_generate(laptops))
File.write(out_dir.join('tvs_filtered.json'), JSON.pretty_generate(tvs))
File.write(out_dir.join('phones_filtered.json'), JSON.pretty_generate(phones))

puts "Done writing filtered files."
