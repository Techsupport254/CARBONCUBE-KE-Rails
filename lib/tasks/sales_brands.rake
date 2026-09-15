# frozen_string_literal: true

namespace :sales_brands do
  desc 'Seed the Brand Kenya master directory into sales_brands (idempotent by name)'
  task seed: :environment do
    path = Rails.root.join('db/data/sales_brands.json')
    data = JSON.parse(File.read(path))

    fields = %w[part category subcategories scope location phone email website twitter]

    created = 0
    updated = 0
    data.each do |attrs|
      brand = SalesBrand.find_or_initialize_by(name: attrs['name'])
      brand.assign_attributes(attrs.slice(*fields))
      if brand.new_record?
        created += 1
      elsif brand.changed?
        updated += 1
      end
      brand.save!
    end

    puts "sales_brands seeded: #{created} created, #{updated} updated, #{SalesBrand.count} total"
  end
end
