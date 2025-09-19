class MessageNotificationMailer < ApplicationMailer
  default from: ENV['BREVO_EMAIL']

  # Send new message notification to recipient
  def new_message_notification(message, recipient)
    @message = message
    @recipient = recipient
    @sender = message.sender
    @conversation = message.conversation
    
    # Get conversation URL based on recipient type
    @conversation_url = get_conversation_url(recipient)
    
    # Personalize greeting based on recipient type
    @recipient_name = get_recipient_name(recipient)
    @sender_name = get_sender_name(@sender)
    
    # Get product context if available
    @product_context = message.product_context
    @ad = message.ad
    
    mail(
      to: @recipient.email,
      subject: "New message from #{@sender_name} on Carbon Cube Kenya",
      reply_to: ENV['BREVO_EMAIL']
    )
  end

  private

  def get_conversation_url(recipient)
    case recipient.class.name
    when 'Buyer'
      "https://carboncube-ke.com/buyer/conversations/#{@conversation.id}"
    when 'Seller'
      "https://carboncube-ke.com/seller/conversations/#{@conversation.id}"
    when 'Admin'
      "https://carboncube-ke.com/admin/conversations/#{@conversation.id}"
    else
      "https://carboncube-ke.com/conversations/#{@conversation.id}"
    end
  end

  def get_recipient_name(recipient)
    case recipient.class.name
    when 'Buyer'
      recipient.username.present? ? recipient.username : recipient.email.split('@').first
    when 'Seller'
      recipient.fullname.present? ? recipient.fullname : recipient.enterprise_name
    when 'Admin'
      recipient.email.split('@').first
    else
      recipient.email.split('@').first
    end
  end

  def get_sender_name(sender)
    case sender.class.name
    when 'Buyer'
      sender.username.present? ? sender.username : sender.email.split('@').first
    when 'Seller'
      sender.fullname.present? ? sender.fullname : sender.enterprise_name
    when 'Admin'
      'Carbon Cube Support'
    else
      sender.email.split('@').first
    end
  end
end
