#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'

OUTPUT_DIR = File.expand_path('output', __dir__)
OUT_FILE   = File.join(OUTPUT_DIR, 'tvs.json')

# Standard screen sizes for modern TVs
SIZES_SMALL = [32, 40, 43]
SIZES_MED   = [50, 55, 65]
SIZES_LARGE = [75, 85, 98]
SIZES_ALL   = SIZES_SMALL + SIZES_MED + SIZES_LARGE

# Helper to build a TV entry
def build_tv(brand, series_name, sizes, resolution, type, smart, os, extra_specs = {})
  results = []
  sizes.each do |size|
    title = "#{brand} #{size}-inch #{series_name} #{type} #{resolution} #{smart ? 'Smart' : ''} TV"
    slug = title.downcase.gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_').sub(/_$/, '')
    
    specs = {
      "Screen Size" => "#{size} inches",
      "Resolution" => resolution,
      "Display Type" => type,
      "Smart TV" => smart ? "Yes" : "No",
      "Operating System" => os
    }.merge(extra_specs)

    results << {
      title: title,
      slug: slug,
      brand: brand,
      category: "TVs & Home Entertainment",
      specifications: specs
    }
  end
  results
end

all_tvs = []

# =========================================================================
# SAMSUNG
# =========================================================================
# 2023/2024 Lineup
all_tvs.concat build_tv("Samsung", "CU7000 Crystal UHD", SIZES_MED+SIZES_LARGE+[43], "4K (2160p)", "LED", true, "Tizen Plus", {"Refresh Rate" => "60Hz", "HDR" => "HDR10+"})
all_tvs.concat build_tv("Samsung", "CU8000 Crystal UHD", SIZES_MED+SIZES_LARGE+[43], "4K (2160p)", "LED", true, "Tizen Plus", {"Refresh Rate" => "60Hz", "HDR" => "HDR10+"})
all_tvs.concat build_tv("Samsung", "Q60C QLED", SIZES_MED+SIZES_LARGE+[43], "4K (2160p)", "QLED", true, "Tizen", {"Refresh Rate" => "60Hz", "HDR" => "Quantum HDR"})
all_tvs.concat build_tv("Samsung", "Q70C QLED", SIZES_MED+SIZES_LARGE, "4K (2160p)", "QLED", true, "Tizen", {"Refresh Rate" => "120Hz", "HDR" => "Quantum HDR"})
all_tvs.concat build_tv("Samsung", "Q80C QLED", SIZES_MED+SIZES_LARGE, "4K (2160p)", "QLED", true, "Tizen", {"Refresh Rate" => "120Hz", "HDR" => "Quantum HDR+"})
all_tvs.concat build_tv("Samsung", "QN85C Neo QLED", SIZES_MED+SIZES_LARGE, "4K (2160p)", "Mini-LED", true, "Tizen", {"Refresh Rate" => "120Hz", "HDR" => "Neo Quantum HDR"})
all_tvs.concat build_tv("Samsung", "QN90C Neo QLED", SIZES_ALL - [32,40,98], "4K (2160p)", "Mini-LED", true, "Tizen", {"Refresh Rate" => "120Hz/144Hz", "HDR" => "Neo Quantum HDR+"})
all_tvs.concat build_tv("Samsung", "S90C OLED", [55,65,77,83], "4K (2160p)", "OLED", true, "Tizen", {"Refresh Rate" => "120Hz/144Hz", "HDR" => "OLED HDR+"})
all_tvs.concat build_tv("Samsung", "S95C OLED", [55,65,77], "4K (2160p)", "OLED", true, "Tizen", {"Refresh Rate" => "120Hz/144Hz", "HDR" => "Quantum HDR OLED+"})
all_tvs.concat build_tv("Samsung", "QN800C Neo QLED", [65,75,85], "8K (4320p)", "Mini-LED", true, "Tizen", {"Refresh Rate" => "120Hz", "HDR" => "Neo Quantum HDR 8K+"})
all_tvs.concat build_tv("Samsung", "QN900C Neo QLED", [65,75,85], "8K (4320p)", "Mini-LED", true, "Tizen", {"Refresh Rate" => "144Hz", "HDR" => "Neo Quantum HDR 8K Pro"})
all_tvs.concat build_tv("Samsung", "The Frame", SIZES_ALL - [98], "4K (2160p)", "QLED (Matte)", true, "Tizen", {"Refresh Rate" => "60Hz/120Hz", "HDR" => "Quantum HDR"})
all_tvs.concat build_tv("Samsung", "T4000", [32], "HD (720p)", "LED", false, "None", {"Refresh Rate" => "60Hz"})

