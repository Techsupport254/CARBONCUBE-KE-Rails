class WelcomeMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  # Send welcome email to new users
  def welcome_email(user)
    @user = user
    @name = user.fullname || user.username || user.email.split('@').first
    @user_type = user.class.name.downcase
    @login_url = "https://carboncube-ke.com/login"
    @dashboard_url = get_dashboard_url(user)
    @support_email = ENV['BREVO_EMAIL']
    @support_phone = "+254 712 990 524"
    @timestamp = Time.current.strftime("%B %d, %Y at %I:%M %p")

    mail(
      to: @user.email,
      subject: "Welcome to Carbon Cube Kenya - Your Account is Ready! 🎉"
    )
  end
  
  private

  def get_dashboard_url(user)
    case user.class.name
    when 'Buyer'
      "https://carboncube-ke.com/"
    when 'Seller'
      "https://carboncube-ke.com/seller/dashboard"
    when 'Admin'
      "https://carboncube-ke.com/admin/analytics"
    when 'SalesUser'
      "https://carboncube-ke.com/sales/dashboard"
    else
      "https://carboncube-ke.com/"
    end
  end
end
