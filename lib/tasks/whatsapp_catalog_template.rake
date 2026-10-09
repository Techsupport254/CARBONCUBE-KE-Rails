# frozen_string_literal: true

# Creates/updates the catalog-upload-request WhatsApp template on the WABA via
# the Meta Graph API. Required because the blast is business-initiated — sellers
# outside the 24h service window can only be reached with an approved
# template.
#
#   bin/rails whatsapp:create_catalog_upload_template
#   bin/rails whatsapp:update_catalog_upload_template
#
# Meta BODY rules that shaped the copy: max 1024 chars, no variables at the
# very start/end, and parameter VALUES may not contain newlines — so the
# sample catalog is baked in as static text, truncated to stay under the cap.
namespace :whatsapp do
  desc 'Create the catalog upload request WhatsApp template (skips if it already exists)'
  task create_catalog_upload_template: :environment do
    waba, token = whatsapp_credentials!
    name = SendCatalogUploadRequestJob::WHATSAPP_TEMPLATE

    if whatsapp_template_names(waba, token).include?(name)
      puts "SKIP   #{name} — already exists"
      next
    end

    result = whatsapp_create_template(waba, token, catalog_upload_template_payload)
    if result[:success]
      puts "CREATE #{name} — id #{result[:id]} (#{result[:status]})"
      puts 'Note: Meta may re-categorize to MARKETING and approval may take a few minutes.'
    else
      puts "FAIL   #{name} — #{result[:error].inspect}"
    end
  end

  desc 'Update the catalog upload request WhatsApp template copy on the WABA'
  task update_catalog_upload_template: :environment do
    waba, token = whatsapp_credentials!
    name = SendCatalogUploadRequestJob::WHATSAPP_TEMPLATE

    template = whatsapp_template_by_name(waba, token, name)
    abort "Template #{name} not found on the WABA — run whatsapp:create_catalog_upload_template first" unless template

    payload = catalog_upload_template_payload
    uri = URI("#{WhatsAppCloudService::GRAPH_URL}/#{template['id']}")
    req = Net::HTTP::Post.new(uri.path)
    req['Authorization'] = "Bearer #{token}"
    req['Content-Type'] = 'application/json'
    # Editable fields only — name/language/category can't change on update
    req.body = { components: payload[:components] }.to_json

    res = whatsapp_request(uri, req)
    result = JSON.parse(res.body)

    if res.code.to_i == 200 && result['success']
      puts "UPDATE #{name} — id #{template['id']} (re-submitted for review)"
    else
      puts "FAIL   #{name} — #{(result['error'] || result).inspect}"
    end
  end

  def whatsapp_credentials!
    require 'net/http'
    require 'json'

    waba = ENV['WHATSAPP_CLOUD_WABA_ID']
    token = ENV['WHATSAPP_CLOUD_ACCESS_TOKEN']
    abort 'Missing WHATSAPP_CLOUD_WABA_ID or WHATSAPP_CLOUD_ACCESS_TOKEN' if waba.blank? || token.blank?
    [waba, token]
  end

  def catalog_upload_template_payload
    body = "Hi {{1}}, your shop on Carbon Cube Kenya is ready for buyers — we just need your products.\n\n" \
           "Send us your catalog in whatever form you have it — website links, documents " \
           "(PDF, Excel, Word), images, or just a typed text — and we'll upload everything for you. " \
           "A simple list like this works too:\n\n" \
           "• HP ZBOOK 15 G8 i7 16-512 — 70k Only\n" \
           "• HP ZBOOK 14 G8 i7 32-512 — 75k Only\n" \
           "• X1 CARBON i7 16-512 11th Gen — 64k Only\n" \
           "• Dell Precision 7550 i7 16-512 — 71k Only\n\n" \
           "Phones, laptops, TVs, auto parts, hardware, filtration, farm equipment, services — " \
           "every category is welcome. Just reply to this message with your catalog."

    {
      name: SendCatalogUploadRequestJob::WHATSAPP_TEMPLATE,
      category: 'UTILITY',
      language: 'en',
      components: [
        {
          type: 'BODY',
          text: body,
          example: { body_text: [['Sali Products Ltd']] }
        },
        {
          type: 'BUTTONS',
          buttons: [
            { type: 'URL', text: 'Open Dashboard', url: 'https://carboncube-ke.com/seller/ads' }
          ]
        }
      ]
    }
  end

  def whatsapp_template_names(waba, token)
    uri = URI("#{WhatsAppCloudService::GRAPH_URL}/#{waba}/message_templates?limit=250&fields=name")
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{token}"
    JSON.parse(whatsapp_request(uri, req).body).fetch('data', []).map { |t| t['name'] }
  end

  def whatsapp_template_by_name(waba, token, name)
    uri = URI("#{WhatsAppCloudService::GRAPH_URL}/#{waba}/message_templates?limit=250&fields=name,status")
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{token}"
    JSON.parse(whatsapp_request(uri, req).body).fetch('data', []).find { |t| t['name'] == name }
  end

  def whatsapp_create_template(waba, token, payload)
    uri = URI("#{WhatsAppCloudService::GRAPH_URL}/#{waba}/message_templates")
    req = Net::HTTP::Post.new(uri.path)
    req['Authorization'] = "Bearer #{token}"
    req['Content-Type'] = 'application/json'
    req.body = payload.to_json

    res = whatsapp_request(uri, req)
    result = JSON.parse(res.body)

    if res.code.to_i == 200
      { success: true, id: result['id'], status: result['status'] }
    else
      { success: false, error: result['error'] || result }
    end
  end

  def whatsapp_request(uri, req)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?
      http.request(req)
    end
  end
end
