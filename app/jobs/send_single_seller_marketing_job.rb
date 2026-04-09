class SendSingleSellerMarketingJob < ApplicationJob
  queue_as :default

  def perform(seller_id, template_name, language_code, admin_id)
    seller = Seller.find_by(id: seller_id)
    admin = Admin.find_by(id: admin_id)
    return unless seller && admin

    # Build personalization components
    components = [
      {
        type: 'body',
        parameters: [
          {
            type: 'text',
            text: seller.fullname.presence || seller.username.presence || 'Muuzaji'
          }
        ]
      }
    ]

    # Add Dynamic Shop Link button parameters
    if template_name == 'easter_promo_v1' || template_name == 'easter_seller_campaign'
      components << {
        type: 'button',
        sub_type: 'url',
        index: 1, # View and Share Your Shop is consistently at index 1
        parameters: [
          {
            type: 'text',
            text: (seller.username.presence || seller.slug.presence || seller.enterprise_name || 'shop').to_s.parameterize
          }
        ]
      }
    end

    # Send the template via Meta Cloud API
    result = WhatsAppCloudService.send_template(seller.phone_number, template_name, language_code, components)

    if result[:success]
      # Log and save conversation record
      conversation = Conversation.find_or_create_conversation!(admin_id: admin.id, seller_id: seller.id)
      conversation.update!(is_whatsapp: true)
      
      preview_text = if template_name.include?('easter')
                      "🐣 Easter Campaign Sent: Hello, #{seller.fullname || seller.username}! We've reached out about the Easter shop update."
                    else
                      "Broadcast Template: #{template_name} sent."
                    end

      conversation.messages.create!(
        content: preview_text,
        sender: admin,
        whatsapp_message_id: result[:message_id],
        status: Message::STATUS_SENT
      )
    else
      Rails.logger.error "❌ Marketing Job Failed for Seller ##{seller.id}: #{result[:error]}"
    end
  end
end