# =========================================================================
# LG
# =========================================================================
all_tvs.concat build_tv("LG", "UR8000", SIZES_MED+SIZES_LARGE+[43], "4K (2160p)", "LED", true, "webOS", {"Refresh Rate" => "60Hz", "HDR" => "HDR10 Pro"})
all_tvs.concat build_tv("LG", "UR9000", SIZES_MED+[43], "4K (2160p)", "LED", true, "webOS", {"Refresh Rate" => "60Hz", "HDR" => "HDR10 Pro"})
all_tvs.concat build_tv("LG", "QNED75", SIZES_MED+SIZES_LARGE+[43], "4K (2160p)", "QNED", true, "webOS", {"Refresh Rate" => "60Hz", "HDR" => "HDR10 Pro"})
all_tvs.concat build_tv("LG", "QNED80", SIZES_MED+SIZES_LARGE, "4K (2160p)", "QNED", true, "webOS", {"Refresh Rate" => "120Hz", "HDR" => "HDR10 Pro"})
all_tvs.concat build_tv("LG", "B3 OLED", [55,65,77], "4K (2160p)", "OLED", true, "webOS", {"Refresh Rate" => "120Hz", "HDR" => "Dolby Vision / HDR10"})
all_tvs.concat build_tv("LG", "C3 OLED", [42,48,55,65,77,83], "4K (2160p)", "OLED evo", true, "webOS", {"Refresh Rate" => "120Hz", "HDR" => "Dolby Vision / HDR10"})
all_tvs.concat build_tv("LG", "G3 OLED", [55,65,77,83], "4K (2160p)", "OLED evo (MLA)", true, "webOS", {"Refresh Rate" => "120Hz", "HDR" => "Dolby Vision / HDR10"})
all_tvs.concat build_tv("LG", "Z3 OLED", [77,88], "8K (4320p)", "OLED", true, "webOS", {"Refresh Rate" => "120Hz", "HDR" => "Dolby Vision / HDR10"})
all_tvs.concat build_tv("LG", "LQ6300", [32], "FHD (1080p)", "LED", true, "webOS", {"Refresh Rate" => "60Hz"})

# =========================================================================
# SONY
# =========================================================================
all_tvs.concat build_tv("Sony", "Bravia X77L", SIZES_MED+[43,75,85], "4K (2160p)", "LED", true, "Google TV", {"Refresh Rate" => "60Hz", "HDR" => "HDR10"})
all_tvs.concat build_tv("Sony", "Bravia X80L", SIZES_MED+[43,75,85], "4K (2160p)", "LED", true, "Google TV", {"Refresh Rate" => "60Hz", "HDR" => "Dolby Vision"})
all_tvs.concat build_tv("Sony", "Bravia X85L", SIZES_MED+[75], "4K (2160p)", "Full Array LED", true, "Google TV", {"Refresh Rate" => "120Hz", "HDR" => "Dolby Vision"})
all_tvs.concat build_tv("Sony", "Bravia X90L", SIZES_MED+SIZES_LARGE, "4K (2160p)", "Full Array LED", true, "Google TV", {"Refresh Rate" => "120Hz", "HDR" => "Dolby Vision"})
all_tvs.concat build_tv("Sony", "Bravia X93L", [65,75,85], "4K (2160p)", "Mini-LED", true, "Google TV", {"Refresh Rate" => "120Hz", "HDR" => "Dolby Vision"})
all_tvs.concat build_tv("Sony", "Bravia X95L", [85], "4K (2160p)", "Mini-LED", true, "Google TV", {"Refresh Rate" => "120Hz", "HDR" => "Dolby Vision"})
all_tvs.concat build_tv("Sony", "Bravia A80L OLED", [55,65,77,83], "4K (2160p)", "OLED", true, "Google TV", {"Refresh Rate" => "120Hz", "HDR" => "Dolby Vision"})
all_tvs.concat build_tv("Sony", "Bravia A95L QD-OLED", [55,65,77], "4K (2160p)", "QD-OLED", true, "Google TV", {"Refresh Rate" => "120Hz", "HDR" => "Dolby Vision"})
all_tvs.concat build_tv("Sony", "W830K", [32], "HD (720p)", "LED", true, "Google TV", {"Refresh Rate" => "60Hz"})

