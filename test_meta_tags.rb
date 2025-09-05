#!/usr/bin/env ruby

# Test script to check meta tags for shop pages
require_relative 'config/environment'

def test_shop_meta_tags(slug)
  puts "Testing meta tags for shop slug: #{slug}"
  
  # Convert slug back to enterprise name format (same logic as MetaTagsController)
  enterprise_name = slug.gsub('-', ' ').gsub('_', ' ')
  puts "Looking for enterprise name: '#{enterprise_name}'"
  
  # Find shop by enterprise name (case insensitive)
  shop = Seller.includes(:seller_tier, :tier)
               .where('LOWER(enterprise_name) = ?', enterprise_name.downcase)
               .first
  
  # If no exact match, try partial match
  unless shop
    puts "No exact match found, trying partial match..."
    shop = Seller.includes(:seller_tier, :tier)
                 .where('LOWER(enterprise_name) ILIKE ?', "%#{enterprise_name.downcase}%")
                 .first
  end
  
  # If still no match, try to find by ID as fallback
  unless shop
    puts "No partial match found, trying ID fallback..."
    begin
      shop_id = slug.to_i
      if shop_id > 0
        shop = Seller.includes(:seller_tier, :tier).find(shop_id)
      end
    rescue ActiveRecord::RecordNotFound
      puts "No shop found with ID: #{shop_id}"
    end
  end
  
  if shop
    puts "\n✅ Shop found!"
    puts "ID: #{shop.id}"
    puts "Enterprise Name: #{shop.enterprise_name}"
    puts "Description: #{shop.description}"
    puts "Profile Picture: #{shop.profile_picture}"
    puts "Tier: #{shop.tier&.name}"
    puts "Product Count: #{shop.ads.active.count}"
    
    # Generate meta tags
    title = "#{shop.enterprise_name} | Carbon Cube Kenya"
    description = shop.description.presence || "#{shop.enterprise_name} - #{shop.tier&.name} seller offering #{shop.ads.active.count} quality products for online shopping on Carbon Cube Kenya"
    
    image_url = if shop.profile_picture.present?
      if shop.profile_picture.start_with?('http')
        shop.profile_picture
      else
        "https://carboncube-ke.com#{shop.profile_picture}"
      end
    else
      "https://via.placeholder.com/1200x630/FFD700/000000?text=#{CGI.escape(shop.enterprise_name)}"
    end
    
    url = "https://carboncube-ke.com/shop/#{slug}"
    
    puts "\n📋 Generated Meta Tags:"
    puts "Title: #{title}"
    puts "Description: #{description}"
    puts "Image URL: #{image_url}"
    puts "URL: #{url}"
  else
    puts "\n❌ No shop found for slug: #{slug}"
    puts "This would fallback to default Carbon Cube meta tags"
  end
end

# Test the specific shop from the WhatsApp link
test_shop_meta_tags("wagpa-auto-spare")

puts "\n" + "="*50
puts "Testing a few other shop slugs to see what exists:"

# Get a few sample shops to see their slugs
sample_shops = Seller.limit(5)
sample_shops.each do |shop|
  slug = shop.enterprise_name.downcase.gsub(' ', '-').gsub('_', '-')
  puts "Shop: #{shop.enterprise_name} -> Slug: #{slug}"
end
