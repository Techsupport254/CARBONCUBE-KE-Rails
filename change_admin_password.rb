#!/usr/bin/env ruby

# Script to change admin password
# Usage: rails runner change_admin_password.rb [new_password]
# If no password is provided, it will generate a secure random password

require 'bcrypt'
require 'securerandom'

# Generate a secure password if none provided
if ARGV[0]
  new_password = ARGV[0]
else
  # Generate a secure random password
  new_password = SecureRandom.alphanumeric(12) + "!@#"
  puts "No password provided. Generating a secure random password..."
end

# Find the admin user
admin = Admin.find_by(email: 'admin@example.com')

if admin
  # Update the password
  admin.password = new_password
  
  if admin.save
    puts "✅ Admin password updated successfully!"
    puts "Email: #{admin.email}"
    puts "New password: #{new_password}"
    puts "\nYou can now log in with these credentials."
    puts "\n⚠️  Please save this password securely!"
  else
    puts "❌ Error updating password: #{admin.errors.full_messages.join(', ')}"
  end
else
  puts "❌ Admin user not found with email: admin@example.com"
  puts "Available admin users:"
  Admin.all.each do |a|
    puts "  - #{a.email} (#{a.fullname})"
  end
end
