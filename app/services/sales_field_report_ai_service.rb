# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

class SalesFieldReportAiService
  GROQ_API_KEY = ENV['GROQ_API_KEY']
  BASE_URL = 'https://api.groq.com/openai/v1/chat/completions'
  MODEL = 'llama-3.3-70b-versatile'

  TAXONOMY = {
    'app_technical' => 'App / Technical Bugs (refreshing, camera, uploads, login)',
    'seller_trust' => 'Seller Trust & Hesitation (reluctance, fear of scams, wanting time to think)',
    'seller_hardware_rejection' => 'Hardware Store Friction (hard to crack, rejection by large hardware stores)',
    'seller_device_constraints' => 'Seller Smartphone Constraints (welders/traders have no smartphone or feature phones only)',
    'airtime_bundles' => 'Airtime & Data Bundles (need airtime/data credit for onboarding/calling leads)',
    'transport_reimbursement' => 'Transport / Travel (bus fare, commute, transport reimbursement requests)',
    'platform_presence' => 'Online Presence & Buyer Demand (sellers questioning website visibility/marketing)',
    'external_environment' => 'External Disruptions (power blackouts, heavy rain, market closures)',
    'ad_uploads_assist' => 'Ad Upload Assistance (need help uploading 5+ products/photos)'
  }.freeze

  def self.parse_and_categorize(raw_text: nil, route_areas: nil, visited: nil, onboarded: nil, challenges: nil, notes: nil)
    input_text = raw_text.to_s.strip
    if input_text.blank?
      input_text = [
        ("Route/Areas: #{route_areas}" if route_areas.present?),
        ("Businesses Visited: #{visited}" if visited.present?),
        ("Businesses Onboarded: #{onboarded}" if onboarded.present?),
        ("Challenges: #{challenges}" if challenges.present?),
        ("Notes: #{notes}" if notes.present?)
      ].compact.join("\n")
    end

    return fallback_analysis(input_text, route_areas, visited, onboarded, challenges, notes) if input_text.blank?

    if GROQ_API_KEY.present?
      ai_result = call_groq_ai(input_text, route_areas, visited, onboarded, challenges, notes)
      return ai_result if ai_result && ai_result[:success]
    end

    fallback_analysis(input_text, route_areas, visited, onboarded, challenges, notes)
  end

  private

  def self.call_groq_ai(input_text, orig_route, orig_visited, orig_onboarded, orig_challenges, orig_notes)
    prompt = <<~PROMPT
      You are an AI Operations Assistant for Carbon Cube Kenya (e-commerce marketplace).
      Your job is to parse and categorize field sales reports from sales representatives.

      Given the following field notes or text:
      """
      #{input_text}
      """

      Extract and return a STRICT JSON object with these keys:
      {
        "route_areas": "Locations/towns visited (e.g. 'Kenol & Kimworori', 'Rongai, Tumaini Center', 'Kondele Kisumu')",
        "businesses_visited": <integer count of businesses visited, or 0 if not mentioned>,
        "businesses_onboarded": <integer count of businesses onboarded, or 0 if not mentioned>,
        "challenges": "Concise summary of obstacles, complaints, or friction faced by rep and sellers",
        "notes": "Follow-ups, prospective leads, or additional requests mentioned",
        "categories": ["array of matching category keys strictly from: app_technical, seller_trust, seller_hardware_rejection, seller_device_constraints, airtime_bundles, transport_reimbursement, platform_presence, external_environment, ad_uploads_assist"],
        "ai_summary": "1-2 sentence executive briefing for management summarizing what the rep did, conversion, and main blocker",
        "sentiment": "<'positive' | 'neutral' | 'challenging' | 'critical'>",
        "urgency": "<'low' | 'medium' | 'high'>",
        "action_items": ["array of specific follow-up actions for managers/leads, e.g. 'Reimburse airtime for rep', 'Follow up with 3 prospective leads'"]
      }

      Ensure numbers are integers. Preserve local Kenyan place names (Kenol, Rongai, Kondele, Migosi, Kisumu, Olekasasi, Maasai Lodge, etc.).
    PROMPT

    uri = URI(BASE_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    http.open_timeout = 5

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{GROQ_API_KEY}"
    request['Content-Type'] = 'application/json'
    request.body = {
      model: MODEL,
      messages: [
        { role: 'system', content: 'You are an accurate e-commerce operations JSON extractor.' },
        { role: 'user', content: prompt }
      ],
      max_tokens: 600,
      temperature: 0.1
    }.to_json

    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)
    content = body.dig('choices', 0, 'message', 'content').to_s.strip
    content = content.gsub(/\A```(?:json)?\s*/i, '').gsub(/\s*```\z/, '').strip

    json_match = content.match(/\{[\s\S]*\}/)
    parsed = json_match ? JSON.parse(json_match[0]) : JSON.parse(content)

    categories = (parsed['categories'] || []).select { |c| TAXONOMY.key?(c) }
    categories = rule_based_categories(input_text) if categories.empty?

    {
      success: true,
      route_areas: parsed['route_areas'].presence || orig_route || 'Field Locations',
      businesses_visited: (parsed['businesses_visited'] || orig_visited || 0).to_i,
      businesses_onboarded: (parsed['businesses_onboarded'] || orig_onboarded || 0).to_i,
      challenges: parsed['challenges'].presence || orig_challenges,
      notes: parsed['notes'].presence || orig_notes,
      categories: categories,
      ai_summary: parsed['ai_summary'].presence,
      sentiment: parsed['sentiment'].presence || 'neutral',
      urgency: parsed['urgency'].presence || 'medium',
      action_items: parsed['action_items'] || []
    }
  rescue => e
    Rails.logger.error "SalesFieldReportAiService error: #{e.message}"
    nil
  end

  def self.fallback_analysis(text, orig_route, orig_visited, orig_onboarded, orig_challenges, orig_notes)
    categories = rule_based_categories(text)

    # Heuristic integer extraction if visited or onboarded is missing
    visited = orig_visited.to_i
    onboarded = orig_onboarded.to_i

    if visited.zero? && text =~ /(?:visited|met|talked to|covered)\s*(\d+)/i
      visited = $1.to_i
    end

    if onboarded.zero? && text =~ /(?:onboarded|signed up|registered|added)\s*(\d+)/i
      onboarded = $1.to_i
    end

    route = orig_route.presence
    if route.blank? && text =~ /(?:worked at|was in|visited businesses around|around)\s*([A-Za-z0-9\s,\/&-]+?)(?:\.|\n|onboarded|visited|\d+)/i
      route = $1.strip
    end

    sentiment = if categories.include?('app_technical') || categories.include?('airtime_bundles')
                  'challenging'
                elsif onboarded >= 3
                  'positive'
                else
                  'neutral'
                end

    urgency = categories.include?('airtime_bundles') || categories.include?('app_technical') ? 'high' : 'medium'

    summary = if visited > 0
                "Rep visited #{visited} businesses and onboarded #{onboarded} businesses in #{route || 'field areas'}."
              else
                "Field report recorded for #{route || 'field areas'}."
              end

    {
      success: true,
      route_areas: route || 'Field Areas',
      businesses_visited: visited,
      businesses_onboarded: onboarded,
      challenges: orig_challenges.presence || text,
      notes: orig_notes,
      categories: categories,
      ai_summary: summary,
      sentiment: sentiment,
      urgency: urgency,
      action_items: generate_action_items(categories)
    }
  end

  def self.rule_based_categories(text)
    t = text.to_s.downcase
    cats = []

    cats << 'app_technical' if t =~ /app|refresh|crash|camera|upload|log(ged)? out|password|bug|stuck/
    cats << 'seller_trust' if t =~ /trust|hesitant|skeptical|scam|think over|think about|reluctant|jiji/
    cats << 'seller_hardware_rejection' if t =~ /hardware|hard to crack|rejection/
    cats << 'seller_device_constraints' if t =~ /smart\s*phone|welder|kiosk|no phone|button phone|feature phone/
    cats << 'airtime_bundles' if t =~ /airtime|bundle|credit|data|call prospective|calling/
    cats << 'transport_reimbursement' if t =~ /transport|fare|reimburse|commute/
    cats << 'platform_presence' if t =~ /online presence|visibility|traffic|buyer/
    cats << 'external_environment' if t =~ /power|blackout|rain|weather|closed early/
    cats << 'ad_uploads_assist' if t =~ /ads|products|photo|upload.*ads/

    cats.uniq
  end

  def self.generate_action_items(categories)
    items = []
    items << 'Review rep airtime & data bundle allocation' if categories.include?('airtime_bundles')
    items << 'Check app camera/refresh logs with IT technical officer' if categories.include?('app_technical')
    items << 'Assist rep with ad uploads and photo guidelines' if categories.include?('ad_uploads_assist')
    items << 'Provide reassurance marketing collateral for hesitant sellers' if categories.include?('seller_trust')
    items
  end
end
