class WelcomeMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  # Send welcome email to new users (links include UTM: source=email, medium=welcome, campaign=signup)
  def welcome_email(user, to_email = nil)
    name = user.fullname || user.username || user.email.to_s.split('@').first
    user_type = user.class.name.downcase
    is_seller = user.is_a?(Seller)

    login_url = UtmUrlHelper.append_utm(
      "https://carboncube-ke.com/login",
      source: 'email',
      medium: 'welcome',
      campaign: 'signup',
      content: 'login'
    )
    dashboard_url = get_dashboard_url(user)

    storefront_url = nil
    enterprise_name = nil
    image_path = nil

    if is_seller
      enterprise_name = user.enterprise_name.presence || name
      shop_slug = (user.enterprise_name || user.username || user.id.to_s).parameterize

      base_frontend = if Rails.env.development?
        ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
      else
        ENV.fetch('FRONTEND_URL', 'https://carboncube-ke.com')
      end

      storefront_url = UtmUrlHelper.append_utm(
        "#{base_frontend}/shop/#{shop_slug}",
        source: 'email',
        medium: 'welcome',
        campaign: 'signup',
        content: 'storefront_link'
      )

      # Generate and attach high-res Standee PNG
      image_path = SellerQrStandeeGeneratorService.generate(user)
      if image_path && File.exist?(image_path)
        attachments["#{shop_slug}-qr-standee.png"] = File.binread(image_path)
      end
    end

    mail(
      to: to_email || user.email,
      subject: is_seller ? "Welcome to Carbon Cube Kenya - Your Storefront & QR Standee Are Ready" : "Welcome to Carbon Cube Kenya - Your Account is Ready",
      react: {
        name: name,
        user_type: user_type,
        login_url: login_url,
        dashboard_url: dashboard_url,
        storefront_url: storefront_url,
        enterprise_name: enterprise_name,
        support_email: ENV['BREVO_EMAIL'] || "support@carboncube.co.ke",
        support_phone: "+254 712 990 524",
        timestamp: Time.current.strftime("%B %d, %Y at %I:%M %p")
      }
    )
  ensure
    File.delete(image_path) if image_path && File.exist?(image_path)
  end
  
  private

  def get_dashboard_url(user)
    base = case user.class.name
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
    UtmUrlHelper.append_utm(
      base,
      source: 'email',
      medium: 'welcome',
      campaign: 'signup',
      content: 'dashboard'
    )
  end
end
