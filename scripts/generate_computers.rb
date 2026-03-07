#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'

OUTPUT_DIR = File.expand_path('output', __dir__)
OUT_FILE   = File.join(OUTPUT_DIR, 'computers.json')

all_pcs = []

# Helper to build a desktop/computer entry
def build_pc(brand, model_family, cpus, rams, storages, extra_specs = {})
  results = []
  cpus.each do |cpu|
    rams.each do |ram|
      storages.each do |storage|
        # Standardize title e.g. "Apple Mac mini (M2) 8GB RAM 256GB SSD"
        title = "#{brand} #{model_family} - #{cpu} / #{ram} / #{storage}"
        slug = title.downcase.gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_').sub(/_$/, '')
        
        specs = {
          "Processor" => cpu,
          "RAM" => ram,
          "Storage" => storage,
          "Form Factor" => extra_specs[:form_factor] || "Desktop PC"
        }.merge(extra_specs.reject { |k, _| k == :form_factor })

        results << {
          title: title,
          slug: slug,
          brand: brand,
          category: "Computers, Phones and Accessories",
          specifications: specs
        }
      end
    end
  end
  results
end

# Apple Desktops
all_pcs.concat build_pc("Apple", "Mac mini (2023)", ["Apple M2", "Apple M2 Pro"], ["8GB", "16GB", "24GB", "32GB"], ["256GB SSD", "512GB SSD", "1TB SSD"], {form_factor: "Mini PC"})
all_pcs.concat build_pc("Apple", "Mac Studio (2023)", ["Apple M2 Max", "Apple M2 Ultra"], ["32GB", "64GB", "96GB", "128GB", "192GB"], ["512GB SSD", "1TB SSD", "2TB SSD", "4TB SSD"], {form_factor: "Mini PC"})
all_pcs.concat build_pc("Apple", "iMac 24-inch (M3)", ["Apple M3"], ["8GB", "16GB", "24GB"], ["256GB SSD", "512GB SSD", "1TB SSD"], {form_factor: "All-in-One", "Display" => "24-inch 4.5K Retina"})

# Dell Desktops
all_pcs.concat build_pc("Dell", "OptiPlex 7000 Micro", ["Intel Core i5-12500T", "Intel Core i7-12700T"], ["8GB", "16GB", "32GB"], ["256GB SSD", "512GB SSD"], {form_factor: "Micro PC"})
all_pcs.concat build_pc("Dell", "OptiPlex 7000 Tower", ["Intel Core i5-12500", "Intel Core i7-12700", "Intel Core i9-12900"], ["16GB", "32GB", "64GB"], ["512GB SSD", "1TB SSD", "2TB SSD"], {form_factor: "Tower", "GPU" => "Intel UHD Graphics"})
all_pcs.concat build_pc("Dell", "XPS Desktop", ["Intel Core i7-13700", "Intel Core i9-13900K"], ["16GB", "32GB", "64GB"], ["1TB SSD", "1TB SSD + 2TB HDD"], {form_factor: "Tower", "GPU" => "Nvidia RTX 4060 / 4070 / 4080"})

# HP Desktops
all_pcs.concat build_pc("HP", "EliteDesk 800 G9 Mini", ["Intel Core i5-12500T", "Intel Core i7-12700T"], ["8GB", "16GB", "32GB"], ["256GB SSD", "512GB SSD", "1TB SSD"], {form_factor: "Mini PC"})
all_pcs.concat build_pc("HP", "Elite Tower 800 G9", ["Intel Core i5-12500", "Intel Core i7-12700"], ["16GB", "32GB"], ["512GB SSD", "1TB SSD"], {form_factor: "Tower"})
all_pcs.concat build_pc("HP", "Omen 40L Gaming", ["AMD Ryzen 7 7700X", "Intel Core i7-13700K"], ["16GB", "32GB"], ["1TB SSD", "2TB SSD"], {form_factor: "Gaming Tower", "GPU" => "Nvidia RTX 4070 / 4070 Ti"})

# Lenovo Desktops
all_pcs.concat build_pc("Lenovo", "ThinkCentre M70q Gen 3 Tiny", ["Intel Core i5-12400T", "Intel Core i7-12700T"], ["8GB", "16GB", "32GB"], ["256GB SSD", "512GB SSD"], {form_factor: "Mini PC"})
all_pcs.concat build_pc("Lenovo", "ThinkCentre M90t Tower", ["Intel Core i7-12700", "Intel Core i9-12900"], ["16GB", "32GB"], ["512GB SSD", "1TB SSD"], {form_factor: "Tower"})
all_pcs.concat build_pc("Lenovo", "Legion Tower 5i Gen 8", ["Intel Core i5-13400F", "Intel Core i7-13700F"], ["16GB", "32GB"], ["512GB SSD", "1TB SSD"], {form_factor: "Gaming Tower", "GPU" => "Nvidia RTX 4060 / 4060 Ti"})

# Merge with existing file to maintain uniqueness
existing_pcs = []
if File.exist?(OUT_FILE)
  existing_pcs = JSON.parse(File.read(OUT_FILE)) rescue []
end

existing_slugs = Set.new(existing_pcs.map { |t| t['slug'] || t[:slug] })
new_pcs = all_pcs.reject { |t| existing_slugs.include?(t[:slug]) }

final_list = existing_pcs + new_pcs

FileUtils.mkdir_p(OUTPUT_DIR)
File.write(OUT_FILE, JSON.pretty_generate(final_list))

puts "Successfully added #{new_pcs.size} Computer models."
puts "Total Computer catalog size: #{final_list.size}"
