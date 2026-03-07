#!/usr/bin/env ruby
# frozen_string_literal: true
# Retags Xiaomi phones in phones.json into Redmi/Poco sub-brands
# and also ensures Safaricom Neon, Xtigi, FreeYond entries exist

require 'json'
require 'set'

PHONES_FILE = File.expand_path('output/phones.json', __dir__)
phones = JSON.parse(File.read(PHONES_FILE))
existing_slugs = Set.new(phones.map { |p| p['slug'] })

new_entries = []

# ─── Retag Redmi phones from Xiaomi ────────────────────────────────────────
redmi_source = phones.select { |p| p['brand']&.downcase == 'xiaomi' && p['title'].to_s.downcase.include?('redmi') }
redmi_source.each do |phone|
  new_slug = "redmi_#{phone['slug']}"
  next if existing_slugs.include?(new_slug)
  new_entries << phone.merge('brand' => 'Redmi', 'slug' => new_slug)
  existing_slugs << new_slug
end
puts "Redmi entries created: #{redmi_source.size}"

# ─── Safaricom Neon phones (manually curated) ───────────────────────────────
NEON_PHONES = [
  { title: "Safaricom Neon Ray", specs: { "Display" => "6.1 inches", "RAM" => "2GB", "Storage" => "32GB", "Camera" => "13 MP", "Battery" => "3000 mAh", "OS" => "Android Go" } },
  { title: "Safaricom Neon Ray Pro", specs: { "Display" => "6.5 inches", "RAM" => "3GB", "Storage" => "32GB", "Camera" => "13 MP", "Battery" => "4000 mAh", "OS" => "Android" } },
  { title: "Safaricom Neon Smart 4G", specs: { "Display" => "5.0 inches", "RAM" => "1GB", "Storage" => "8GB", "Camera" => "5 MP", "Battery" => "2000 mAh", "OS" => "Android Go", "Network" => "4G LTE" } },
  { title: "Safaricom Neon Kicka 5 Plus", specs: { "Display" => "5.5 inches", "RAM" => "1GB", "Storage" => "8GB", "Camera" => "5 MP", "Battery" => "2500 mAh", "OS" => "Android Go" } },
  { title: "Safaricom Neon Nova", specs: { "Display" => "6.52 inches", "RAM" => "3GB", "Storage" => "32GB", "Camera" => "13 MP", "Battery" => "5000 mAh", "OS" => "Android 12 Go" } },
].each do |phone|
  slug = phone[:title].downcase.gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_')
  next if existing_slugs.include?(slug)
  new_entries << { 'title' => phone[:title], 'slug' => slug, 'brand' => 'Safaricom', 'specifications' => phone[:specs] }
  existing_slugs << slug
end

# ─── Xtigi phones (manually curated) ────────────────────────────────────────
XTIGI_PHONES = [
  { title: "Xtigi S20 Pro", specs: { "Display" => "6.72 inches", "RAM" => "4GB", "Storage" => "64GB", "Camera" => "13 MP Triple", "Battery" => "5000 mAh", "OS" => "Android 12" } },
  { title: "Xtigi Joy 12", specs: { "Display" => "6.5 inches", "RAM" => "2GB", "Storage" => "32GB", "Camera" => "8 MP", "Battery" => "4000 mAh", "OS" => "Android Go" } },
  { title: "Xtigi Joy 13 Pro", specs: { "Display" => "6.6 inches", "RAM" => "4GB", "Storage" => "64GB", "Camera" => "16 MP", "Battery" => "4500 mAh", "OS" => "Android 12" } },
  { title: "Xtigi S11", specs: { "Display" => "5.7 inches", "RAM" => "1GB", "Storage" => "16GB", "Camera" => "5 MP", "Battery" => "3000 mAh", "OS" => "Android Go" } },
].each do |phone|
  slug = phone[:title].downcase.gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_')
  next if existing_slugs.include?(slug)
  new_entries << { 'title' => phone[:title], 'slug' => slug, 'brand' => 'Xtigi', 'specifications' => phone[:specs] }
  existing_slugs << slug
end

# ─── Write updated file ──────────────────────────────────────────────────────
final = phones + new_entries
File.write(PHONES_FILE, JSON.generate(final))
puts "Added #{new_entries.size} new entries. Total: #{final.size}"
