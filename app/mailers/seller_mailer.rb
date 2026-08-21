class SellerMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  def document_expiry_reminder(seller, to_email = nil, custom_message = nil, custom_subject = nil, update_url = nil)
    @seller = seller
    @custom_message = custom_message
    recipient_name = seller.enterprise_name.presence || seller.fullname.presence || "Partner"
    enterprise_param = CGI.escape(recipient_name.to_s.downcase.strip.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, ''))

    @update_url = update_url.presence || "https://carboncube-ke.com/profile?edit=true&tab=documents&utm_source=compliance&utm_medium=email&utm_campaign=document_verification&enterprise=#{enterprise_param}"
    subject = custom_subject.presence || "Document Expiry Reminder — #{recipient_name}"

    mail(
      to: to_email.presence || seller.email,
      subject: subject,
      react: {
        sellerName: recipient_name,
        updateUrl: @update_url,
        customMessage: @custom_message
      }
    )
  end

  def document_update_reminder(seller, to_email = nil, custom_message = nil, custom_subject = nil, update_url = nil)
    @seller = seller
    @custom_message = custom_message
    recipient_name = seller.enterprise_name.presence || seller.fullname.presence || "Partner"
    enterprise_param = CGI.escape(recipient_name.to_s.downcase.strip.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, ''))

    @update_url = update_url.presence || "https://carboncube-ke.com/profile?edit=true&tab=documents&utm_source=compliance&utm_medium=email&utm_campaign=document_verification&enterprise=#{enterprise_param}"
    subject = custom_subject.presence || "Please Update Your Expired Document — #{recipient_name}"

    mail(
      to: to_email.presence || seller.email,
      subject: subject,
      react: {
        sellerName: recipient_name,
        updateUrl: @update_url,
        customMessage: @custom_message
      }
    )
  end


  def reactivation_confirmation(seller, to_email = nil)
    fullname = seller.fullname.presence || seller.enterprise_name.presence || "Seller"
    first_name = fullname.to_s.split(" ").first.presence || "Partner"
    dashboard_url = "https://carboncube-ke.com/seller/dashboard"

    mail(
      to: to_email || seller.email,
      subject: "Your Carbon Cube Kenya account has been reactivated",
      react: {
        fullname: fullname,
        firstName: first_name,
        enterpriseName: seller.enterprise_name,
        dashboardUrl: dashboard_url,
        supportEmail: ENV["BREVO_EMAIL"]
      }
    )
  end

  def review_request_confirmation(seller, to_email = nil)
    fullname = seller.fullname.presence || seller.enterprise_name.presence || "Seller"
    first_name = fullname.to_s.split(" ").first.presence || "Partner"
    dashboard_url = "https://carboncube-ke.com/seller/dashboard"

    mail(
      to: to_email || seller.email,
      subject: "Your Carbon Cube Kenya review request has been received",
      react: {
        fullname: fullname,
        firstName: first_name,
        enterpriseName: seller.enterprise_name,
        dashboardUrl: dashboard_url,
        supportEmail: ENV["BREVO_EMAIL"]
      }
    )
  end

  def review_request_approved(seller, review_request, to_email = nil)
    fullname = seller.fullname.presence || seller.enterprise_name.presence || "Seller"
    first_name = fullname.to_s.split(" ").first.presence || "Partner"
    dashboard_url = "https://carboncube-ke.com/seller/dashboard"

    mail(
      to: to_email || seller.email,
      subject: "Your Carbon Cube Kenya account review is approved",
      react: {
        fullname: fullname,
        firstName: first_name,
        enterpriseName: seller.enterprise_name,
        reviewNotes: review_request.review_notes,
        reviewedAt: review_request.reviewed_at&.strftime("%B %d, %Y"),
        dashboardUrl: dashboard_url,
        supportEmail: ENV["BREVO_EMAIL"]
      }
    )
  end

  def account_flagged(seller, flag_notes = nil, to_email = nil)
    fullname = seller.fullname.presence || seller.enterprise_name.presence || "Seller"
    first_name = fullname.to_s.split(" ").first.presence || "Partner"
    review_request_url = "https://carboncube-ke.com/seller/review-request"

    mail(
      to: to_email || seller.email,
      subject: "Your Carbon Cube Kenya account has been flagged",
      react: {
        fullname: fullname,
        firstName: first_name,
        enterpriseName: seller.enterprise_name,
        flagNotes: flag_notes,
        reviewRequestUrl: review_request_url,
        supportEmail: ENV["BREVO_EMAIL"]
      }
    )
  end

  def ad_flagged(seller, ad, flag_notes = nil, to_email = nil)
    fullname = seller.fullname.presence || seller.enterprise_name.presence || "Seller"
    first_name = fullname.to_s.split(" ").first.presence || "Partner"
    
    # Extract clean product image
    ad_image_url = if ad.respond_to?(:first_media_url) && ad.first_media_url.present?
                     ad.first_media_url
                   elsif ad.media.present?
                     begin
                       parsed = ad.media.is_a?(String) ? JSON.parse(ad.media) : ad.media
                       Array(parsed).first
                     rescue
                       ad.media.to_s
                     end
                   end

    # Format user-friendly price
    formatted_price = if ad.price.present?
                        "KES #{ad.price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
                      end

    # Sanitize admin-level strings (remove scores, auto-reject tags, internal codes)
    clean_reason = flag_notes.to_s
                             .gsub(/^(Auto-Rejected|Rejected|Held|Soft-Flagged)?\s*\[Score:\s*\d+\]:\s*/i, '')
                             .gsub(/\[Score:\s*\d+\]/i, '')
                             .gsub(%r{^Inappropriate / NSFW image detected:\s*}i, 'Inappropriate image content: ')
                             .strip
    clean_reason = "Content or image quality guidelines update required." if clean_reason.blank?

    edit_url = "https://carboncube-ke.com/seller/ads/#{ad.id}/edit"
    dashboard_url = "https://carboncube-ke.com/seller/ads"

    mail(
      to: to_email || seller.email,
      subject: "Action Required: Update needed on \"#{ad.title}\"",
      react: {
        fullname: fullname,
        firstName: first_name,
        enterpriseName: seller.enterprise_name,
        adId: ad.id,
        adTitle: ad.title,
        adPrice: formatted_price,
        adCategory: ad.category&.name,
        adCondition: ad.condition&.titleize,
        adImageUrl: ad_image_url,
        flagReason: clean_reason,
        editAdUrl: edit_url,
        dashboardUrl: dashboard_url,
        supportEmail: ENV["BREVO_EMAIL"]
      }
    )
  end

  def review_request_rejected(seller, review_request, to_email = nil)
    fullname = seller.fullname.presence || seller.enterprise_name.presence || "Seller"
    first_name = fullname.to_s.split(" ").first.presence || "Partner"
    contact_url = UtmUrlHelper.append_utm(
      "https://carboncube-ke.com/contact",
      source: "email",
      medium: "seller_communication",
      campaign: "review_request_rejected",
      content: "contact_support"
    )

    mail(
      to: to_email || seller.email,
      subject: "Update on your Carbon Cube Kenya account review",
      react: {
        fullname: fullname,
        firstName: first_name,
        enterpriseName: seller.enterprise_name,
        reviewNotes: review_request.review_notes,
        reviewedAt: review_request.reviewed_at&.strftime("%B %d, %Y"),
        contactUrl: contact_url,
        supportEmail: ENV["BREVO_EMAIL"]
      }
    )
  end

  def storefront_qr_welcome(seller, to_email = nil)
    fullname = seller.fullname.presence || seller.enterprise_name.presence || "Merchant"
    first_name = fullname.to_s.split(" ").first.presence || "Partner"
    enterprise_name = seller.enterprise_name.presence || fullname
    shop_slug = (seller.enterprise_name || seller.username || seller.id.to_s).parameterize

    base_frontend = if Rails.env.development?
      ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    else
      ENV.fetch('FRONTEND_URL', 'https://carboncube-ke.com')
    end

    storefront_url = UtmUrlHelper.append_utm(
      "#{base_frontend}/shop/#{shop_slug}",
      source: "email",
      medium: "welcome_qr",
      campaign: "seller_onboarding",
      content: "storefront_link"
    )

    qr_studio_url = UtmUrlHelper.append_utm(
      "#{base_frontend}/seller/qr",
      source: "email",
      medium: "welcome_qr",
      campaign: "seller_onboarding",
      content: "qr_studio"
    )

    # Generate and attach high-res standee image
    image_path = SellerQrStandeeGeneratorService.generate(seller)
    if image_path && File.exist?(image_path)
      attachments["#{shop_slug}-qr-standee.png"] = File.binread(image_path)
    end

    mail(
      to: to_email || seller.email,
      subject: "Your Official Storefront QR Standee & Shop Link - Carbon Cube Kenya",
      react: {
        fullname: fullname,
        firstName: first_name,
        enterpriseName: enterprise_name,
        storefrontUrl: storefront_url,
        qrStudioUrl: qr_studio_url,
        supportEmail: ENV["BREVO_EMAIL"] || "support@carboncube.co.ke",
        supportPhone: "+254 712 990 524"
      }
    )
  ensure
    File.delete(image_path) if image_path && File.exist?(image_path)
  end
end
