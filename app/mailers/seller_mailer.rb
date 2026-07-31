class SellerMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  def document_expiry_reminder(seller)
    update_url = UtmUrlHelper.append_utm("https://carboncube-ke.com/seller/documents",
      source: "email", medium: "reminder", campaign: "document_expiry", content: "upload")

    mail(
      to: seller.email,
      subject: "Document Expiry Reminder",
      react: {
        seller_name: seller.fullname || seller.enterprise_name,
        update_url: update_url
      }
    )
  end

  def document_update_reminder(seller)
    update_url = UtmUrlHelper.append_utm("https://carboncube-ke.com/seller/documents",
      source: "email", medium: "reminder", campaign: "document_update", content: "upload")

    mail(
      to: seller.email,
      subject: "Please Update Your Expired Document",
      react: {
        seller_name: seller.fullname || seller.enterprise_name,
        update_url: update_url
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
end
