#!/usr/bin/env ruby
# Debug script to test product creation directly

require_relative 'config/environment'

# Find the pending session
session = WhatsappProductSession.where(status: 'pending').order(created_at: :desc).first

if session
  puts "Found session:"
  puts "  ID: #{session.id}"
  puts "  Seller ID: #{session.seller_id}"
  puts "  Phone: #{session.phone_number}"
  puts "  Step: #{session.step}"
  puts "  Status: #{session.status}"
  puts ""
  
  puts "Product data:"
  session.product_data.each do |key, value|
    puts "  #{key}: #{value.inspect}"
  end
  puts ""
  
  # Try to create the product directly
  puts "Attempting to create product..."
  result = WhatsappProductCreationService.create_product(session)
  
  puts "Result:"
  puts "  Success: #{result[:success]}"
  puts "  Error: #{result[:error]}" if result[:error]
  puts "  Ad ID: #{result[:ad]&.id}" if result[:ad]
  
  if result[:success]
    session.complete!
    puts "Session completed!"
  end
else
  puts "No pending session found"
end
