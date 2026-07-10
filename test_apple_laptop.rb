#!/usr/bin/env ruby
# Test script to check what AI detects from Apple MacBook images

require 'cloudinary'
require_relative 'config/environment'

IMAGE_DIR = '/home/kirui/Desktop/Carbon/imgs'

# Upload and analyze each image
images = Dir.glob("#{IMAGE_DIR}/*.png").first(3)

images.each do |image_path|
  puts "=" * 60
  puts "Analyzing: #{File.basename(image_path)}"
  puts "=" * 60
  
  # Upload to Cloudinary
  result = Cloudinary::Uploader.upload(
    image_path,
    upload_preset: ENV['UPLOAD_PRESET'],
    folder: 'test_analysis',
    resource_type: 'image'
  )
  
  if result && result['secure_url']
    puts "Uploaded: #{result['secure_url']}"
    
    # Try Cloudinary AI analysis
    begin
      cloudinary_response = Cloudinary::Api.resource(result['public_id'], 
        analysis: true,
        analysis_type: 'coco_v2'
      )
      
      if cloudinary_response && cloudinary_response['analysis']
        puts "\nCloudinary Analysis:"
        puts "Tags: #{cloudinary_response['analysis']['tags']&.map { |t| "#{t['tag']} (#{(t['confidence'] * 100).to_i}%)" }&.join(', ')}"
        puts "Categories: #{cloudinary_response['analysis']['categories']&.map { |c| c['name'] }&.join(', ')}"
      end
    rescue => e
      puts "Cloudinary analysis failed: #{e.message}"
    end
    
    # Try Groq AI analysis
    if GroqAiService.available?
      groq_result = GroqAiService.analyze_images([result['secure_url']])
      puts "\nGroq AI Analysis:"
      puts "Success: #{groq_result[:success]}"
      puts "Detected Objects: #{groq_result[:detected_objects]&.join(', ')}"
      puts "Brand: #{groq_result[:brand]}"
      puts "Category: #{groq_result[:category]}"
      puts "Confidence: #{groq_result[:confidence]}"
    end
  end
  
  puts ""
end
