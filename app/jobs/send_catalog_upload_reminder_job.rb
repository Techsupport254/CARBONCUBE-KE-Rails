# frozen_string_literal: true

require 'timeout'

# Sends a reminder to sellers who haven't yet submitted their product catalog.
# Delivers across all 4 channels:
#   - Email:    SellerCommunicationsMailer.catalog_upload_reminder
#   - Push:     FCM via PushNotificationService
#   - In-app:   Notification row for the bell + conversation message from system admin
#   - WhatsApp: WhatsAppCloudService with template or fallback text
#
# Single seller usage:
#   SendCatalogUploadReminderJob.perform_later(seller.id)
#
# Test usage:
#   SendCatalogUploadReminderJob.perform_now(seller.id, {},
#     target_phone: '0716404137', target_email: 'kiruivictor097@gmail.com')
class SendCatalogUploadReminderJob < ApplicationJob
  queue_as :broadcast

  WHATSAPP_TEMPLATE = 'catalog_upload_reminder_v1'
  WHATSAPP_FALLBACK_TEMPLATE = 'catalog_upload_request_v2'
  WHATSAPP_LANGUAGE = 'en'

  NOTIFICATION_TITLE = 'Reminder: Send Us Your Product Catalog'

  PUSH_BODY = 'Friendly reminder: Send us your product catalog (photos, document, or text) ' \
              'and our team will upload everything to your shop for you at no cost.'

  NOTIFICATION_BODY = <<~MARKDOWN
    **Friendly Reminder: We're Ready to List Your Products**

    Your shop is live on Carbon Cube Kenya, but you don't have active products listed yet. Active buyers are browsing daily — let's make sure they can find and buy from you!

    **Send us your catalog however you have it:**
    • **Links** to your website or existing social pages
    • **Documents** — PDF, Excel spreadsheets, or Word docs
    • **Images** — photos of your products or price list
    • **Just a text message** — a simple typed list of items & prices

    Example:
    • `Phones: Samsung Galaxy A15 128GB / 6GB — 19.5k`
    • `Laptops: HP EliteBook 840 G6 i5 16-256 — 32k`
    • `Hardware: Simba Cement 32.5R 50kg — 775/=`
    • `Construction: Deformed Steel Rebar D12 (12m) — 1,115/=`
    • `Auto Parts: Chloride Exide N70 Battery — 14.5k`
    • `TVs & Audio: TCL 55" 4K Smart Google TV — 46k`
    • `Agriculture: Automatic 64-Egg Incubator — 12k`
    • `Services: Workshop Repair & Overhaul Service — 800/=`

    All categories are welcome — computers, phones, auto parts, hardware, electronics, farm equipment, and services. Simply reply right here with your catalog and we'll take care of the rest.
  MARKDOWN

  NOTIFICATION_DATA = { 'type' => 'catalog_upload_reminder' }.freeze

  DEFAULT_CHANNELS = { 'whatsapp' => true, 'email' => true, 'push' => true, 'in_app' => true }.freeze

  def perform(seller_id, channels = {}, target_phone: nil, target_email: nil)
    channels = DEFAULT_CHANNELS.merge(channels.to_h.stringify_keys)

    seller = Seller.find_by(id: seller_id)
    unless seller
      Rails.logger.error "[SendCatalogUploadReminderJob] Seller #{seller_id} not found"
      return
    end

    # Guard: do not send if seller already has active ads
    if target_phone.blank? && seller.ads.where(deleted: false).exists?
      Rails.logger.info "[SendCatalogUploadReminderJob] Skipping seller #{seller.id} — already has active ads"
      return { skipped: true, reason: 'has_active_ads' }
    end

    name  = seller.enterprise_name.presence || seller.fullname.presence || 'Partner'
    phone = target_phone.presence || seller.phone_number
    email = target_email.presence || seller.email

    results = { whatsapp: nil, email: nil, push: nil, notification: nil, in_app: nil }

    results[:whatsapp] = send_whatsapp(seller, name, phone, override: target_phone.present?) if channels['whatsapp']
    results[:email]    = send_email(seller, email) if channels['email']

    if channels['push'] || channels['in_app']
      notification_result = ensure_notification(seller, with_push: channels['push'])
      results[:push]         = notification_result[:push]
      results[:notification] = notification_result[:notification]
    end

    results[:in_app] = send_in_app_message(seller, name) if channels['in_app']

    results
  end

  private

  def send_whatsapp(seller, name, phone, override: false)
    if phone.blank?
      Rails.logger.warn "[SendCatalogUploadReminderJob] Seller #{seller.id} has no phone - skipping WhatsApp"
      return { success: false, error: 'no_phone' }
    end

    if !override && seller.respond_to?(:whatsapp_notifications) && !seller.whatsapp_notifications
      Rails.logger.info "[SendCatalogUploadReminderJob] Seller #{seller.id} opted out of WhatsApp - skipping"
      return { success: false, error: 'opted_out' }
    end

    if !override && WhatsappMessageLog.already_sent?(seller, WHATSAPP_TEMPLATE)
      return { success: false, error: 'already_sent' }
    end

    components = [
      {
        type: 'body',
        parameters: [{ type: 'text', text: name }]
      }
    ]

    result = WhatsAppCloudService.send_template_or_text(
      phone,
      template_name: WHATSAPP_TEMPLATE,
      components: components,
      language: WHATSAPP_LANGUAGE,
      fallback_text: whatsapp_fallback_text(name, seller)
    )

    # If reminder template is not registered on Meta yet, fallback to request template
    if (!result.is_a?(Hash) || !result[:success]) && WHATSAPP_FALLBACK_TEMPLATE
      result = WhatsAppCloudService.send_template_or_text(
        phone,
        template_name: WHATSAPP_FALLBACK_TEMPLATE,
        components: components,
        language: WHATSAPP_LANGUAGE,
        fallback_text: whatsapp_fallback_text(name, seller)
      )
    end

    if result.is_a?(Hash) && result[:success]
      WhatsappMessageLog.mark_as_sent(seller, WHATSAPP_TEMPLATE, phone, result[:message_id])
      Rails.logger.info "[SendCatalogUploadReminderJob] WhatsApp catalog reminder delivered to #{phone}"
    else
      error = result.is_a?(Hash) ? result[:error] : 'Unknown error'
      Rails.logger.warn "[SendCatalogUploadReminderJob] WhatsApp failed for seller #{seller.id}: #{error}"
      log_whatsapp_failure(seller, phone, error)
    end

    result
  end

  def whatsapp_fallback_text(name, seller)
    shop_name = seller.enterprise_name.presence || name
    dashboard_url = UtmUrlHelper.append_utm(
      'https://carboncube-ke.com/seller/ads',
      source: 'whatsapp', medium: 'notification', campaign: 'catalog_upload_reminder'
    )

    <<~MESSAGE
      📦 *Friendly Reminder: Send Us Your Product Catalog*

      Hi *#{name}*, a quick follow-up from Carbon Cube Kenya.

      Your storefront *#{shop_name}* is live and ready for buyers, but you don't have active products listed yet. Active buyers are browsing daily — let's make sure they can find and buy from you!

      You don't need to spend time listing them manually. Just send us your price list, product photos, documents, or a simple text list right here on WhatsApp, and our team will upload and categorize everything for you at *no cost*.

      A simple typed list like this works too:
      • Phones: Samsung Galaxy A15 128GB / 6GB — 19.5k
      • Laptops: HP EliteBook 840 G6 i5 16-256 — 32k
      • Hardware: Simba Cement 32.5R 50kg — 775/=
      • Construction: Deformed Steel Rebar D12 (12m) — 1,115/=
      • Auto Parts: Chloride Exide N70 Battery — 14.5k
      • TVs & Audio: TCL 55" 4K Smart Google TV — 46k
      • Agriculture: Automatic 64-Egg Incubator — 12k
      • Services: Workshop Repair & Overhaul Service — 800/=

      Phones, laptops, auto parts, hardware, electronics, farm equipment, services — every category is welcome.

      Reply right here with your catalog, or view your dashboard:
      #{dashboard_url}

      *Carbon Cube Kenya Team*
    MESSAGE
  end

  def log_whatsapp_failure(seller, phone, error)
    WhatsappMessageLog.create(
      seller: seller,
      phone_number: phone,
      template_name: WHATSAPP_TEMPLATE,
      sent_successfully: false,
      error_message: error.to_s
    )
  rescue StandardError
    nil
  end

  def send_email(seller, email)
    if email.blank?
      Rails.logger.warn "[SendCatalogUploadReminderJob] Seller #{seller.id} has no email - skipping email"
      return { success: false, error: 'no_email' }
    end

    Timeout.timeout(30) do
      SellerCommunicationsMailer.with(seller: seller, to_email: email).catalog_upload_reminder.deliver_now
    end

    { success: true }
  rescue => e
    Rails.logger.error "[SendCatalogUploadReminderJob] Email failed for seller #{seller.id}: #{e.message}"
    { success: false, error: e.message }
  end

  def ensure_notification(seller, with_push:)
    result = { push: nil, notification: nil }
    tokens = DeviceToken.where(user: seller).pluck(:token)

    if with_push && tokens.any?
      push_result = PushNotificationService.send_notification_with_details(tokens, push_payload)
      result[:push] = push_result
    end

    Notification.create!(
      recipient: seller,
      title: NOTIFICATION_TITLE,
      body: NOTIFICATION_BODY,
      data: NOTIFICATION_DATA
    )
    result[:notification] = { success: true }

    result
  rescue => e
    Rails.logger.error "[SendCatalogUploadReminderJob] Notification/push failed for seller #{seller.id}: #{e.message}"
    { push: result[:push], notification: { success: false, error: e.message } }
  end

  def push_payload
    { title: NOTIFICATION_TITLE, body: PUSH_BODY, data: NOTIFICATION_DATA }
  end

  def send_in_app_message(seller, name)
    system_admin = Rails.cache.fetch('system_admin_user', expires_in: 1.hour) do
      Admin.find_by(email: 'support@carboncube-ke.com') ||
        Admin.find_by(username: 'admin') ||
        Admin.first
    end

    unless system_admin
      Rails.logger.error '[SendCatalogUploadReminderJob] Cannot send in-app message: no Admin found'
      return { success: false, error: 'no_admin' }
    end

    shop_name = seller.enterprise_name.presence || name
    dashboard_url = UtmUrlHelper.append_utm(
      'https://carboncube-ke.com/seller/ads',
      source: 'in_app', medium: 'messaging', campaign: 'catalog_upload_reminder'
    )

    markdown_content = <<~MARKDOWN
      **Friendly Reminder: We're Ready to List Your Products**

      Greetings **#{name}**,

      Following up on our earlier message — your shop **#{shop_name}** is live and visible on Carbon Cube Kenya, but you don't have active products listed yet.

      You don't need to spend time adding them manually. Send us whatever catalog, price list, documents, or photos you have right here, and our operations team will upload and categorize everything for you at **no cost**.

      Here's an example of a simple typed list:
      • Phones: Samsung Galaxy A15 128GB / 6GB — 19.5k
      • Laptops: HP EliteBook 840 G6 i5 16-256 — 32k
      • Hardware: Simba Cement 32.5R 50kg — 775/=
      • Construction: Deformed Steel Rebar D12 (12m) — 1,115/=
      • Auto Parts: Chloride Exide N70 Battery — 14.5k
      • TVs & Audio: TCL 55" 4K Smart Google TV — 46k
      • Agriculture: Automatic 64-Egg Incubator — 12k
      • Services: Workshop Repair & Overhaul Service — 800/=

      All categories are welcome — computers & phones, auto parts, hardware, electronics, agriculture, and services.

      Reply right here in this chat with your catalog, or open your [Dashboard](#{dashboard_url}).

      Best regards,
      **Carbon Cube Kenya Team**
    MARKDOWN

    conversation = Conversation.find_or_create_by!(
      admin_id: system_admin.id,
      seller_id: seller.id,
      ad_id: nil,
      buyer_id: nil,
      inquirer_seller_id: nil
    )

    message = conversation.messages.create!(
      content: markdown_content,
      sender: system_admin
    )

    begin
      UpdateUnreadCountsJob.perform_later(conversation.id, message.id)
    rescue => e
      Rails.logger.warn "[SendCatalogUploadReminderJob] Failed to enqueue unread count update: #{e.message}"
    end

    { success: true, conversation_id: conversation.id, message_id: message.id }
  rescue => e
    Rails.logger.error "[SendCatalogUploadReminderJob] In-app message failed for seller #{seller.id}: #{e.message}"
    { success: false, error: e.message }
  end
end
