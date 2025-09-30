class SellerMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  def document_expiry_reminder(seller)
    @seller = seller
    mail(to: @seller.email, subject: "Document Expiry Reminder")
  end

  def document_update_reminder(seller)
    @seller = seller
    mail(to: @seller.email, subject: "Please Update Your Expired Document")
  end
end
