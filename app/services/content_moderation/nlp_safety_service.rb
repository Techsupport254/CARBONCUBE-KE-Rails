# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module ContentModeration
  class NlpSafetyService
    GROQ_API_KEY = ENV['GROQ_API_KEY']
    BASE_URL = 'https://api.groq.com/openai/v1/chat/completions'
    MODEL = 'openai/gpt-oss-20b'

    SYSTEM_INSTRUCTIONS = <<~PROMPT
      You are an enterprise Trust & Safety AI classifier for Carbon Cube Kenya (an East African e-commerce marketplace).
      Your sole mission is to classify user-generated product listings and messages to detect genuine harms while RIGOROUSLY avoiding false positives on legitimate commerce.

      VIOLATION TAXONOMY:
      1. FRAUD_SCAM: Demands upfront non-refundable deposits/fare/commitment fee before viewing, fake M-Pesa transaction scripts, phishing links, counterfeit currency ("wash wash"), unrealistic scam prices (e.g. iPhone 15 Pro for 10k).
      2. PROHIBITED_GOODS: Unregistered firearms/weapons, illegal drugs/narcotics, prescription abortifacients (cytotec/misoprostol), forged ID/passports/certificates, stolen property.
      3. ADULT_SERVICES: Commercial escort/prostitution services, explicit erotic massages with happy endings, pornography.
      4. HATE_HARASSMENT: Hate speech against protected groups, targeted harassment, violent threats.

      STRICT FALSE POSITIVE PREVENTION RULES (ALWAYS MARK THESE AS SAFE / RISK 0-15):
      - Everyday tools & electronics: "massage gun", "gunmetal grey laptop", "glue gun", "heat gun", "nail gun", "kitchen knife set", "tactical torch", "hunting boots", "paintball gun" ARE 100% SAFE.
      - Fashion & apparel: "cocktail dress", "sexy lingerie", "bikini", "bodycon", "swimsuit" ARE 100% SAFE (unless offering escort services).
      - Local trade terms & Sheng: "luku safi", "kamata offer", "bei ya kuongea", "lipa na mpesa on delivery", "pick up in town", "deliveries countrywide" ARE 100% SAFE.
      - Real estate / Car rental deposits: Standard refundable security deposits stated in normal commercial terms ARE SAFE.
      - Agricultural, industrial, and construction equipment (e.g. valves, pipes, pumps) ARE 100% SAFE.

      OUTPUT FORMAT:
      Respond STRICTLY with a valid JSON object matching this schema:
      {
        "risk_score": <integer from 0 to 100>,
        "violation_detected": <boolean>,
        "category": <"NONE" | "FRAUD_SCAM" | "PROHIBITED_GOODS" | "ADULT_SERVICES" | "HATE_HARASSMENT">,
        "confidence": <float between 0.0 and 1.0>,
        "reason": "<one concise sentence explaining verdict>"
      }
    PROMPT

    def self.evaluate(title, description, category_name = nil, price = nil)
      return safe_fallback('Empty content') if title.blank? && description.blank?
      return local_fallback(title, description) unless GROQ_API_KEY.present?
      return local_fallback(title, description) if Rails.cache.read("groq_moderation_rate_limited")

      context_text = []
      context_text << "Product Title: #{title}" if title.present?
      context_text << "Category: #{category_name}" if category_name.present?
      context_text << "Price (KES): #{price}" if price.present?
      context_text << "Description: #{description}" if description.present?

      user_prompt = "Evaluate this listing:\n\n#{context_text.join("\n")}"

      begin
        uri = URI(BASE_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 8
        http.open_timeout = 4

        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer #{GROQ_API_KEY}"
        request['Content-Type'] = 'application/json'
        request.body = {
          model: MODEL,
          messages: [
            { role: 'system', content: SYSTEM_INSTRUCTIONS },
            { role: 'user', content: user_prompt }
          ],
          response_format: { type: 'json_object' },
          max_tokens: 300,
          temperature: 0.0
        }.to_json

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          if response.code.to_i == 429
            Rails.cache.write("groq_moderation_rate_limited", true, expires_in: 3.seconds)
            Rails.logger.debug { "Groq Moderation API rate limited (429), cooling down for 3s" }
          else
            Rails.logger.warn "Groq Moderation API returned #{response.code}: #{response.body}"
          end
          return local_fallback(title, description)
        end

        data = JSON.parse(response.body)
        raw_content = data.dig('choices', 0, 'message', 'content').to_s.strip
        parsed = JSON.parse(raw_content)

        {
          success: true,
          risk_score: parsed['risk_score'].to_i.clamp(0, 100),
          violation_detected: parsed['violation_detected'] == true,
          category: parsed['category'] || 'NONE',
          confidence: (parsed['confidence'] || 0.8).to_f.clamp(0.0, 1.0),
          reason: parsed['reason'] || 'Evaluated by Groq AI Safety Engine'
        }
      rescue JSON::ParserError => e
        Rails.logger.error "Groq JSON Parse Error: #{e.message}"
        local_fallback(title, description)
      rescue => e
        Rails.logger.error "Groq API Error in NlpSafetyService: #{e.message}"
        local_fallback(title, description)
      end
    end


    def self.local_fallback(title, description)
      # Deterministic fallback when AI API is unavailable
      heuristic = HeuristicRuleEvaluator.evaluate(title, description)
      {
        success: true,
        risk_score: heuristic[:risk_score],
        violation_detected: heuristic[:violation_detected],
        category: heuristic[:category],
        confidence: 0.7,
        reason: heuristic[:reason]
      }
    end

    def self.safe_fallback(reason)
      {
        success: true,
        risk_score: 0,
        violation_detected: false,
        category: 'NONE',
        confidence: 1.0,
        reason: reason
      }
    end
  end
end