# =========================================================================
# TCL
# =========================================================================
all_tvs.concat build_tv("TCL", "S3", [32,40,43], "FHD (1080p)", "LED", true, "Roku TV", {"Refresh Rate" => "60Hz"})
all_tvs.concat build_tv("TCL", "S4", SIZES_MED+[43,75,85], "4K (2160p)", "LED", true, "Google / Roku", {"Refresh Rate" => "60Hz", "HDR" => "HDR10"})
all_tvs.concat build_tv("TCL", "Q6", SIZES_MED+[75,85], "4K (2160p)", "QLED", true, "Google / Fire TV", {"Refresh Rate" => "60Hz (120Hz VRR)", "HDR" => "Dolby Vision / HDR10+"})
all_tvs.concat build_tv("TCL", "Q7", SIZES_MED+[75,85], "4K (2160p)", "QLED", true, "Google TV", {"Refresh Rate" => "120Hz (144Hz VRR)", "HDR" => "Dolby Vision IQ / HDR10+"})
all_tvs.concat build_tv("TCL", "QM8", [65,75,85,98], "4K (2160p)", "Mini-LED", true, "Google TV", {"Refresh Rate" => "120Hz (144Hz VRR)", "HDR" => "Dolby Vision IQ / HDR10+"})

# =========================================================================
# HISENSE
# =========================================================================
all_tvs.concat build_tv("Hisense", "A4 Series", [32,40,43], "FHD (1080p)", "LED", true, "Vidaa / Android", {"Refresh Rate" => "60Hz"})
all_tvs.concat build_tv("Hisense", "A6 Series", SIZES_MED+[43,75,85], "4K (2160p)", "LED", true, "Google TV", {"Refresh Rate" => "60Hz", "HDR" => "Dolby Vision"})
all_tvs.concat build_tv("Hisense", "U6K", SIZES_MED+[75], "4K (2160p)", "Mini-LED", true, "Google TV", {"Refresh Rate" => "60Hz (VRR)", "HDR" => "Dolby Vision / HDR10+"})
all_tvs.concat build_tv("Hisense", "U7K", SIZES_MED+[75,85], "4K (2160p)", "Mini-LED", true, "Google TV", {"Refresh Rate" => "144Hz", "HDR" => "Dolby Vision IQ / HDR10+"})
all_tvs.concat build_tv("Hisense", "U8K", SIZES_MED+[75,85,100], "4K (2160p)", "Mini-LED", true, "Google TV", {"Refresh Rate" => "144Hz", "HDR" => "Dolby Vision IQ / HDR10+"})

# =========================================================================
# VIZIO
# =========================================================================
all_tvs.concat build_tv("Vizio", "D-Series", [24,32,40,43], "FHD (1080p)", "LED", true, "SmartCast", {"Refresh Rate" => "60Hz"})
all_tvs.concat build_tv("Vizio", "V-Series", SIZES_MED+[43,70,75], "4K (2160p)", "LED", true, "SmartCast", {"Refresh Rate" => "60Hz", "HDR" => "Dolby Vision / HDR10+"})
all_tvs.concat build_tv("Vizio", "M-Series Quantum", SIZES_MED+[43,70,75], "4K (2160p)", "QLED", true, "SmartCast", {"Refresh Rate" => "60Hz", "HDR" => "Dolby Vision / HDR10+"})
all_tvs.concat build_tv("Vizio", "P-Series Quantum", [65,75,85], "4K (2160p)", "QLED", true, "SmartCast", {"Refresh Rate" => "120Hz", "HDR" => "Dolby Vision / HDR10+"})

# Merge with existing file to maintain uniqueness
existing_tvs = []
if File.exist?(OUT_FILE)
  existing_tvs = JSON.parse(File.read(OUT_FILE)) rescue []
end

existing_slugs = Set.new(existing_tvs.map { |t| t['slug'] || t[:slug] })
new_tvs = all_tvs.reject { |t| existing_slugs.include?(t[:slug]) }

final_list = existing_tvs + new_tvs

FileUtils.mkdir_p(OUTPUT_DIR)
File.write(OUT_FILE, JSON.pretty_generate(final_list))

puts "Successfully added #{new_tvs.size} TV models."
puts "Total TV catalog size: #{final_list.size}"
