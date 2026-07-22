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
end
