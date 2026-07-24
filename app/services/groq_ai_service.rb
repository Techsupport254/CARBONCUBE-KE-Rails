# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

class GroqAiService
  GROQ_API_KEY = ENV['GROQ_API_KEY']
  BASE_URL = 'https://api.groq.com/openai/v1/chat/completions'
  MODEL = 'meta-llama/llama-4-scout-17b-16e-instruct'

  def self.analyze_images(image_urls, title = nil, context = {})
    return { success: false, error: "Groq API key not configured" } unless GROQ_API_KEY
    return { success: false, error: "No image URLs provided" } if image_urls.blank?

    begin
      # Use up to 3 image URLs for the vision prompt
      urls_to_analyze = image_urls.first(3)

      # Build the image_url content blocks for Groq vision
      image_content = urls_to_analyze.map do |img_url|
        { type: 'image_url', image_url: { url: img_url } }
      end

      # Build the prompt for product analysis
      context_lines = []
      context_lines << "Product title: '#{title}'" if title.present?
      context_lines << "Category: '#{context[:category]}'" if context[:category].present?
      context_lines << "Subcategory: '#{context[:subcategory]}'" if context[:subcategory].present?
      context_lines << "Brand: '#{context[:brand]}'" if context[:brand].present?
      context_lines << "Condition: '#{context[:condition]}'" if context[:condition].present?
      context_lines << "Price: '#{context[:price]}'" if context[:price].present?
      context_lines << "Key specifications: #{context[:specifications].to_json}" if context[:specifications].present?
      context_text = context_lines.any? ? "\nAdditional context:\n" + context_lines.map { |l| "- #{l}" }.join("\n") : ''

      prompt = "Analyze these product image(s) and extract the following information in JSON format:
{
  \"detected_objects\": [list of main objects detected],
  \"category\": [suggested product category],
  \"subcategory\": [suggested product subcategory if inferable],
  \"brand\": [brand name if detectable],
  \"condition\": [estimated condition: brand_new, second_hand, refurbished],
  \"confidence\": [overall confidence score 0-1],
  \"description\": [SEO-optimized product description for Kenyan e-commerce]
}
#{context_text}

The description should be concise (1-2 sentences), natural, and SEO-friendly: include the product name/title, category, brand if known, key selling point or use case, and a subtle call to action for Kenyan buyers. Use relevant keywords naturally without stuffing. Use the provided context when available, but infer from the image if any value is missing. Focus on accuracy for e-commerce product classification."

      # Build the messages array
      messages = [
        { role: 'user', content: image_content + [{ type: 'text', text: prompt }] }
      ]

      uri = URI(BASE_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{GROQ_API_KEY}"
      request['Content-Type'] = 'application/json'
      request.body = {
        model: MODEL,
        messages: messages,
        max_tokens: 1000,
        temperature: 0.1
      }.to_json

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error "Groq API error: #{response.code} - #{response.body}"
        return { success: false, error: "Groq API returned #{response.code}" }
      end

      groq_data = JSON.parse(response.body)
      raw_content = groq_data.dig('choices', 0, 'message', 'content').to_s.strip

      # Strip markdown fences if model wraps the JSON
      raw_content = raw_content.gsub(/\A```(?:json)?\s*/i, '').gsub(/\s*```\z/, '').strip

      # Try to extract JSON from the response
      json_match = raw_content.match(/\{[\s\S]*\}/)
      if json_match
        json_content = json_match[0]
        analysis_result = JSON.parse(json_content)
      else
        # Fallback: Try to parse the entire response as JSON
        analysis_result = JSON.parse(raw_content)
      end

      # Normalize brand to always be a string
      brand_value = analysis_result['brand']
      normalized_brand = if brand_value.is_a?(Array)
                           brand_value.first
                         elsif brand_value.is_a?(String)
                           brand_value
                         else
                           nil
                         end

      {
        success: true,
        detected_objects: analysis_result['detected_objects'] || [],
        category: analysis_result['category'],
        brand: normalized_brand,
        condition: analysis_result['condition'],
        confidence: analysis_result['confidence'] || 0.5,
        description: analysis_result['description'],
        raw_response: analysis_result
      }

    rescue JSON::ParserError => e
      Rails.logger.error "Groq JSON parse error: #{e.message}"
      { success: false, error: "AI returned an unexpected format. Please try again." }
    rescue => e
      Rails.logger.error "Groq AI error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      { success: false, error: "Failed to analyze images: #{e.message}" }
    end
  end

  def self.available?
    GROQ_API_KEY.present?
  end
end
