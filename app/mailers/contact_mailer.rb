class ContactMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  # Send contact form submission to admin
  def contact_form
    name = params[:name]
    email = params[:email]
    phone = params[:phone]
    subject = params[:subject]
    message = params[:message]
    timestamp = Time.current.strftime("%B %d, %Y at %I:%M %p")

    mail(
      to: ENV['ADMIN_EMAIL'] || 'info@carboncube-ke.com',
      subject: "New Contact Form Submission: #{subject}",
      reply_to: email,
      react: {
        name: name,
        email: email,
        phone: phone,
        subject: subject,
        message: message,
        timestamp: timestamp
      }
    )
  end

  # Send auto-reply to user
  def auto_reply
    name = params[:name]
    email = params[:email]
    subject = params[:subject]

    campaign = subject.to_s.downcase.include?("callback") ? "callback_request" : "contact_form"

    site_url = UtmUrlHelper.append_utm("https://carboncube-ke.com",
      source: "email", medium: "auto_reply", campaign: campaign, content: "home")
    about_url = UtmUrlHelper.append_utm("https://carboncube-ke.com/about-us",
      source: "email", medium: "auto_reply", campaign: campaign, content: "about")
    blog_url = UtmUrlHelper.append_utm("https://carboncube-ke.com/blog",
      source: "email", medium: "auto_reply", campaign: campaign, content: "blog")

    mail(
      to: email,
      subject: "Thank you for contacting Carbon Cube Kenya - We'll be in touch soon!",
      react: {
        name: name,
        email: email,
        subject: subject,
        site_url: site_url,
        about_url: about_url,
        blog_url: blog_url
      }
    )
  end
end
