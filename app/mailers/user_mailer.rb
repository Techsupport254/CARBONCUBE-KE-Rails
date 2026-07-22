class UserMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  def reactivation_email(user, reactivation_url)
    name = user.try(:fullname) || user.try(:username) || user.email.split('@').first

    mail(
      to: user.email,
      subject: "Account Reactivation Link - Carbon Cube Kenya",
      react: {
        name: name,
        reactivation_url: reactivation_url,
        timestamp: Time.current.strftime("%B %d, %Y at %I:%M %p"),
        support_email: ENV['BREVO_EMAIL']
      }
    )
  end
end
