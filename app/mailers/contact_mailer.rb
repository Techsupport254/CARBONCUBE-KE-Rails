class ContactMailer < ApplicationMailer
  default from: 'noreply@carboncube-ke.com'

  # Send contact form submission to admin
  def contact_form
    @name = params[:name]
    @email = params[:email]
    @phone = params[:phone]
    @subject = params[:subject]
    @message = params[:message]
    @timestamp = Time.current.strftime("%B %d, %Y at %I:%M %p")

    mail(
      to: ENV['ADMIN_EMAIL'] || 'info@carboncube-ke.com',
      subject: "New Contact Form Submission: #{@subject}",
      reply_to: @email
    )
  end

  # Send auto-reply to user
  def auto_reply
    @name = params[:name]
    @email = params[:email]
    @subject = params[:subject]

    mail(
      to: @email,
      subject: "Thank you for contacting Carbon Cube Kenya - We'll be in touch soon!"
    )
  end
end
