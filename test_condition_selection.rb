#!/usr/bin/env ruby
# Test script for interactive condition selection

require 'net/http'
require 'uri'
require 'json'
require 'cloudinary'

# Load Rails environment
require_relative 'config/environment'

# Configuration
BASE_URL = 'http://localhost:3001'
WEBHOOK_URL = "#{BASE_URL}/webhooks/whatsapp"
SELLER_PHONE = '0712345678'
IMAGE_DIR = '/home/kirui/Desktop/Carbon/imgs'

# Colors for output
GREEN = "\033[0;32m"
RED = "\033[0;31m"
YELLOW = "\033[1;33m"
NC = "\033[0m"

def log(message, color = NC)
  puts "#{color}#{message}#{NC}"
end

# Upload image to Cloudinary
def upload_image_to_cloudinary(image_path)
  log("Uploading #{File.basename(image_path)}...", YELLOW)
  
  begin
    result = Cloudinary::Uploader.upload(
      image_path,
      upload_preset: ENV['UPLOAD_PRESET'],
      folder: 'whatsapp_test',
      resource_type: 'image'
    )
    
    if result && result['secure_url']
      log("✓ Uploaded: #{result['secure_url']}", GREEN)
      result['secure_url']
    else
      log("✗ Failed to upload #{File.basename(image_path)}", RED)
      nil
    end
  rescue => e
    log("✗ Error uploading #{File.basename(image_path)}: #{e.message}", RED)
    nil
  end
end

# Simulate text message
def send_webhook_text(phone_number, text)
  log("Sending webhook with text: #{text}", YELLOW)
  
  payload = {
    object: 'whatsapp_business_account',
    entry: [{
      id: '123456789',
      changes: [{
        value: {
          messaging_product: 'whatsapp',
          metadata: {
            display_phone_number: '254712345678',
            phone_number_id: '123456789'
          },
          messages: [{
            from: phone_number.start_with?('254') ? phone_number : "254#{phone_number[1..]}",
            id: "wamid.test_#{Time.now.to_i}",
            timestamp: Time.now.to_i.to_s,
            type: 'text',
            text: { body: text }
          }]
        },
        field: 'messages'
      }]
    }]
  }
  
  uri = URI(WEBHOOK_URL)
  http = Net::HTTP.new(uri.host, uri.port)
  
  request = Net::HTTP::Post.new(uri.path)
  request['Content-Type'] = 'application/json'
  request.body = payload.to_json
  
  begin
    response = http.request(request)
    log("Webhook response: #{response.code}", GREEN)
    { success: response.code.to_i == 200, response: response.body }
  rescue => e
    log("✗ Webhook error: #{e.message}", RED)
    { success: false, error: e.message }
  end
end

# Simulate button response
def send_webhook_button(phone_number, button_id)
  log("Sending webhook with button response: #{button_id}", YELLOW)
  
  payload = {
    object: 'whatsapp_business_account',
    entry: [{
      id: '123456789',
      changes: [{
        value: {
          messaging_product: 'whatsapp',
          metadata: {
            display_phone_number: '254712345678',
            phone_number_id: '123456789'
          },
          messages: [{
            from: phone_number.start_with?('254') ? phone_number : "254#{phone_number[1..]}",
            id: "wamid.test_#{Time.now.to_i}",
            timestamp: Time.now.to_i.to_s,
            type: 'interactive',
            interactive: {
              type: 'button_reply',
              button_reply: {
                id: button_id,
                title: 'Test Button'
              }
            }
          }]
        },
        field: 'messages'
      }]
    }]
  }
  
  uri = URI(WEBHOOK_URL)
  http = Net::HTTP.new(uri.host, uri.port)
  
  request = Net::HTTP::Post.new(uri.path)
  request['Content-Type'] = 'application/json'
  request.body = payload.to_json
  
  begin
    response = http.request(request)
    log("Webhook response: #{response.code}", GREEN)
    { success: response.code.to_i == 200, response: response.body }
  rescue => e
    log("✗ Webhook error: #{e.message}", RED)
    { success: false, error: e.message }
  end
end

