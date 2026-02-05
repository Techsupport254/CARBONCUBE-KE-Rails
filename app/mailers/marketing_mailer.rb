class MarketingMailer < ApplicationMailer
  helper ActionView::Helpers::NumberHelper
  layout false

  def valentines_campaign(seller)
    @seller = seller
    @fullname = seller.fullname
    @enterprise_name = seller.enterprise_name
    
    # Ads Count
    @ads_count = seller.ads_count
    
    # Profile Picture Logic
    raw_pic = seller.profile_picture
    if raw_pic.present? && !raw_pic.to_s.start_with?('/cached_profile_pictures/')
      @profile_picture = raw_pic
    else
      # Robust Fallback to UI Avatars
      # Ensure name is safe for URL
      safe_name = (@enterprise_name.presence || @fullname.presence || "Carbon User").to_s.gsub(/[^a-zA-Z0-9\s]/, '').strip
      safe_name = "CU" if safe_name.blank?
      @profile_picture = "https://ui-avatars.com/api/?name=#{URI.encode_www_form_component(safe_name)}&background=FED7D7&color=E53E3E&size=128&bold=true&format=png"
    end
    
    # Tier Name
    @tier_name = seller.seller_tier&.tier&.name || "Free"
    
    # Total Clicks
    @total_clicks = ClickEvent.where(ad_id: seller.ads.select(:id), event_type: 'Ad-Click').count

    # Identify Top Performing Ad
    top_ad_data = ClickEvent.where(ad_id: seller.ads.select(:id), event_type: 'Ad-Click')
                            .group(:ad_id)
                            .order('count_all DESC')
                            .count
                            .first
    
    # top_ad_data is [ad_id, count] or nil
    if top_ad_data
      @top_ad = Ad.find_by(id: top_ad_data[0])
      @top_ad_clicks = top_ad_data[1]
    elsif seller.ads.exists?
       # Fallback: Just grab the latest active ad if no clicks yet
       @top_ad = seller.ads.active.order(created_at: :desc).first
       @top_ad_clicks = 0
    end

    # Days since last ad
    last_ad = seller.ads.order(created_at: :desc).first
    @days_since_last_ad = last_ad ? ((Time.current - last_ad.created_at) / 1.day).to_i : 999
    
    # Gender
    @gender = seller.gender.presence || "Legend" 
    
    # Timestamp (for footer or metadata matching welcome_mailer)
    @timestamp = Time.current.in_time_zone("Nairobi").strftime("%B %d, %Y at %I:%M %p")

    # Headers to avoid "Promotions" tab
    headers['X-Priority'] = '1' # High priority
    headers['X-MSMail-Priority'] = 'High'
    headers['Importance'] = 'High'
    headers['Precedence'] = nil # Explicitly override ApplicationMailer's 'bulk'
    
    # Intentionally removing List-Unsubscribe from HEADER to look less like a newsletter
    headers['List-Unsubscribe'] = nil
    headers['List-Unsubscribe-Post'] = nil

    # Force unique thread by adding invisible char or ID to subject if needed, 
    # but simplest is to just make the subject unique.
    unique_id = Time.current.to_i.to_s[-4..-1]

    # Explicitly set a unique Message-ID to break threading
    headers['Message-ID'] = "<#{Time.current.to_f}-#{seller.id}@carboncube-ke.com>"
    headers['X-Entity-Ref-ID'] = unique_id

    mail(
      to: seller.email,
      subject: "We’ve got feelings for your shop! ❤️ (Performance Update)",
      from: "Carbon Cube Team <#{ENV['BREVO_EMAIL']}>"
    )
  end
end
