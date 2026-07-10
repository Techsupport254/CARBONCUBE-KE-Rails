#!/usr/bin/env ruby
# Test script for WhatsApp image upload functionality - Fixed version

require 'net/http'
require 'uri'
require 'json'
require 'cloudinary'

# Load Rails environment
require_relative 'config/environment'

# Configuration
BASE_URL = 'http://localhost:3001'
WEBHOOK_URL = "#{BASE_URL}/webhooks/whatsapp"
SELLER_PHONE = '0712345678' # Change this to a valid seller phone number
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

# Simulate WhatsApp webhook with images
def send_webhook_with_images(phone_number, image_urls)
  log("Sending webhook with #{image_urls.length} images...", YELLOW)
  
  # Create a realistic WhatsApp webhook payload with images
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
            type: 'image',
            image: {
              id: "media_test_#{Time.now.to_i}",
              caption: "Test product images"
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
    log("Webhook response: #{response.code} - #{response.body[0..200]}...", GREEN)
    { success: response.code.to_i == 200, response: response.body }
  rescue => e
    log("✗ Webhook error: #{e.message}", RED)
    { success: false, error: e.message }
  end
end

# Simulate text message (for ADD command, title, etc.)
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

# Main test flow
def main
  log("=" * 50, GREEN)
  log("WhatsApp Image Upload Test - Fixed", GREEN)
  log("=" * 50, GREEN)
  log("")
  
  # Check if seller exists
  seller = Seller.find_by(phone_number: SELLER_PHONE)
  unless seller
    log("✗ Seller not found with phone #{SELLER_PHONE}", RED)
    log("Please create a seller first or update SELLER_PHONE in the script", RED)
    return
  end
  
  log("✓ Found seller: #{seller.fullname} (#{seller.phone_number})", GREEN)
  log("")
  
  # Step 1: Upload images to Cloudinary
  log("Step 1: Uploading test images to Cloudinary", YELLOW)
  log("-" * 50, YELLOW)
  
  images = Dir.glob("#{IMAGE_DIR}/*.png").first(3)
  if images.empty?
    log("✗ No images found in #{IMAGE_DIR}", RED)
    return
  end
  
  image_urls = []
  images.each do |image_path|
    url = upload_image_to_cloudinary(image_path)
    image_urls << url if url
  end
  
  if image_urls.empty?
    log("✗ Failed to upload any images", RED)
    return
  end
  
  log("")
  log("✓ Successfully uploaded #{image_urls.length} images", GREEN)
  log("")
  
  # Step 2: Send ADD command to start product creation
  log("Step 2: Starting product creation with ADD command", YELLOW)
  log("-" * 50, YELLOW)
  
  result = send_webhook_text(SELLER_PHONE, 'ADD')
  unless result[:success]
    log("✗ Failed to send ADD command", RED)
    return
  end
  
  log("✓ ADD command sent", GREEN)
  log("")
  
  # Wait a moment for session creation
  sleep(2)
  
  # Step 3: Check if session was created
  log("Step 3: Checking session status", YELLOW)
  log("-" * 50, YELLOW)
  
  session = WhatsappProductSession.active.for_phone(SELLER_PHONE).where(seller_id: seller.id).first
  if session
    log("✓ Session created: Step #{session.step}", GREEN)
  else
    log("✗ No session found", RED)
  end
  log("")
  
  # Step 4: Send images (simulate by updating session directly since webhook can't handle actual media)
  log("Step 4: Adding images to session", YELLOW)
  log("-" * 50, YELLOW)
  
  if session
    session.update_product_data('media', image_urls)
    session.advance_step! # Move to step 2 (title)
    log("✓ Images added to session, advanced to step #{session.step}", GREEN)
  else
    log("✗ Cannot add images - no session", RED)
    return
  end
  log("")
  
  # Step 5: Send product title
  log("Step 5: Sending product title", YELLOW)
  log("-" * 50, YELLOW)
  
  result = send_webhook_text(SELLER_PHONE, 'Samsung Galaxy S24 Ultra 5G 256GB')
  unless result[:success]
    log("✗ Failed to send title", RED)
    return
  end
  
  log("✓ Title sent", GREEN)
  log("")
  
  # Wait for AI processing
  sleep(3)
  
  # Step 6: Check session status after AI analysis
  log("Step 6: Checking session after AI analysis", YELLOW)
  log("-" * 50, YELLOW)
  
  session.reload
  product_data = session.product_data
  
  log("Session step: #{session.step}", GREEN)
  log("Product data:", GREEN)
  log("  Title: #{product_data['title']}", GREEN)
  log("  Images: #{product_data['media']&.length || 0}", GREEN)
  log("  Category ID: #{product_data['category_id']}", GREEN)
  log("  Brand: #{product_data['brand']}", GREEN)
  log("  Condition: #{product_data['condition']}", GREEN)
  log("  AI Confidence: #{product_data['ai_confidence']}", GREEN)
  log("  Suggested Price: #{product_data['suggested_price']}", GREEN)
  log("")
  
  # Step 7: Set price manually if AI didn't suggest one
  unless product_data['suggested_price']
    log("Step 7: Setting price manually (AI didn't suggest one)", YELLOW)
    log("-" * 50, YELLOW)
    
    # Set a reasonable price for the phone
    session.update_product_data('price', 150000)
    session.update_product_data('suggested_price', 150000)
    log("✓ Price set to KES 150,000", GREEN)
    log("")
  end
  
  # Step 8: Send CONFIRM to create product
  log("Step 8: Confirming product creation", YELLOW)
  log("-" * 50, YELLOW)
  
  result = send_webhook_text(SELLER_PHONE, 'CONFIRM')
  unless result[:success]
    log("✗ Failed to send CONFIRM", RED)
    return
  end
  
  log("✓ CONFIRM sent", GREEN)
  log("")
  
  # Wait for product creation
  sleep(2)
  
  # Step 9: Check if product was created
  log("Step 9: Verifying product creation", YELLOW)
  log("-" * 50, YELLOW)
  
  session.reload
  if session.status == 'completed'
    log("✓ Session completed successfully!", GREEN)
    
    # Find the created ad
    recent_ad = seller.ads.order(created_at: :desc).first
    if recent_ad
      log("✓ Product created: #{recent_ad.title}", GREEN)
      log("  Ad ID: #{recent_ad.id}", GREEN)
      log("  Price: KES #{recent_ad.price}", GREEN)
      log("  Images: #{recent_ad.media&.length || 0}", GREEN)
      log("  Category: #{recent_ad.category&.name}", GREEN)
      log("  Brand: #{recent_ad.brand}", GREEN)
      log("  Condition: #{recent_ad.condition}", GREEN)
    else
      log("⚠ Session completed but no ad found", YELLOW)
    end
  else
    log("✗ Session not completed. Status: #{session.status}", RED)
    log("Product data:", RED)
    product_data = session.product_data
    product_data.each do |key, value|
      log("  #{key}: #{value}", RED)
    end
  end
  
  log("")
  log("=" * 50, GREEN)
  log("Test completed", GREEN)
  log("=" * 50, GREEN)
end

# Run the test
main
