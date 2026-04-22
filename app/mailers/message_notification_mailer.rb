class MessageNotificationMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  # Send new message notification to recipient
  def new_message_notification(message, recipient)
    @message = message
    @recipient = recipient
    @sender = message.sender
    @conversation = message.conversation
    
    # Detect if this is a callback request to set appropriate UTM campaign
    campaign = message.content.to_s.start_with?("[Callback Request]") ? "callback_request" : "message"
    
    # Get conversation URL based on recipient type
    @conversation_url = get_conversation_url(recipient, campaign: campaign)
    
    # Personalize greeting based on recipient type
    @recipient_name = get_recipient_name(recipient)
    @sender_name = get_sender_name(@sender)
    
    # Get product context if available
    @product_context = message.product_context
    @ad = message.ad
    
    @message_content = strip_markdown(message.content)
    
    mail(
      to: @recipient.email,
      subject: "New message from #{@sender_name} on Carbon Cube Kenya",
      reply_to: ENV['BREVO_EMAIL']
    )
  end

  private

  def strip_markdown(text)
    return "" if text.blank?
    # Simple regex to strip basic markdown for preview
    text.to_s
      .gsub(/^#+\s+/, '') # Remove headers
      .gsub(/\*\*(.*?)\*\*/, '\1') # Remove bold
      .gsub(/\*(.*?)\*/, '\1') # Remove italic
      .gsub(/__(.*?)__/, '\1') # Remove bold underscores
      .gsub(/_(.*?)_/, '\1') # Remove italic underscores
      .gsub(/\[(.*?)\]\(.*?\)/, '\1') # Remove links but keep text
      .gsub(/`+(.*?)`+/, '\1') # Remove code
      .gsub(/^\s*[-*+]\s+/, '') # Remove list markers
  end

  def get_conversation_url(recipient, campaign: "message")
    base = case recipient.class.name
    when 'Buyer'
      "https://carboncube-ke.com/buyer/conversations/#{@conversation.id}"
    when 'Seller'
      "https://carboncube-ke.com/seller/conversations/#{@conversation.id}"
    when 'Admin'
      "https://carboncube-ke.com/admin/conversations/#{@conversation.id}"
    else
      "https://carboncube-ke.com/conversations/#{@conversation.id}"
    end
    UtmUrlHelper.append_utm(
      base,
      source: 'email',
      medium: 'notification',
      campaign: campaign,
      content: @conversation.id
    )
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