# Main test flow
def main
  log("=" * 50, GREEN)
  log("Interactive Condition Selection Test", GREEN)
  log("=" * 50, GREEN)
  log("")
  
  seller = Seller.find_by(phone_number: SELLER_PHONE)
  unless seller
    log("✗ Seller not found with phone #{SELLER_PHONE}", RED)
    return
  end
  
  log("✓ Found seller: #{seller.fullname}", GREEN)
  log("")
  
  # Upload images
  log("Step 1: Uploading MacBook images", YELLOW)
  log("-" * 50, YELLOW)
  
  images = Dir.glob("#{IMAGE_DIR}/*.png").first(3)
  image_urls = []
  images.each do |image_path|
    url = upload_image_to_cloudinary(image_path)
    image_urls << url if url
  end
  
  if image_urls.empty?
    log("✗ Failed to upload any images", RED)
    return
  end
  
  log("✓ Successfully uploaded #{image_urls.length} images", GREEN)
  log("")
  
  # Start product creation
  log("Step 2: Starting product creation", YELLOW)
  log("-" * 50, YELLOW)
  
  result = send_webhook_text(SELLER_PHONE, 'ADD')
  unless result[:success]
    log("✗ Failed to send ADD command", RED)
    return
  end
  
  log("✓ ADD command sent", GREEN)
  sleep(2)
  
  # Check session
  session = WhatsappProductSession.active.for_phone(SELLER_PHONE).where(seller_id: seller.id).first
  unless session
    log("✗ No session found", RED)
    return
  end
  
  log("✓ Session created: Step #{session.step}", GREEN)
  log("")
  
  # Add images to session
  log("Step 3: Adding images to session", YELLOW)
  log("-" * 50, YELLOW)
  
  session.update_product_data('media', image_urls)
  session.advance_step!
  log("✓ Images added to session, advanced to step #{session.step}", GREEN)
  log("")
  
  # Send title
  log("Step 4: Sending MacBook title", YELLOW)
  log("-" * 50, YELLOW)
  
  result = send_webhook_text(SELLER_PHONE, 'Apple MacBook Pro 14-inch M3 Chip 16GB RAM 512GB SSD')
  unless result[:success]
    log("✗ Failed to send title", RED)
    return
  end
  
  log("✓ Title sent", GREEN)
  sleep(3)
  
  # Check session status
  log("Step 5: Checking session after AI analysis", YELLOW)
  log("-" * 50, YELLOW)
  
  session.reload
  product_data = session.product_data
  
  log("Session step: #{session.step}", GREEN)
  log("Product data:", GREEN)
  log("  Title: #{product_data['title']}", GREEN)
  log("  Brand: #{product_data['brand']}", GREEN)
  log("  Condition: #{product_data['condition']}", GREEN)
  log("")
  
  # Trigger edit mode
  log("Step 6: Triggering edit mode to test condition selection", YELLOW)
  log("-" * 50, YELLOW)
  
  result = send_webhook_text(SELLER_PHONE, 'EDIT')
  unless result[:success]
    log("✗ Failed to send EDIT command", RED)
    return
  end
  
  log("✓ EDIT command sent", GREEN)
  sleep(2)
  
  # Trigger condition selection
  log("Step 7: Triggering condition selection", YELLOW)
  log("-" * 50, YELLOW)
  
  result = send_webhook_text(SELLER_PHONE, 'CONDITION')
  unless result[:success]
    log("✗ Failed to send CONDITION command", RED)
    return
  end
  
  log("✓ CONDITION command sent", GREEN)
  log("")
  
  # Simulate button response for brand_new condition
  log("Step 8: Simulating button response for 'brand_new'", YELLOW)
  log("-" * 50, YELLOW)
  
  result = send_webhook_button(SELLER_PHONE, 'condition_brand_new')
  unless result[:success]
    log("✗ Failed to send button response", RED)
    return
  end
  
  log("✓ Button response sent", GREEN)
  sleep(2)
  
  # Check final session state
  log("Step 9: Checking final session state", YELLOW)
  log("-" * 50, YELLOW)
  
  session.reload
  product_data = session.product_data
  
  log("Session step: #{session.step}", GREEN)
  log("Final condition: #{product_data['condition']}", GREEN)
  log("")
  
  log("=" * 50, GREEN)
  log("Test completed", GREEN)
  log("=" * 50, GREEN)
end

main
