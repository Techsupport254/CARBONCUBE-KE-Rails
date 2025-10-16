#!/usr/bin/env ruby
# Script to fix IP address references in database
# This script updates database records that reference the IP address to use the domain instead

puts "🔧 Starting IP address reference cleanup..."

# Update any tracking records that might reference the IP
if defined?(Rails)
  Rails.application.eager_load!
  
  # Check if we have any models that might contain IP references
  models_to_check = []
  
  # Look for models that might have URL or host references
  Dir.glob(Rails.root.join('app', 'models', '*.rb')).each do |file|
    model_name = File.basename(file, '.rb').classify
    begin
      model_class = model_name.constantize
      if model_class.respond_to?(:column_names)
        columns = model_class.column_names
        if columns.any? { |col| col.include?('url') || col.include?('host') || col.include?('domain') }
          models_to_check << model_class
        end
      end
    rescue => e
      puts "⚠️  Could not load model #{model_name}: #{e.message}"
    end
  end
  
  puts "📊 Found #{models_to_check.length} models to check for IP references"
  
  models_to_check.each do |model|
    begin
      # Look for columns that might contain the IP address
      ip_columns = model.column_names.select do |col|
        col.include?('url') || col.include?('host') || col.include?('domain') || col.include?('referrer')
      end
      
      if ip_columns.any?
        puts "🔍 Checking #{model.name} for IP references in columns: #{ip_columns.join(', ')}"
        
        ip_columns.each do |column|
          # Update records that contain the IP address
          updated_count = model.where("#{column} ILIKE ?", "%188.245.245.79%").update_all(
            "#{column} = REPLACE(#{column}, '188.245.245.79', 'carboncube-ke.com')"
          
          if updated_count > 0
            puts "✅ Updated #{updated_count} records in #{model.name}.#{column}"
          end
        end
      end
    rescue => e
      puts "⚠️  Error processing #{model.name}: #{e.message}"
    end
  end
  
  puts "✅ IP address reference cleanup completed!"
else
  puts "⚠️  Rails not loaded. Please run this script from the Rails environment."
end
