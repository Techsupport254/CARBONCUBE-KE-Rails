# frozen_string_literal: true

class SendDocumentComplianceReminderJob < ApplicationJob
  queue_as :default

  # reminder_type: 'expiry' | 'mismatch' | 'invalid' | 'general'
  # channel: 'whatsapp' | 'email' | 'all'
  def perform(seller_id, reminder_type: 'expiry', channel: 'whatsapp', custom_message: nil, custom_subject: nil, target_phone: nil, target_email: nil)
    seller = Seller.find_by(id: seller_id)
    unless seller
      Rails.logger.error "[SendDocumentComplianceReminderJob] Seller with ID #{seller_id} not found"
      return
    end

    recipient_name = seller.enterprise_name.presence || seller.fullname.presence || 'Valued Seller'
    phone = target_phone.presence || seller.phone_number
    email = target_email.presence || seller.email

    results = { whatsapp: nil, in_app: nil, email: nil }

    # 1. WhatsApp Delivery (approved templates only)
    if channel.in?(['whatsapp', 'all']) && phone.present?
      template_name, body_params = whatsapp_template_for(seller, reminder_type, recipient_name)

      components = [
        {
          type: 'body',
          parameters: body_params.map { |val| { type: 'text', text: val.to_s } }
        }
      ]

      whatsapp_res = WhatsAppCloudService.send_template(phone, template_name, 'en', components)

      if whatsapp_res[:success]
        WhatsappMessageLog.mark_as_sent(seller, template_name, phone, whatsapp_res[:message_id]) if defined?(WhatsappMessageLog)
        results[:whatsapp] = { success: true, message_id: whatsapp_res[:message_id], template: template_name }
        Rails.logger.info "[SendDocumentComplianceReminderJob] WhatsApp template #{template_name} delivered to #{phone}"
      else
        Rails.logger.warn "[SendDocumentComplianceReminderJob] WhatsApp template #{template_name} failed: #{whatsapp_res[:error]}"
        results[:whatsapp] = { success: false, error: whatsapp_res[:error] }
      end
    end


    # 2. Email Delivery
    if channel.in?(['email', 'all']) && email.present?
      subject = custom_subject.presence || default_email_subject(reminder_type, recipient_name)
      body    = custom_message.presence || default_whatsapp_body(reminder_type, seller, recipient_name)
      doc_url = build_document_url(recipient_name, 'email')

      begin
        mail_obj = if reminder_type.to_s == 'expiry'
                     SellerMailer.document_expiry_reminder(seller, email, body, subject, doc_url)
                   else
                     SellerMailer.document_update_reminder(seller, email, body, subject, doc_url)
                   end
        mail_obj.deliver_now

        results[:email] = { success: true, recipient: email }
        Rails.logger.info "[SendDocumentComplianceReminderJob] Compliance email delivered to #{email} using SellerMailer (#{reminder_type})"
      rescue => e
        Rails.logger.error "[SendDocumentComplianceReminderJob] Email delivery failed for #{email}: #{e.message}"
        results[:email] = { success: false, error: e.message }
      end
    end




    results
  end


  private

  def build_document_url(name, channel = 'whatsapp')
    enterprise_param = CGI.escape(name.to_s.downcase.strip.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, ''))
    "https://carboncube-ke.com/profile?edit=true&tab=documents&utm_source=compliance&utm_medium=#{channel}&utm_campaign=document_verification&enterprise=#{enterprise_param}"
  end

  def default_email_subject(type, name)
    case type.to_s
    when 'expiry'   then "Action Required: Renew Your Business Permit — #{name}"
    when 'mismatch' then "Action Required: Business Permit Identity Mismatch — #{name}"
    when 'invalid'  then "Action Required: Upload Valid Business Document — #{name}"
    else                 "Compliance Notice — #{name}"
    end
  end

  def whatsapp_template_for(seller, reminder_type, name)
    docs = seller.seller_documents.includes(:document_type)
    first_unverified = docs.find { |doc| !doc.document_verified? }
    first_expired = docs.find { |doc| doc.document_expiry_date.present? && doc.expired? }

    case reminder_type.to_s
    when 'expiry'
      doc = first_expired || docs.first
      doc_name = doc&.document_type&.name || 'Unified Business Permit'
      expiry = doc&.document_expiry_date&.strftime('%d %b %Y') || 'recently'
      ['document_expiry_reminder_v1', [name, doc_name, expiry]]
    when 'mismatch'
      doc = first_unverified || docs.first
      permit_name = doc&.document_type&.name || 'the uploaded permit'
      ['document_mismatch_reminder_v1', [name, permit_name, name]]
    else
      # 'invalid' and any other type fall back to the invalid-document template
      ['document_invalid_reminder_v1', [name]]
    end
  end

  def default_whatsapp_body(_type, seller, name)
    doc_link = build_document_url(name, 'whatsapp')
    issues = seller.seller_documents.includes(:document_type).filter_map do |doc|
      doc_name = doc.document_type&.name || 'Document'
      if doc.document_expiry_date.present? && doc.expired?
        "• *#{doc_name}* expired on *#{doc.document_expiry_date.strftime('%d %b %Y')}*"
      elsif !doc.document_verified?
        "• *#{doc_name}* is not verified or invalid"
      end
    end
    issue_lines = issues.any? ? issues.join("\n") : '• Your verification documents need attention'

    "Hello *#{name}*,\n\nWe noticed the following compliance issues with your business documents on Carbon:\n\n#{issue_lines}\n\nPlease upload your updated documents using the link below:\n#{doc_link}\n\nThank you,\n*Carbon Seller Support*"
  end

  def send_in_app_compliance_message(seller, name, type, custom_text)
    system_admin = Rails.cache.fetch('system_admin_user', expires_in: 1.hour) do
      Admin.find_by(email: 'support@carboncube-ke.com') || Admin.find_by(username: 'admin') || Admin.first
    end
    return { success: false, error: 'No admin found' } unless system_admin

    title = case type.to_s
            when 'expiry' then 'Action Required: Business Permit Renewal'
            when 'mismatch' then 'Action Required: Document Identity Verification'
            when 'invalid' then 'Action Required: Upload Valid Business Permit'
            else 'Verification Notice'
            end

    content = custom_text.presence || default_whatsapp_body(type, seller, name)

    markdown = <<~MARKDOWN
      ### #{title}

      #{content}
    MARKDOWN

    conversation = Conversation.find_or_create_by!(
      admin_id: system_admin.id,
      seller_id: seller.id,
      ad_id: nil,
      buyer_id: nil,
      inquirer_seller_id: nil
    )

    message = conversation.messages.create!(
      content: markdown,
      sender: system_admin
    )

    UpdateUnreadCountsJob.perform_later(conversation.id, message.id) if defined?(UpdateUnreadCountsJob)

    { success: true, conversation_id: conversation.id, message_id: message.id }
  rescue StandardError => e
    Rails.logger.error "[SendDocumentComplianceReminderJob] In-app message failed: #{e.message}"
    { success: false, error: e.message }
  end
end
