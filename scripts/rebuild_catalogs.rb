require 'json'

def load_source(name)
  path = Rails.root.join('scripts', 'output', "#{name}.json")
  if File.exist?(path)
    begin
      JSON.parse(File.read(path))
    rescue => e
      puts "Error parsing #{path}: #{e.message}"
      []
    end
  else
    []
  end
end

out_dir = Rails.root.join('scripts', 'output')
FileUtils.mkdir_p(out_dir)

# Load data from all available sources
phones_data = load_source('phones')
laptops_raw = load_source('laptops')
tvs_raw = load_source('tvs')
computers_raw = load_source('computers')
automotive_raw = load_source('automotive')

# Merge all into a processing set
data = phones_data + laptops_raw + tvs_raw + computers_raw + automotive_raw
puts "Total devices loaded from sources: #{data.size} (Phones: #{phones_data.size}, Laptops: #{laptops_raw.size}, TVs: #{tvs_raw.size}, Computers: #{computers_raw.size}, Automotive: #{automotive_raw.size})"

ipads = []
tablets = []
watches = []
laptops = []
tvs = []
computers = []
automotive = []
phones = []

tablet_keywords = %w[tab pad tablet slate note-pro notepro]
watch_keywords = %w[watch band fit tracker w1 w2 w3 w4 w5] 
laptop_keywords = %w[book laptop macbook chromebook envy x360 pavilion ideapad thinkpad inspire precision alienware]
tv_keywords = %w[tv vision viera bravia aquos qled oled crystal]

data.each do |device|
  title = device['title'].to_s.downcase
  brand = device['brand'].to_s.downcase

  # Extract by keyword or explicit source hint
  if title.include?('ipad')
    ipads << device
  elsif laptop_keywords.any? { |kw| title.include?(kw) }
    laptops << device
  elsif device['category'] == 'TVs & Home Entertainment'
    tvs << device
  elsif device['category'] == 'Computers, Phones and Accessories' && device['specifications'] && device['specifications']['Form Factor']
    computers << device
  elsif device['category'] == 'Automotive Parts & Accessories'
    automotive << device
  elsif watch_keywords.any? { |kw| title.include?(kw) || title.match?(/\b#{kw}\b/) } && !title.include?('fitbit')
    watches << device
  elsif tablet_keywords.any? { |kw| title.include?(kw) } && !title.include?('keypad') && !title.include?('padfone')
    tablets << device
  else
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
puts " - Computers: #{computers.size}"
puts " - Automotive: #{automotive.size}"
puts " - Phones: #{phones.size}"

def write_if_not_empty(path, data)
  File.write(path, JSON.pretty_generate(data))
  puts "Wrote #{data.size} items to #{path}."
end

write_if_not_empty(out_dir.join('ipads_filtered.json'), ipads)
write_if_not_empty(out_dir.join('tablets_filtered.json'), tablets)
write_if_not_empty(out_dir.join('watches_filtered.json'), watches)
write_if_not_empty(out_dir.join('laptops_filtered.json'), laptops)
write_if_not_empty(out_dir.join('tvs_filtered.json'), tvs)
write_if_not_empty(out_dir.join('computers_filtered.json'), computers)
write_if_not_empty(out_dir.join('automotive_filtered.json'), automotive)
write_if_not_empty(out_dir.join('phones_filtered.json'), phones)

puts "Done writing filtered files."
