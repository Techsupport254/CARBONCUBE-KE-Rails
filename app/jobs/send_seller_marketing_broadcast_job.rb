class SendSellerMarketingBroadcastJob < ApplicationJob
  queue_as :default

  def perform(template_name = 'seller_onboarding_sw_v1', language_code = 'sw', admin_id = 'fbd79dff-1a39-4150-8fe8-965d11b57c5f')
    Rails.logger.info "=== SELLER MARKETING BROADCAST START ==="
    Rails.logger.info "Template: #{template_name} | Language: #{language_code}"

    # Verify admin exists
    admin = Admin.find_by(id: admin_id)
    unless admin
      Rails.logger.error "❌ Fatal: Admin with ID #{admin_id} not found."
      return { success: false, error: "Admin not found" }
    end

    # Target: All active sellers with a phone number
    # We find_in_batches to avoid memory bloat
    sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
                    .where.not(phone_number: [nil, ""])

    total = sellers.count
    Rails.logger.info "Found #{total} sellers to broadcast to."

    sent = 0
    failed = 0

    sellers.find_each(batch_size: 50) do |seller|
      begin
        # Build components for personalized message
        # Template uses named parameter 'customer_name'
        # Build components for personalized message
        components = [
          {
            type: 'body',
            parameters: [
              {
                type: 'text',
                parameter_name: 'customer_name',
                text: seller.fullname.presence || seller.username.presence || 'Muuzaji'
              }
            ]
          }
        ]

        # Add Button parameter for Easter template (Shop Slug)
        if template_name == 'easter_seller_utility_v1'
          components << {
            type: 'button',
            sub_type: 'url',
            index: 1, # The 'View and Share Your Shop' button is at index 1
            parameters: [
              {
                type: 'text',
                text: seller.username.presence || seller.slug.presence || 'shop'
              }
            ]
          }
        end

        # Using Cloud Service
        result = WhatsAppCloudService.send_template(seller.phone_number, template_name, language_code, components)
        
        if result[:success]
          sent += 1
          Rails.logger.info "✅ Broadcast sent to Seller ##{seller.id} (#{seller.phone_number})"
          
          # Record the message in our conversation history
          # Find or create a WhatsApp conversation between the admin and seller
          conversation = Conversation.find_or_create_conversation!(
            admin_id: admin.id,
            seller_id: seller.id
          )
          
          # Ensure it's marked as WhatsApp
          conversation.update!(is_whatsapp: true)

          # Save the message record with the personalized greeting
          greeting = seller.fullname.presence || 'Muuzaji'
          content_preview = "Habari yako, #{greeting}! Asante sana kwa kuwa muuzaji kwenye Carbon Cube Kenya..."
          
          conversation.messages.create!(
            content: content_preview,
            sender: admin,
            whatsapp_message_id: result[:message_id],
            status: Message::STATUS_SENT
          )
        else
          failed += 1
          Rails.logger.error "❌ Failed to send to Seller ##{seller.id}: #{result[:error]}"
        end
      rescue => e
        failed += 1
        Rails.logger.error "💥 Exception broadcasting to Seller ##{seller.id}: #{e.message}"
      end
      
      # Tiny sleep between messages (2 messages per second) to stay safe with API tiers
      sleep(0.5)
    end

    Rails.logger.info "=== SELLER MARKETING BROADCAST COMPLETE ==="
    Rails.logger.info "Success: #{sent} | Failed: #{failed} | Total: #{total}"
    
    { success_count: sent, failure_count: failed, total_targeted: total }
  end
end
