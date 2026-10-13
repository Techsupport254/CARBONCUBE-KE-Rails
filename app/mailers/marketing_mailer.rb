class MarketingMailer < ApplicationMailer
  def valentines_campaign(seller)
    fullname = seller.fullname
    enterprise_name = seller.enterprise_name
    ads_count = seller.ads_count
    tier_name = seller.seller_tier&.tier&.name || "Free"

    total_clicks = ClickEvent.where(ad_id: seller.ads.select(:id), event_type: 'Ad-Click').count

    top_ad_title = nil
    top_ad_clicks = nil
    top_ad_data = ClickEvent.where(ad_id: seller.ads.select(:id), event_type: 'Ad-Click')
                            .group(:ad_id).order('count_all DESC').count.first
    if top_ad_data
      top_ad = Ad.find_by(id: top_ad_data[0])
      top_ad_title = top_ad&.title
      top_ad_clicks = top_ad_data[1]
    elsif seller.ads.exists?
      top_ad = seller.ads.active.order(created_at: :desc).first
      top_ad_title = top_ad&.title
      top_ad_clicks = 0
    end

    last_ad = seller.ads.order(created_at: :desc).first
    days_since_last_ad = last_ad ? ((Time.current - last_ad.created_at) / 1.day).to_i : 999

    dashboard_url = "https://carboncube-ke.com/seller/dashboard"

    headers['X-Priority'] = '1'
    headers['X-MSMail-Priority'] = 'High'
    headers['Importance'] = 'High'
    headers['Precedence'] = nil
    headers['List-Unsubscribe'] = nil
    headers['List-Unsubscribe-Post'] = nil
    headers['Message-ID'] = "<#{Time.current.to_f}-#{seller.id}@carboncube-ke.com>"

    mail(
      to: seller.email,
      subject: "Your shop performance update",
      from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>",
      react: {
        fullname: fullname,
        enterprise_name: enterprise_name,
        ads_count: ads_count,
        total_clicks: total_clicks,
        days_since_last_ad: days_since_last_ad,
        tier_name: tier_name,
        gender: seller.gender.presence || "Legend",
        profile_picture: seller.profile_picture,
        top_ad_title: top_ad_title,
        top_ad_clicks: top_ad_clicks,
        dashboard_url: dashboard_url
      }
    )
  end

  def product_review_request(name:, email:, products:)
    headers['Precedence'] = nil
    headers['List-Unsubscribe'] = nil
    headers['List-Unsubscribe-Post'] = nil
    headers['X-Auto-Response-Suppress'] = nil
    headers['X-Priority'] = '1'
    headers['X-MSMail-Priority'] = 'High'
    headers['Importance'] = 'High'
    headers['Feedback-ID'] = "review_request:carboncube"
    headers['Message-ID'] = "<#{Time.current.to_f}-review-#{SecureRandom.hex(4)}@carboncube-ke.com>"
    headers['In-Reply-To'] = nil
    headers['References'] = nil

    first_name = name.to_s.split.first || name

    mail(
      to: email,
      subject: "#{first_name}, how was your experience?",
      from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>",
      reply_to: ENV['BREVO_EMAIL'],
      react: {
        name: name,
        products: products
      }
    )
  end

  # Nudge a user who has never installed the mobile app.
  # recipient: a Buyer or Seller instance
  # reminder_number: 0 (initial), 1 (reminder 1), 2 (final reminder)
  def app_install_nudge(recipient:, reminder_number: 0)
    fullname   = recipient.fullname.presence || recipient.try(:enterprise_name).presence || "there"
    first_name = fullname.split(" ").first.presence || fullname
    role       = recipient.is_a?(Seller) ? "seller" : "buyer"

    campaign_stage = reminder_number == 0 ? "initial" : "reminder_#{reminder_number}"
    utm = "utm_source=email&utm_medium=app_install_nudge&utm_campaign=app_install_#{campaign_stage}&utm_content=#{role}"

    subject = case reminder_number
              when 0
                "#{first_name}, have you tried the Carbon Cube Kenya app?"
              when 1
                "Reminder: Get faster updates with the Carbon Cube Kenya app"
              else
                "Final reminder: Take Carbon Cube Kenya on the go"
              end

    headers["Precedence"]              = nil
    headers["List-Unsubscribe"]        = nil
    headers["List-Unsubscribe-Post"]   = nil
    headers["X-Auto-Response-Suppress"] = nil
    headers["X-Priority"]              = reminder_number > 0 ? "2" : "3"
    headers["Feedback-ID"]             = "app_install_nudge:carboncube"
    headers["Message-ID"]              = "<#{Time.current.to_f}-app-nudge-#{recipient.class.name.downcase}-#{recipient.id}-#{reminder_number}@carboncube-ke.com>"

    mail(
      to:      recipient.email,
      subject: subject,
      from:    "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>",
      react: {
        firstName:      first_name,
        fullname:       fullname,
        role:           role,
        reminderNumber: reminder_number,
        playStoreUrl:   "https://play.google.com/store/apps/details?id=com.carboncubeke&#{utm}",
        appStoreUrl:    "https://apps.apple.com/app/carbon-cube-kenya/id000000000?#{utm}",
        appPageUrl:     "https://carboncube-ke.com/app?#{utm}",
      }
    )
  end

  def self.review_url_for(ad)
    slug = ad.url_slug
    "https://carboncube-ke.com/ads/#{slug}/review?utm_source=email&utm_medium=review_request&utm_campaign=product_review&utm_content=#{slug}"
  end
end
