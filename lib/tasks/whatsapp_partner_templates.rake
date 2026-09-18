# frozen_string_literal: true

# Creates the partner-lifecycle WhatsApp message templates on the WABA via
# the Meta Graph API. Templates are business-initiated messages — required
# whenever the invitee hasn't messaged us inside the 24h service window.
#
#   bin/rails whatsapp:list_templates        # show all templates on the WABA
#   bin/rails whatsapp:create_partner_templates
#
# Approval is usually instant for UTILITY templates; Meta may re-categorize
# copy it considers promotional to MARKETING — the sends work either way.
namespace :whatsapp do
  desc 'List all WhatsApp message templates on the WABA'
  task list_templates: :environment do
    require 'net/http'
    require 'json'

    uri = URI("#{WhatsAppCloudService::GRAPH_URL}/#{ENV['WHATSAPP_CLOUD_WABA_ID']}/message_templates" \
              '?limit=100&fields=name,status,category,language')
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{ENV['WHATSAPP_CLOUD_ACCESS_TOKEN']}"
    res = graph_request(uri, req)
    data = JSON.parse(res.body)

    if data['error']
      puts "API error: #{data['error'].inspect}"
    else
      (data['data'] || []).each do |t|
        puts "#{t['name'].ljust(45)} #{t['status'].ljust(10)} #{t['category'].ljust(14)} #{t['language']}"
      end
    end
  end

  desc 'Create the partner invite/update WhatsApp templates (idempotent-ish: skips names that already exist)'
  task create_partner_templates: :environment do
    require 'net/http'
    require 'json'

    waba = ENV['WHATSAPP_CLOUD_WABA_ID']
    token = ENV['WHATSAPP_CLOUD_ACCESS_TOKEN']
    abort 'Missing WHATSAPP_CLOUD_WABA_ID or WHATSAPP_CLOUD_ACCESS_TOKEN' if waba.blank? || token.blank?

    existing = template_names(waba, token)

    partner_templates.each do |tpl|
      if existing.include?(tpl[:name])
        puts "SKIP   #{tpl[:name]} — already exists"
        next
      end

      components = [
        { type: 'BODY', text: tpl[:body], example: { body_text: [tpl[:example]] } }
      ]
      components << { type: 'BUTTONS', buttons: [join_button] } if tpl[:join_button]

      uri = URI("#{WhatsAppCloudService::GRAPH_URL}/#{waba}/message_templates")
      req = Net::HTTP::Post.new(uri.path)
      req['Authorization'] = "Bearer #{token}"
      req['Content-Type'] = 'application/json'
      req.body = {
        name: tpl[:name],
        category: 'UTILITY',
        language: 'en',
        components: components
      }.to_json

      res = graph_request(uri, req)
      result = JSON.parse(res.body)
      if res.code.to_i == 200
        puts "CREATE #{tpl[:name]} — id #{result['id']} (#{result['status']})"
      else
        puts "FAIL   #{tpl[:name]} — #{result['error'].inspect}"
      end
    end
  end

  def join_button
    {
      type: 'URL',
      text: 'Join Carbon Cube',
      url: 'https://carboncube-ke.com/partner/join?token={{1}}',
      example: ['https://carboncube-ke.com/partner/join?token=AbCdEf123xYz']
    }
  end

  # BODY text with {{n}} placeholders + example values for Meta review.
  # Every variable needs a non-empty example — Meta rejects empty strings —
  # so role+context is merged into a single always-present "role label"
  # variable ("partner" / "distributor in Sali Products Ltd's network").
  # Meta also rejects variables at the very start or end of the BODY text,
  # and parameter VALUES may not contain newlines/tabs — multi-line lists
  # therefore need one "• {{n}}" placeholder per line, not a list-in-one-var.
  def partner_templates
    [
      {
        name: 'partner_invite_v1',
        body: "Hi {{1}}, you've been invited to join Carbon Cube Kenya as a {{2}}.\n\n" \
              "Here's what you get:\n• {{3}}\n• {{4}}\n• {{5}}\n• {{6}}\n\n" \
              'Your link expires {{7}} — tap the button below to join.',
        example: ['Sali Products Ltd', 'brand/manufacturer partner',
                  'Verified Partner badge on your storefront', 'A free storefront for your catalog',
                  'Reach buyers across Kenya', 'Priority support', 'October 1'],
        join_button: true
      },
      {
        name: 'partner_invite_reminder_v1',
        body: "Hi {{1}}, your Carbon Cube Kenya {{2}} invite is still open — setup takes about a minute.\n\n" \
              "Your benefits:\n• {{3}}\n• {{4}}\n• {{5}}\n\n" \
              'Tap below to finish joining.',
        example: ['Sali Products Ltd', 'partner',
                  'Verified Partner badge', 'Free storefront', 'Priority support'],
        join_button: true
      },
      {
        name: 'partner_invite_final_v1',
        body: "Hi {{1}}, your Carbon Cube Kenya {{2}} invite expires {{3}}. " \
              'This is the last reminder — after expiry the link stops working and our team will send a new one.',
        example: ['Sali Products Ltd', 'partner', 'October 1'],
        join_button: true
      },
      {
        name: 'partner_joined_internal_v1',
        body: 'Team alert: {{1}} joined as {{2}} — the invite was accepted and access is now live.',
        example: ['Sali Products Ltd', 'partner']
      },
      {
        name: 'partner_invite_expired_v1',
        body: "Team alert: the {{2}} invite for {{1}} expired unaccepted. " \
              'Reminders have stopped — follow up by phone or send a fresh invite from the partners page.',
        example: ['Sali Products Ltd', 'partner']
      },
      {
        name: 'partner_update_v1',
        body: "Heads up — {{1}} from {{2}}:\n\n{{3}}\n{{4}}\n\n— Sent via Carbon Cube Kenya",
        example: ['Pricing update', 'Sali Products Ltd',
                  'Price drop: Maize Flour 2kg', 'Now KSh 180 (was KSh 220) — order before Friday.']
      }
    ]
  end

  def template_names(waba, token)
    uri = URI("#{WhatsAppCloudService::GRAPH_URL}/#{waba}/message_templates?limit=250&fields=name")
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{token}"
    JSON.parse(graph_request(uri, req).body).fetch('data', []).map { |t| t['name'] }
  end

  def graph_request(uri, req)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?
      http.request(req)
    end
  end
end
