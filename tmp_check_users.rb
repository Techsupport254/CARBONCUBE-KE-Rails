#!/usr/bin/env ruby
require_relative 'config/environment'

puts 'Most recent buyer:'
buyer = Buyer.order(created_at: :desc).first
if buyer
  puts "ID: #{buyer.id}"
  puts "Name: #{buyer.fullname}"
  puts "Email: #{buyer.email}"
  puts "Username: #{buyer.username}"
  puts "Created: #{buyer.created_at}"
else
  puts 'No buyers found'
end

puts ''
puts 'Most recent seller:'
seller = Seller.order(created_at: :desc).first
if seller
  puts "ID: #{seller.id}"
  puts "Name: #{seller.fullname}"
  puts "Email: #{seller.email}"
  puts "Username: #{seller.username}"
  puts "Enterprise: #{seller.enterprise_name}"
  puts "Created: #{seller.created_at}"
else
  puts 'No sellers found'
end
