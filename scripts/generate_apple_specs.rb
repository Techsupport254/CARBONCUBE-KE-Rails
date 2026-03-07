#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'json'
require 'set'

OPENTCORE_PATH = '/tmp/opencore/AppleModels/DataBase'
OUTPUT_FILE = '/Users/Quaint/Desktop/carbon-v2/backend/scripts/output/laptops.json'

def parse_yaml(file_path)
  content = File.read(file_path)
  # Basic parsing since these YAMLs are slightly custom but mostly YAML-compatible
  # We care about Specifications: section
  
  parsed = YAML.safe_load(content, permitted_classes: [Symbol], symbolize_names: true) rescue nil
  return nil unless parsed && parsed[:Specifications]
  
  specs = parsed[:Specifications]
  
  # Identify title (MarketingName or SystemReportName)
  titles = Array(specs[:MarketingName] || specs[:SystemReportName])
  return [] if titles.empty?
  
  items = []
  titles.each do |title|
    items << {
      title: title,
      brand: "Apple",
      manufacturer: "Apple",
      specifications: {
        "Processor" => Array(specs[:CPU]).join(" / "),
        "GPU" => Array(specs[:GPU]).join(" / "),
        "RAM" => Array(specs[:RAM]).join(" / "),
        "Generation" => Array(specs[:CPUCodename]).join(" / "),
        "Year" => Array(parsed[:AppleModelYear]).first
      }
    }
  end
  items
end

results = []

# 1. Parse Intel Macs from OpenCore
Dir.glob("#{OPENTCORE_PATH}/**/*.yaml").each do |file|
  macs = parse_yaml(file)
  results.concat(macs) if macs
end

# 2. Add Apple Silicon Macs (M1, M2, M3)
m_series = [
  { title: "MacBook Air (M1, 2020)", cpu: "Apple M1 chip", ram: "8GB/16GB", gpu: "7-core GPU/8-core GPU", display: "13.3-inch Retina" },
  { title: "MacBook Pro (13-inch, M1, 2020)", cpu: "Apple M1 chip", ram: "8GB/16GB", gpu: "8-core GPU", display: "13.3-inch Retina" },
  { title: "MacBook Pro (14-inch, 2021)", cpu: "Apple M1 Pro / M1 Max", ram: "16GB/32GB/64GB", gpu: "14/16/24/32-core GPU", display: "14.2-inch Liquid Retina XDR" },
  { title: "MacBook Pro (16-inch, 2021)", cpu: "Apple M1 Pro / M1 Max", ram: "16GB/32GB/64GB", gpu: "16/24/32-core GPU", display: "16.2-inch Liquid Retina XDR" },
  { title: "MacBook Air (M2, 2022)", cpu: "Apple M2 chip", ram: "8GB/16GB/24GB", gpu: "8-core GPU/10-core GPU", display: "13.6-inch Liquid Retina" },
  { title: "MacBook Air (15-inch, M2, 2023)", cpu: "Apple M2 chip", ram: "8GB/16GB/24GB", gpu: "10-core GPU", display: "15.3-inch Liquid Retina" },
  { title: "MacBook Pro (13-inch, M2, 2022)", cpu: "Apple M2 chip", ram: "8GB/16GB/24GB", gpu: "10-core GPU", display: "13.3-inch Retina" },
  { title: "MacBook Pro (14-inch, 2023)", cpu: "Apple M2 Pro / M2 Max", ram: "16GB/32GB/64GB/96GB", gpu: "10/12/16/19/30/38-core GPU", display: "14.2-inch Liquid Retina XDR" },
  { title: "MacBook Pro (16-inch, 2023)", cpu: "Apple M2 Pro / M2 Max", ram: "16GB/32GB/64GB/96GB", gpu: "19/30/38-core GPU", display: "16.2-inch Liquid Retina XDR" },
  { title: "MacBook Pro (14-inch, Nov 2023)", cpu: "Apple M3 / M3 Pro / M3 Max", ram: "8GB/16GB/24GB/36GB/48GB/64GB/96GB/128GB", gpu: "10/14/18/30/40-core GPU", display: "14.2-inch Liquid Retina XDR" },
  { title: "MacBook Pro (16-inch, Nov 2023)", cpu: "Apple M3 Pro / M3 Max", ram: "18GB/36GB/48GB/64GB/96GB/128GB", gpu: "18/30/40-core GPU", display: "16.2-inch Liquid Retina XDR" },
  { title: "MacBook Air (13-inch, M3, 2024)", cpu: "Apple M3 chip", ram: "8GB/16GB/24GB", gpu: "8-core GPU/10-core GPU", display: "13.6-inch Liquid Retina" },
  { title: "MacBook Air (15-inch, M3, 2024)", cpu: "Apple M3 chip", ram: "8GB/16GB/24GB", gpu: "10-core GPU", display: "15.3-inch Liquid Retina" }
]

m_series.each do |m|
  results << {
    title: m[:title],
    brand: "Apple",
    manufacturer: "Apple",
    specifications: {
      "Processor" => m[:cpu],
      "GPU" => m[:gpu],
      "RAM" => m[:ram],
      "Display" => m[:display],
      "Generation" => "Apple Silicon"
    }
  }
end

# 3. Final cleaning and uniqueness
existing = File.exist?(OUTPUT_FILE) ? JSON.parse(File.read(OUTPUT_FILE)) : []
# Keep existing non-Apple laptops, but replace Apple laptops with our better ones
non_apple = existing.reject { |l| (l["brand"] || l[:brand]).to_s.downcase == "apple" }

final_results = non_apple + results
final_results.uniq! { |l| l[:title] || l["title"] }

File.write(OUTPUT_FILE, JSON.pretty_generate(final_results))
puts "Successfully added #{results.size} Apple MacBooks with technical specifications."
puts "Total catalog size: #{final_results.size}"
