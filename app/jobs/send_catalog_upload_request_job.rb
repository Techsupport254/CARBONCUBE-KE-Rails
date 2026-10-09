# frozen_string_literal: true

require 'timeout'

# Requests a seller to send us their product catalog so our team can list it
# for them. Delivers across every channel in one place:
#   - WhatsApp: approved template `catalog_upload_request_v1` (falls back to
#     plain text if Meta rejects it)
#   - Email:    SellerCommunicationsMailer.catalog_upload_request
#   - Push:     FCM via PushNotificationService (also persists the
#               in-app Notification row when a device token exists)
#   - In-app:   Notification row for the bell + a conversation message from
#               the system admin account
#
# Single seller usage:
#   SendCatalogUploadRequestJob.perform_later(seller.id)
#
# Test usage (contact overrides — nothing else is touched):
#   SendCatalogUploadRequestJob.perform_now(seller.id, {},
#     target_phone: '0716404137', target_email: 'kiruivictor097@gmail.com')
class SendCatalogUploadRequestJob < ApplicationJob
  queue_as :broadcast

  WHATSAPP_TEMPLATE = 'catalog_upload_request_v2'
  WHATSAPP_LANGUAGE = 'en'

  NOTIFICATION_TITLE = 'Send Us Your Product Catalog'

  # FCM push body — system tray renders plain text only, keep it short.
  PUSH_BODY = 'Send us your catalog — links, documents, images, or just a ' \
              'typed text — and we will upload it to your shop for you.'

  # In-app notification body — rendered as markdown by the app's
  # NotificationsScreen (react-native-markdown-display).
  NOTIFICATION_BODY = <<~MARKDOWN
    Your shop is ready for buyers — we just need your products.

    **Send us your catalog however you have it:**
    • **Links** to your website or online catalog
    • **Documents** — PDF, Excel, or Word
    • **Images** — photos of your products or price list
    • **Just a text** — a simple typed list

    Example:

    • `HP ZBOOK 15 G8 i7 16-512 — 70k Only`
    • `X1 CARBON i7 16-512 11th Gen — 64k Only`
    • `Dell Precision 7550 i7 16-512 — 71k Only`

    All categories are welcome — phones, laptops, TVs, auto parts, hardware, filtration, farm equipment, services. Just reply to this message with your catalog.
  MARKDOWN

  NOTIFICATION_DATA  = { 'type' => 'catalog_upload_request' }.freeze

  DEFAULT_CHANNELS = { 'whatsapp' => true, 'email' => true, 'push' => true, 'in_app' => true }.freeze

  def perform(seller_id, channels = {}, target_phone: nil, target_email: nil)
    channels = DEFAULT_CHANNELS.merge(channels.to_h.stringify_keys)

    seller = Seller.find_by(id: seller_id)
    unless seller
      Rails.logger.error "[SendCatalogUploadRequestJob] Seller #{seller_id} not found"
      return
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

    if results.values.all? { |r| r.nil? || (r.is_a?(Hash) && r[:success] == false) }
      Rails.logger.warn "[SendCatalogUploadRequestJob] No channel succeeded for seller #{seller.id}"
    end

    results
  end

  private

  def send_whatsapp(seller, name, phone, override: false)
    if phone.blank?
      Rails.logger.warn "[SendCatalogUploadRequestJob] Seller #{seller.id} has no phone number - skipping WhatsApp"
      return { success: false, error: 'no_phone' }
    end

    if !override && seller.respond_to?(:whatsapp_notifications) && !seller.whatsapp_notifications
      Rails.logger.info "[SendCatalogUploadRequestJob] Seller #{seller.id} opted out of WhatsApp - skipping"
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
      fallback_text: whatsapp_fallback_text(name)
    )

    if result.is_a?(Hash) && result[:success]
      WhatsappMessageLog.mark_as_sent(seller, WHATSAPP_TEMPLATE, phone, result[:message_id])
      Rails.logger.info "[SendCatalogUploadRequestJob] WhatsApp catalog request delivered to #{phone}"
    else
      error = result.is_a?(Hash) ? result[:error] : 'Unknown error'
      Rails.logger.warn "[SendCatalogUploadRequestJob] WhatsApp failed for seller #{seller.id}: #{error}"
      log_whatsapp_failure(seller, phone, error)
    end

    result
  end

  def whatsapp_fallback_text(name)
    dashboard_url = UtmUrlHelper.append_utm(
      'https://carboncube-ke.com/seller/ads',
      source: 'whatsapp', medium: 'notification', campaign: 'catalog_upload_request'
    )

    <<~MESSAGE
      📦 *Send Us Your Catalog — We'll Upload It*

      Hi *#{name}*, your Carbon Cube Kenya shop is live — now let's fill it.

      Send us your catalog in whatever form you have it — *links* to your website, *documents* (PDF, Excel, Word), *images*, or *just a typed text* — and we'll upload everything for you. A simple list like this works too:

      • HP ZBOOK 15 G8 i7 16-512 11th — 70k Only
      • HP ZBOOK 14 G8 i7 32-512 TOUCH — 75k Only
      • X1 CARBON i7 16-512 11th Gen — 64k Only
      • Dell Precision 7550 i7 16-512 — 71k Only

      Phones, laptops, TVs, auto parts, hardware, filtration, farm equipment, services — every category is welcome.

      Reply to this message with your catalog, or add products directly from your dashboard:
      #{dashboard_url}

      *Carbon Cube Kenya*
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
      Rails.logger.warn "[SendCatalogUploadRequestJob] Seller #{seller.id} has no email - skipping email"
      return { success: false, error: 'no_email' }
    end

    Timeout.timeout(30) do
      SellerCommunicationsMailer.with(seller: seller, to_email: email).catalog_upload_request.deliver_now
    end

    { success: true }
  rescue => e
    Rails.logger.error "[SendCatalogUploadRequestJob] Email failed for seller #{seller.id}: #{e.message}"
    { success: false, error: e.message }
  end

  # In-app Notification row + optional FCM push. Mirrors BroadcastAppUpdateJob:
  # the push service persists the Notification row itself when a device token
  # is on file; for sellers without tokens we write the row directly so the
  # bell notification still shows up.
  def ensure_notification(seller, with_push:)
    result = { push: nil, notification: nil }
    tokens = DeviceToken.where(user: seller).pluck(:token)

    if with_push && tokens.any?
      push_result = PushNotificationService.send_notification_with_details(tokens, push_payload)
      result[:push] = push_result
    end

    unless Notification.exists?(recipient: seller, title: NOTIFICATION_TITLE)
      Notification.create!(
        recipient: seller,
        title: NOTIFICATION_TITLE,
        body: NOTIFICATION_BODY,
        data: NOTIFICATION_DATA
      )
    end
    result[:notification] = { success: true }

    result
  rescue => e
    Rails.logger.error "[SendCatalogUploadRequestJob] Notification/push failed for seller #{seller.id}: #{e.message}"
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
      Rails.logger.error '[SendCatalogUploadRequestJob] Cannot send in-app message: no Admin found'
      return { success: false, error: 'no_admin' }
    end

    dashboard_url = UtmUrlHelper.append_utm(
      'https://carboncube-ke.com/seller/ads',
      source: 'in_app', medium: 'messaging', campaign: 'catalog_upload_request'
    )

    markdown_content = <<~MARKDOWN
      **Send Us Your Catalog — We'll Upload It for You**

      Greetings **#{name}**,

      Your Carbon Cube Kenya shop is live — now let's fill it with your products.

      Send us your catalog in whatever form you have it — **links** to your website, **documents** (PDF, Excel, Word), **images**, or **just a typed text** — and our team will upload everything for you. Here's an example of a simple list:

      • HP ZBOOK 15 G8 i7 16-512 11th NON 4GB Graphics — 70k Only
      • HP ZBOOK 14 G8 i7 32-512 11th TOUCH 4GB Graphics — 75k Only
      • X1 CARBON i7 16-512 11th Gen TOUCH SCREEN — 64k Only
      • Dell Precision 7550 10th Gen i7 16-512 4GB Graphics — 71k Only

      All categories are welcome — phones & computers, TVs & electronics, auto parts, hardware & tools, filtration, agriculture and services.

      Reply right here with your catalog — a link, a document, images, or a typed text — or add products directly from your [Dashboard](#{dashboard_url}).

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
      Rails.logger.warn "[SendCatalogUploadRequestJob] Failed to enqueue unread count update: #{e.message}"
    end

    { success: true, conversation_id: conversation.id, message_id: message.id }
  rescue => e
    Rails.logger.error "[SendCatalogUploadRequestJob] In-app message failed for seller #{seller.id}: #{e.message}"
    { success: false, error: e.message }
  end
end
