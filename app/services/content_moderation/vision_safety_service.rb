# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'open-uri'
require 'base64'
require 'cloudinary'

module ContentModeration
  class VisionSafetyService
    GROQ_API_KEY = ENV['GROQ_API_KEY']
    GEMINI_API_KEY = ENV['GEMINI_API_KEY']
    BASE_URL = 'https://api.groq.com/openai/v1/chat/completions'
    VISION_MODEL = 'qwen/qwen3.6-27b'

    PROMPT = <<~PROMPT
      Analyze this product image for e-commerce safety and moderation.
      Check for:
      1. NSFW, adult, sexually suggestive/revealing lingerie/swimwear, nudity, or graphic content.
      2. Mismatch between an e-commerce catalog image vs inappropriate/unrelated media.

      Output JSON:
      {
        "is_nsfw": true/false,
        "nsfw_score": 0-100,
        "category": "SAFE" | "SUGGESTIVE" | "EXPLICIT_ADULT" | "VIOLENCE" | "SPAM",
        "description": "<one sentence description of image content>"
      }
    PROMPT

    def self.evaluate_images(image_urls, product_title = nil)
      return { nsfw_score: 0, is_nsfw: false, reason: 'No images provided' } if image_urls.blank?

      images_to_check = image_urls.first(2)
      highest_nsfw_score = 0
      detected_reason = nil
      is_nsfw_flag = false
      provider_used = nil

      images_to_check.each do |img_url|
        next if img_url.blank?

        # -------------------------------------------------------------
        # OPTION 1: CLOUDINARY MODERATION API (First Priority)
        # -------------------------------------------------------------
        cloudinary_res = check_cloudinary_moderation(img_url)
        if cloudinary_res[:evaluated]
          if cloudinary_res[:nsfw_score] >= highest_nsfw_score
            highest_nsfw_score = cloudinary_res[:nsfw_score]
            detected_reason = cloudinary_res[:reason]
            is_nsfw_flag = cloudinary_res[:is_nsfw]
            provider_used = 'cloudinary'
          end
          next if is_nsfw_flag # If Cloudinary flagged, proceed
        end

        # -------------------------------------------------------------
        # OPTION 2: MULTIMODAL VISION AI (Gemini Flash Vision)
        # -------------------------------------------------------------
        gemini_res = check_gemini_vision(img_url)
        if gemini_res[:evaluated]
          if gemini_res[:nsfw_score] >= highest_nsfw_score
            highest_nsfw_score = gemini_res[:nsfw_score]
            detected_reason = gemini_res[:reason]
            is_nsfw_flag = gemini_res[:is_nsfw]
            provider_used = 'gemini_vision'
          end
          next if is_nsfw_flag
        end

        # -------------------------------------------------------------
        # OPTION 3: GROQ VISION FALLBACK
        # -------------------------------------------------------------
        groq_res = check_groq_vision(img_url)
        if groq_res[:evaluated]
          if groq_res[:nsfw_score] >= highest_nsfw_score
            highest_nsfw_score = groq_res[:nsfw_score]
            detected_reason = groq_res[:reason]
            is_nsfw_flag = groq_res[:is_nsfw]
            provider_used ||= 'groq_vision'
          end
        end
      end

      {
        is_nsfw: is_nsfw_flag,
        nsfw_score: highest_nsfw_score,
        reason: detected_reason || 'Image safety verified',
        provider: provider_used
      }
    end

    def self.check_cloudinary_moderation(img_url)
      return { evaluated: false } unless img_url.to_s.include?('cloudinary.com')
      return { evaluated: false } if Rails.cache.read("cloudinary_moderation_rate_limited")

      public_id = extract_cloudinary_public_id(img_url)
      return { evaluated: false } unless public_id.present?

      begin
        res = Cloudinary::Api.resource(public_id, moderation: true)
        moderation_entries = res['moderation']

        if moderation_entries.is_a?(Array) && moderation_entries.any?
          rejected_entry = moderation_entries.find { |m| m['status'] == 'rejected' }
          pending_entry = moderation_entries.find { |m| m['status'] == 'pending' }

          if rejected_entry
            kind = rejected_entry['kind'] || 'Cloudinary AI'
            return {
              evaluated: true,
              is_nsfw: true,
              nsfw_score: 95,
              reason: "Flagged by Cloudinary Moderation (#{kind})"
            }
          elsif pending_entry
            return {
              evaluated: true,
              is_nsfw: false,
              nsfw_score: 50,
              reason: "Pending Cloudinary Moderation Review"
            }
          else
            return {
              evaluated: true,
              is_nsfw: false,
              nsfw_score: 0,
              reason: "Approved by Cloudinary Moderation"
            }
          end
        end

        { evaluated: false }
      rescue => e
        msg = e.message.to_s.downcase
        if msg.include?('rate limit') || msg.include?('limit of 2000') || msg.include?('429')
          Rails.cache.write("cloudinary_moderation_rate_limited", true, expires_in: 10.minutes)
          Rails.logger.debug { "Cloudinary Admin API rate limit reached, cooling down" }
        elsif msg.include?('not found') || msg.include?('404')
          Rails.logger.debug { "Cloudinary resource not found for #{public_id}" }
        else
          Rails.logger.warn "Cloudinary moderation check exception for #{public_id}: #{e.message}"
        end
        { evaluated: false }
      end
    end


    def self.check_gemini_vision(img_url)
      return { evaluated: false } unless GEMINI_API_KEY.present?

      begin
        image_data = URI.parse(img_url).open(read_timeout: 12, open_timeout: 6).read
        base64_image = Base64.strict_encode64(image_data)

        uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=#{GEMINI_API_KEY}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 15
        http.open_timeout = 6

        req = Net::HTTP::Post.new(uri)
        req['Content-Type'] = 'application/json'
        req.body = {
          contents: [
            {
              parts: [
                { text: PROMPT },
                {
                  inline_data: {
                    mime_type: 'image/jpeg',
                    data: base64_image
                  }
                }
              ]
            }
          ],
          generationConfig: { response_mime_type: 'application/json' }
        }.to_json

        res = http.request(req)
        return { evaluated: false } unless res.is_a?(Net::HTTPSuccess)

        parsed_body = JSON.parse(res.body)
        output_text = parsed_body.dig('candidates', 0, 'content', 'parts', 0, 'text').to_s.strip
        parsed = JSON.parse(output_text)

        score = parsed['nsfw_score'].to_i.clamp(0, 100)
        is_nsfw = parsed['is_nsfw'] == true || score >= 50

        {
          evaluated: true,
          is_nsfw: is_nsfw,
          nsfw_score: score,
          reason: parsed['description'] || 'Evaluated by Vision AI'
        }
      rescue Net::ReadTimeout, Net::OpenTimeout, SocketError => e
        Rails.logger.debug { "Gemini Vision network timeout/socket issue for #{img_url}: #{e.message}" }
        { evaluated: false }
      rescue => e
        Rails.logger.warn "Gemini Vision check exception for #{img_url}: #{e.message}"
        { evaluated: false }
      end
    end

    def self.check_groq_vision(img_url)
      return { evaluated: false } unless GROQ_API_KEY.present?

      begin
        uri = URI(BASE_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 15
        http.open_timeout = 5

        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer #{GROQ_API_KEY}"
        request['Content-Type'] = 'application/json'
        request.body = {
          model: VISION_MODEL,
          messages: [
            {
              role: 'user',
              content: [
                { type: 'image_url', image_url: { url: img_url } },
                { type: 'text', text: PROMPT }
              ]
            }
          ],
          max_tokens: 1500,
          temperature: 0.0
        }.to_json

        response = http.request(request)
        return { evaluated: false } unless response.is_a?(Net::HTTPSuccess)

        data = JSON.parse(response.body)
        raw_content = data.dig('choices', 0, 'message', 'content').to_s.strip

        json_text = raw_content.gsub(%r{<think>[\s\S]*?</think>}i, '').strip
        match = json_text.match(/\{[\s\S]*\}/)

        if match
          parsed = JSON.parse(match[0])
          score = parsed['nsfw_score'].to_i.clamp(0, 100)
          is_nsfw = parsed['is_nsfw'] == true || score >= 50
          {
            evaluated: true,
            is_nsfw: is_nsfw,
            nsfw_score: score,
            reason: parsed['description'] || 'Evaluated by AI Vision'
          }
        else
          { evaluated: false }
        end
      rescue => e
        Rails.logger.warn "Groq Vision check exception: #{e.message}"
        { evaluated: false }
      end
    end

    def self.extract_cloudinary_public_id(url)
      match = url.to_s.match(%r{/upload/(?:v\d+/)?([^.?]+)})
      match ? match[1].split('/').last : nil
    end

    private_class_method :check_cloudinary_moderation, :check_gemini_vision, :check_groq_vision, :extract_cloudinary_public_id
  end
end
