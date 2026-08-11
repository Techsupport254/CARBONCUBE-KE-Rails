class SellerCommunicationsMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  skip_before_action :add_deliverability_headers, only: [:seller_growth_initiative, :app_promo, :listing_reminder]

  def custom_communication
    user = params[:user] || params[:seller]
    user_type = params[:user_type] || 'seller'
    custom_subject = params[:subject]
    custom_message = params[:message]

    fullname = if user_type == 'seller'
      user.fullname.presence || user.enterprise_name.presence || 'Seller'
    else
      user.fullname.presence || user.username.presence || 'Buyer'
    end
    first_name = fullname.to_s.split(' ').first.presence || "Partner"

    timestamp = Time.current.strftime('%Y%m%d%H%M')
    unique_subject = "#{custom_subject} - #{timestamp}"

    mail_message = mail(
      to: user.email,
      subject: unique_subject,
      react: {
        fullname: fullname,
        first_name: first_name,
        subject: custom_subject,
        message: custom_message,
        user_type: user_type
      }
    )

    mail_message['In-Reply-To'] = nil
    mail_message['References'] = nil
    mail_message['Thread-Topic'] = nil
    mail_message['Thread-Index'] = nil
    mail_message['X-Threading'] = 'false'
    mail_message['X-Conversation-ID'] = SecureRandom.uuid

    mail_message
  end

  def general_update
    user = params[:seller] || params[:user]
    user_type = user.respond_to?(:user_type) ? user.user_type : 'seller'

    fullname = user.fullname
    first_name = fullname.to_s.split(' ').first.presence || "Partner"

    timestamp = Time.current.strftime('%Y%m%d%H%M')
    unique_subject = "Platform Update #{timestamp} - Let's Grow Together!"

    mail_message = mail(
      to: user.email,
      subject: unique_subject,
      react: {
        fullname: fullname,
        first_name: first_name,
        user_type: user_type
      }
    )

    mail_message['X-Threading'] = 'false'
    mail_message['X-Conversation-ID'] = SecureRandom.uuid

    mail_message
  end

  def black_friday_email
    user = params[:seller] || params[:user]

    fullname = user.fullname
    first_name = fullname.to_s.split(' ').first.presence || "Partner"
    dashboard_url = "https://carboncube-ke.com/seller/dashboard"

    timestamp = Time.current.strftime('%Y%m%d%H%M%S')
    subject_text = "Platform Notification #{timestamp} - High Traffic Period Expected"

    headers['X-Priority'] = '1'
    headers['Importance'] = 'High'
    headers['X-MSMail-Priority'] = 'High'
    headers['Precedence'] = nil
    headers['List-Unsubscribe'] = nil
    headers['List-Unsubscribe-Post'] = nil
    headers['In-Reply-To'] = nil
    headers['References'] = nil

    mail_message = mail(
      to: user.email,
      subject: subject_text,
      react: {
        fullname: fullname,
        first_name: first_name,
        dashboard_url: dashboard_url
      }
    )

    mail_message['Precedence'] = nil
    mail_message['List-Unsubscribe'] = nil
    mail_message['List-Unsubscribe-Post'] = nil
    mail_message['In-Reply-To'] = nil
    mail_message['References'] = nil
    mail_message['Reply-To'] = nil

    mail_message
  end

  def seller_growth_initiative
    seller = params[:seller]

    fullname = seller.fullname
    first_name = fullname.to_s.split(' ').first.presence || "Legend"
    enterprise_name = seller.enterprise_name
    ads_count = seller.ads.where(deleted: false).count
    tier_name = seller.seller_tier&.tier&.name || "Free"
    dashboard_url = "https://carboncube-ke.com/seller/dashboard"

    subject_text = "You have a new message"
    subject_text += " [Ref: #{Time.current.to_i.to_s[-4..-1]}]"

    headers['X-Priority'] = '1'
    headers['X-MSMail-Priority'] = 'High'
    headers['Importance'] = 'High'
    headers['Precedence'] = nil
    headers['List-Unsubscribe'] = nil
    headers['List-Unsubscribe-Post'] = nil
    headers['Message-ID'] = "<#{Time.current.to_f}-#{seller.id}@carboncube-ke.com>"

    mail(
      to: seller.email,
      from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>",
      subject: subject_text,
      react: {
        fullname: fullname,
        first_name: first_name,
        enterprise_name: enterprise_name,
        ads_count: ads_count,
        tier_name: tier_name,
        dashboard_url: dashboard_url
      }
    )
  end

  def app_promo
    user = params[:user] || params[:seller]

    fullname = user.fullname
    first_name = fullname.to_s.split(' ').first.presence || "Partner"
    app_url = "https://carboncube-ke.com/app"

    subject_text = "[Official] Your Store Access Update: Carbon Cube Mobile"
    subject_text += " [Ref: #{Time.current.to_i.to_s[-4..-1]}]"

    headers['X-Priority'] = '1'
    headers['X-MSMail-Priority'] = 'High'
    headers['Importance'] = 'High'
    headers['Auto-Submitted'] = 'auto-generated'
    headers['X-Auto-Response-Suppress'] = 'All'
    headers['Precedence'] = nil
    headers['List-Unsubscribe'] = nil
    headers['List-Unsubscribe-Post'] = nil
    headers['Message-ID'] = "<#{Time.current.to_f}-app-promo-#{user.id}@carboncube-ke.com>"

    mail(
      to: user.email,
      from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>",
      subject: subject_text,
      react: {
        fullname: fullname,
        first_name: first_name,
        app_url: app_url
      }
    )
  end

  def listing_reminder
    user = params[:seller] || params[:user]

    fullname = user.fullname
    first_name = fullname.to_s.split(' ').first.presence || "Partner"
    dashboard_url = UtmUrlHelper.append_utm("https://carboncube-ke.com/seller/ads",
      source: "listing_reminder", medium: "email", campaign: "listing_update")

    subject_text = "Listing Update Reminder"

    headers['X-Priority'] = '1'
    headers['X-MSMail-Priority'] = 'High'
    headers['Importance'] = 'High'
    headers['Auto-Submitted'] = 'auto-generated'
    headers['X-Auto-Response-Suppress'] = 'All'

    mail(
      to: user.email,
      from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>",
      subject: subject_text,
      react: {
        fullname: fullname,
        first_name: first_name,
        dashboard_url: dashboard_url
      }
    )
  end

  def share_shop_feature
    user = params[:seller] || params[:user]

    fullname = user.fullname
    first_name = fullname.to_s.split(' ').first.presence || "Partner"
    dashboard_url = "https://carboncube-ke.com/seller/dashboard"

    subject_text = "Share Your Shop Link with Ease"

    headers['X-Priority'] = '1'
    headers['X-MSMail-Priority'] = 'High'
    headers['Importance'] = 'High'
    headers['Auto-Submitted'] = 'auto-generated'
    headers['X-Auto-Response-Suppress'] = 'All'

    mail(
      to: user.email,
      from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>",
      subject: subject_text,
      react: {
        fullname: fullname,
        first_name: first_name,
        dashboard_url: dashboard_url
      }
    )
  end

  def accurate_listings
    user = params[:seller] || params[:user]

    fullname = user.fullname
    first_name = fullname.to_s.split(' ').first.presence || "Partner"
    dashboard_url = "https://carboncube-ke.com/seller/ads"

    subject_text = "Build Trust through Accurate Listings"

    headers['X-Priority'] = '1'
    headers['X-MSMail-Priority'] = 'High'
    headers['Importance'] = 'High'
    headers['Auto-Submitted'] = 'auto-generated'
    headers['X-Auto-Response-Suppress'] = 'All'

    mail(
      to: user.email,
      from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>",
      subject: subject_text,
      react: {
        fullname: fullname,
        first_name: first_name,
        dashboard_url: dashboard_url
      }
    )
  end

  def buyers_compare_before_contact
    user = params[:seller] || params[:user]

    fullname = user.respond_to?(:fullname) && user.fullname.present? ? user.fullname : (user.respond_to?(:enterprise_name) && user.enterprise_name.present? ? user.enterprise_name : 'Seller')
    first_name = fullname.to_s.split(' ').first.presence || "Partner"
    dashboard_url = UtmUrlHelper.append_utm(
      "https://carboncube-ke.com/seller/ads",
      source: "seller_communication",
      medium: "email",
      campaign: "buyers_compare_before_contact",
      content: "review_ads_button"
    )

    subject_text = "Seller Account Update: Listing recommendations for Carbon Cube Kenya"

    mail(
      to: user.email,
      from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>",
      subject: subject_text,
      react: {
        fullname: fullname,
        first_name: first_name,
        dashboard_url: dashboard_url,
        banner_url: "https://res.cloudinary.com/dwrjceslk/image/upload/v1785482749/emails/ghybhzdpzvpw4ekmi3ct.png"
      }
    )
  end

  def request_phone_number
    user = params[:seller] || params[:user]

    fullname = user.respond_to?(:fullname) && user.fullname.present? ? user.fullname : (user.respond_to?(:enterprise_name) && user.enterprise_name.present? ? user.enterprise_name : 'Seller')
    first_name = fullname.to_s.split(' ').first.presence || "Partner"

    update_phone_url = UtmUrlHelper.append_utm(
      "https://carboncube-ke.com/seller/profile",
      source: "seller_communication",
      medium: "email",
      campaign: "request_phone_number",
      content: "complete_profile_cta"
    )

    subject_text = "Action Required: Complete your seller profile on Carbon Cube Kenya"

    mail(
      to: user.email,
      from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>",
      subject: subject_text,
      react: {
        fullname: fullname,
        first_name: first_name,
        update_phone_url: update_phone_url,
        banner_url: "https://res.cloudinary.com/dwrjceslk/image/upload/v1785482749/emails/ghybhzdpzvpw4ekmi3ct.png"
      }
    )
  end

  def ad_visibility_reminder
    user = params[:seller] || params[:user]
    to_email = params[:to_email]

    fullname = user.respond_to?(:fullname) && user.fullname.present? ? user.fullname : (user.respond_to?(:enterprise_name) && user.enterprise_name.present? ? user.enterprise_name : 'Seller')
    first_name = fullname.to_s.split(' ').first.presence || "Partner"
    enterprise_name = user.respond_to?(:enterprise_name) ? user.enterprise_name : nil
    ads_count = params[:ads_count] || (user.respond_to?(:ads) ? user.ads.count : nil)
    last_active_at = user.respond_to?(:last_active_at) ? user.last_active_at : nil
    last_active = last_active_at&.strftime('%B %d, %Y')

    ads_data = if params[:ads].present?
      params[:ads]
    elsif user.respond_to?(:ads)
      user.ads.where(deleted: false).order(updated_at: :desc).limit(3).map do |ad|
        {
          title: ad.title,
          image: ad.respond_to?(:first_valid_media_url) ? ad.first_valid_media_url : nil,
          price: ad.respond_to?(:price) ? ad.price : nil,
          url: ad.respond_to?(:product_url) ? ad.product_url : "https://carboncube-ke.com/ads/#{ad.id}"
        }
      end
    else
      []
    end

    dashboard_url = UtmUrlHelper.append_utm(
      "https://carboncube-ke.com/seller/ads",
      source: "seller_communication",
      medium: "email",
      campaign: "ad_visibility_reminder",
      content: "add_ads_cta"
    )

    subject_text = "Boost your Carbon Cube Kenya shop visibility"

    mail(
      to: to_email || user.email,
      from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>",
      subject: subject_text,
      react: {
        fullname: fullname,
        firstName: first_name,
        enterpriseName: enterprise_name,
        adsCount: ads_count,
        lastActive: last_active,
        ads: ads_data,
        dashboardUrl: dashboard_url,
        supportEmail: ENV['BREVO_EMAIL']
      }
    )
  end

  def new_features
    user = params[:seller] || params[:user]
    to_email = params[:to_email]

    fullname = if user.respond_to?(:fullname) && user.fullname.present?
      user.fullname
    elsif user.respond_to?(:enterprise_name) && user.enterprise_name.present?
      user.enterprise_name
    else
      'Seller'
    end
    first_name = fullname.to_s.split(' ').first.presence || "Partner"

    profile_url = "https://carboncube-ke.com/profile?edit=true&tab=business&utm_source=seller_communication&utm_medium=email&utm_campaign=new_features&utm_content=update_profile_cta"
    banner_url = "https://res.cloudinary.com/dwrjceslk/image/upload/c_scale,f_png,q_auto,w_1200/v1/emails/new_features_banner?_a=BACMTiAE"
    support_url = "mailto:support@carboncube-ke.com"

    subject_text = "New Features Available for Sellers"

    mail(
      to: to_email || user.email,
      from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>",
      subject: subject_text,
      react: {
        fullname: fullname,
        first_name: first_name,
        profile_url: profile_url,
        banner_url: banner_url,
        support_url: support_url
      }
    )
  end
end

