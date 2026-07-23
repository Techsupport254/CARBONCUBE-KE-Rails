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

  def self.review_url_for(ad)
    slug = Ad.slugify(ad.title)
    "https://carboncube-ke.com/ads/#{slug}/review?id=#{ad.id}"
  end
end
