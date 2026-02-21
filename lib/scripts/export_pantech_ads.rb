# backend/lib/scripts/export_pantech_ads.rb
require 'csv'

puts "Searching for seller: Pantech Kenya..."
seller = Seller.where("LOWER(enterprise_name) LIKE ?", "%pantech%").first

unless seller
  puts "Error: Seller not found!"
  exit
end

puts "Found seller: #{seller.enterprise_name} (ID: #{seller.id})"

# Get all active ads for this seller
ads = seller.ads.where(deleted: false)
puts "Found #{ads.count} active ads."

if ads.any?
  # Create tmp directory if it doesn't exist (though it should)
  FileUtils.mkdir_p("tmp") unless Dir.exist?("tmp")
  
  csv_file = "tmp/pantech_ads_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
  
  CSV.open(csv_file, 'w') do |csv|
    # Header row
    csv << [
      'ID',
      'Title',
      'Description',
      'Price',
      'Category',
      'Subcategory',
      'Brand',
      'Condition',
      'Created At',
      'Updated At',
      'Media URLs'
    ]
    
    # Data rows
    ads.find_each do |ad|
      csv << [
        ad.id,
        ad.title,
        ad.description,
        ad.price,
        ad.category&.name,
        ad.subcategory&.name,
        ad.brand,
        ad.condition,
        ad.created_at&.iso8601,
        ad.updated_at&.iso8601,
        ad.media_urls.join(', ')
      ]
    end
  end
  
  puts ""
  puts "✓ Successfully exported #{ads.count} ads to: #{csv_file}"
  puts ""
  
  # Also provide a summary of categories for convenience
  puts "Category Breakdown:"
  ads.joins(:category).group('categories.name').count.each do |name, count|
    puts "  - #{name || 'No Category'}: #{count}"
  end
else
  puts "No ads found to export."
end
