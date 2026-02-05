class ContactMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

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

    # Detect campaign based on subject
    @campaign = @subject.to_s.downcase.include?("callback") ? "callback_request" : "contact_form"

    # Set URLs with UTMs for the auto-reply email
    @site_url = UtmUrlHelper.append_utm("https://carboncube-ke.com", 
      source: "email", medium: "auto_reply", campaign: @campaign, content: "home")
    @about_url = UtmUrlHelper.append_utm("https://carboncube-ke.com/about-us", 
      source: "email", medium: "auto_reply", campaign: @campaign, content: "about")
    @blog_url = UtmUrlHelper.append_utm("https://carboncube-ke.com/blog", 
      source: "email", medium: "auto_reply", campaign: @campaign, content: "blog")

    mail(
      to: @email,
      subject: "Thank you for contacting Carbon Cube Kenya - We'll be in touch soon!"
    )
  end
end
